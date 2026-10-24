import Foundation
import WhisperKit

/// Wraps WhisperKit: downloads the model on first run, keeps it loaded, and transcribes sample buffers.
actor Transcriber {
    private static let modelVariant = "openai_whisper-large-v3-v20240930_turbo"

    private var whisper: WhisperKit?

    private static var baseFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Closetalk/models")
    }

    /// Written after the first successful load. Core ML compiles the model for the Neural Engine on
    /// that load, which takes about 10 minutes; later loads take seconds.
    private static var compiledMarker: URL {
        baseFolder.appending(path: "\(modelVariant).compiled")
    }

    /// Whether a load has finished before, so the next one won't need the long first compile.
    static var hasCompiledBefore: Bool {
        FileManager.default.fileExists(atPath: compiledMarker.path)
    }

    /// Where WhisperKit's downloader puts this variant under baseFolder.
    private static var modelFolder: URL {
        baseFolder.appending(path: "models/argmaxinc/whisperkit-coreml/\(modelVariant)")
    }

    /// Downloads the model if it isn't on disk yet, then loads and warms it up.
    /// Reports download progress as 0...1 (only when a download is needed), then nil when loading starts.
    func load(progress: @escaping @Sendable (Double?) -> Void) async throws {
        // Written only after a download finishes, so an interrupted download resumes on the next try.
        let doneMarker = Self.baseFolder.appending(path: "\(Self.modelVariant).complete")
        if !FileManager.default.fileExists(atPath: doneMarker.path) {
            _ = try await WhisperKit.download(variant: Self.modelVariant, downloadBase: Self.baseFolder) { p in
                progress(p.fractionCompleted)
            }
            FileManager.default.createFile(atPath: doneMarker.path, contents: nil)
        }
        progress(nil)
        let config = WhisperKitConfig(
            modelFolder: Self.modelFolder.path,
            tokenizerFolder: Self.baseFolder,
            verbose: false,
            logLevel: .error,
            prewarm: true,
            load: true,
            download: false
        )
        do {
            whisper = try await WhisperKit(config)
            FileManager.default.createFile(atPath: Self.compiledMarker.path, contents: nil)
        } catch {
            // Likely a damaged download. Forget it was complete so the next retry downloads again.
            try? FileManager.default.removeItem(at: doneMarker)
            throw error
        }
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        guard let whisper else { return "" }
        let options = DecodingOptions(
            language: "en",
            detectLanguage: false,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )
        let results = try await whisper.transcribe(audioArray: samples, decodeOptions: options)
        return results.map(\.text).joined(separator: " ")
    }

    /// For the --transcribe debug flag: decodes an audio file to 16 kHz mono samples.
    static func samples(fromFile path: String) throws -> [Float] {
        try AudioProcessor.loadAudioAsFloatArray(fromPath: path)
    }
}
