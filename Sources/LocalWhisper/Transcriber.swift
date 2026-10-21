import Foundation
import WhisperKit

/// Wraps WhisperKit: downloads the model on first run, keeps it loaded, and transcribes sample buffers.
actor Transcriber {
    static let modelVariant = "openai_whisper-large-v3-v20240930_turbo"

    private var whisper: WhisperKit?

    private static var baseFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "LocalWhisper/models")
    }

    /// Where WhisperKit's downloader puts this variant under baseFolder.
    private static var modelFolder: URL {
        baseFolder.appending(path: "models/argmaxinc/whisperkit-coreml/\(modelVariant)")
    }

    /// Downloads the model if it isn't on disk yet, then loads and warms it up.
    /// Reports download progress as 0...1, then nil once the download is done and loading starts.
    func load(progress: @escaping @Sendable (Double?) -> Void) async throws {
        let folder = Self.modelFolder
        let encoder = folder.appending(path: "AudioEncoder.mlmodelc")
        if !FileManager.default.fileExists(atPath: encoder.path) {
            _ = try await WhisperKit.download(variant: Self.modelVariant, downloadBase: Self.baseFolder) { p in
                progress(p.fractionCompleted)
            }
            progress(nil)
        }
        let config = WhisperKitConfig(
            modelFolder: folder.path,
            tokenizerFolder: Self.baseFolder,
            verbose: false,
            logLevel: .error,
            prewarm: true,
            load: true,
            download: false
        )
        whisper = try await WhisperKit(config)
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
