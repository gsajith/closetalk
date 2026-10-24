import Foundation
import os
import WhisperKit

/// Wraps WhisperKit: downloads the model on first run, keeps it loaded, and transcribes sample buffers.
/// On a first launch it also loads a small sample model, so dictation works within seconds while the
/// full model downloads (1.5 GB) and compiles (up to about 10 minutes).
actor Transcriber {
    private static let modelVariant = "openai_whisper-large-v3-v20240930_turbo"
    /// tiny.en: ready in about 20 s on a first launch, but gets names and symbols wrong.
    private static let sampleVariant = "openai_whisper-tiny.en"

    /// What load(sampleFirst:report:) is doing, for the menu and the setup window.
    enum LoadEvent: Sendable {
        case sampleLoading
        case sampleReady
        case sampleFailed
        case downloading(fraction: Double)
        /// The full model is on disk and loading, which compiles it the first time.
        case loading
    }

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

    /// Written only after a download finishes, so an interrupted download resumes on the next try.
    private static var downloadedMarker: URL {
        baseFolder.appending(path: "\(modelVariant).complete")
    }

    static var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: downloadedMarker.path)
    }

    /// Whether a load has finished before, so the next one won't need the long first compile.
    /// Versions before the marker existed left only Core ML's compiled cache, so count that too.
    static var hasCompiledBefore: Bool {
        if FileManager.default.fileExists(atPath: compiledMarker.path) { return true }
        guard isDownloaded, let id = Bundle.main.bundleIdentifier else { return false }
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: id)
        return !((try? FileManager.default.contentsOfDirectory(atPath: cache.path))?.isEmpty ?? true)
    }

    /// Where WhisperKit's downloader puts this variant under baseFolder.
    private static var modelFolder: URL {
        baseFolder.appending(path: "models/argmaxinc/whisperkit-coreml/\(modelVariant)")
    }

    /// Gets the full model ready: downloads it if it isn't on disk yet, then loads and warms it up. With
    /// `sampleFirst`, it first loads the sample model and starts transcribing with it. A failed sample load
    /// only means waiting for the full model, so it isn't an error.
    func load(sampleFirst: Bool, report: @escaping @Sendable (LoadEvent) -> Void) async throws {
        if sampleFirst && whisper == nil {
            report(.sampleLoading)
            do {
                let folder = try await WhisperKit.download(variant: Self.sampleVariant, downloadBase: Self.baseFolder)
                whisper = try await WhisperKit(Self.config(folder))
                report(.sampleReady)
            } catch {
                Self.log.error("sample model failed: \(error.localizedDescription, privacy: .public)")
                report(.sampleFailed)
            }
        }

        let doneMarker = Self.downloadedMarker
        if !Self.isDownloaded {
            _ = try await WhisperKit.download(variant: Self.modelVariant, downloadBase: Self.baseFolder) { p in
                report(.downloading(fraction: p.fractionCompleted))
            }
            FileManager.default.createFile(atPath: doneMarker.path, contents: nil)
        }
        report(.loading)
        do {
            // Swapping the reference is safe mid-dictation: a running transcription keeps its own.
            whisper = try await WhisperKit(Self.config(Self.modelFolder))
            FileManager.default.createFile(atPath: Self.compiledMarker.path, contents: nil)
            Self.removeSampleModel()
        } catch {
            // Likely a damaged download. Forget it was complete so the next retry downloads again,
            // and compiles again after that.
            try? FileManager.default.removeItem(at: doneMarker)
            try? FileManager.default.removeItem(at: Self.compiledMarker)
            throw error
        }
    }

    private static let log = Logger(subsystem: "dev.gsajith.Closetalk", category: "transcriber")

    private static func config(_ folder: URL) -> WhisperKitConfig {
        WhisperKitConfig(modelFolder: folder.path, tokenizerFolder: baseFolder, verbose: false, logLevel: .error,
                         prewarm: true, load: true, download: false)
    }

    /// The sample model is only for the first launch, so its 150 MB go once the full model works.
    private static func removeSampleModel() {
        for path in ["models/argmaxinc/whisperkit-coreml/\(sampleVariant)", "models/openai/whisper-tiny.en"] {
            try? FileManager.default.removeItem(at: baseFolder.appending(path: path))
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
