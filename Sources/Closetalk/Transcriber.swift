import Foundation
import os
import WhisperKit

/// Wraps WhisperKit: downloads the models on first run, keeps them loaded, and transcribes sample buffers.
/// It keeps a small model next to the full one. On a first launch the small model dictates while the
/// full model downloads (1.5 GB) and compiles (up to about 10 minutes). After that it only transcribes
/// the live preview while recording.
actor Transcriber {
    private static let modelVariant = "openai_whisper-large-v3-v20240930_turbo"
    /// tiny.en, 150 MB: ready in about 20 s on a first launch, but gets names and symbols wrong. On an
    /// M1 Max a pass takes 80 to 400 ms, 25 ms of it in the encoder, against about 2 s for the full model.
    /// WhisperKit cancels between steps, so a preview cancelled on release stops within milliseconds.
    private static let smallVariant = "openai_whisper-tiny.en"

    /// What load(sampleFirst:report:) is doing, for the menu and the setup window.
    enum LoadEvent: Sendable {
        case sampleLoading
        case sampleReady
        case sampleFailed
        case downloading(fraction: Double)
        /// The full model is on disk and loading, which compiles it the first time.
        case loading
    }

    /// The model dictation pastes from: the small one until the full one is ready.
    private var whisper: WhisperKit?
    /// The small model, for previews.
    private var small: WhisperKit?

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
    private static var downloadedMarker: URL { downloadedMarker(modelVariant) }

    private static func downloadedMarker(_ variant: String) -> URL {
        baseFolder.appending(path: "\(variant).complete")
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

    /// Where WhisperKit's downloader puts a variant under baseFolder.
    private static func modelFolder(_ variant: String) -> URL {
        baseFolder.appending(path: "models/argmaxinc/whisperkit-coreml/\(variant)")
    }

    /// Gets the full model ready: downloads it if it isn't on disk yet, then loads and warms it up. With
    /// `sampleFirst`, it first loads the small model and starts transcribing with it. A failed small load
    /// only means waiting for the full model, so it isn't an error.
    func load(sampleFirst: Bool, report: @escaping @Sendable (LoadEvent) -> Void) async throws {
        if sampleFirst && whisper == nil {
            report(.sampleLoading)
            do {
                try await loadSmallModel()
                whisper = small
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
            whisper = try await WhisperKit(Self.config(Self.modelFolder(Self.modelVariant)))
            FileManager.default.createFile(atPath: Self.compiledMarker.path, contents: nil)
        } catch {
            // Likely a damaged download. Forget it was complete so the next retry downloads again,
            // and compiles again after that.
            try? FileManager.default.removeItem(at: doneMarker)
            try? FileManager.default.removeItem(at: Self.compiledMarker)
            throw error
        }
    }

    /// Loads the small model for previews, unless the first launch already did. Earlier versions deleted
    /// it once the full model worked, so updating downloads it once more. Without it, recording shows no
    /// preview, which isn't worth an error.
    func loadPreviewModel() async {
        do {
            try await loadSmallModel()
        } catch {
            Self.log.error("preview model failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func loadSmallModel() async throws {
        guard small == nil else { return }
        let marker = Self.downloadedMarker(Self.smallVariant)
        // Checked first, so later launches load it offline without asking Hugging Face.
        if !FileManager.default.fileExists(atPath: marker.path) {
            _ = try await WhisperKit.download(variant: Self.smallVariant, downloadBase: Self.baseFolder)
            FileManager.default.createFile(atPath: marker.path, contents: nil)
        }
        do {
            small = try await WhisperKit(Self.config(Self.modelFolder(Self.smallVariant)))
        } catch {
            try? FileManager.default.removeItem(at: marker)
            throw error
        }
    }

    private static let log = Logger(subsystem: "dev.gsajith.Closetalk", category: "transcriber")

    private static func config(_ folder: URL) -> WhisperKitConfig {
        WhisperKitConfig(modelFolder: folder.path, tokenizerFolder: baseFolder, verbose: false, logLevel: .error,
                         prewarm: true, load: true, download: false)
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        try await Self.transcribe(samples, with: whisper)
    }

    /// Transcribes with the small model for the live preview, or returns "" before it loads. Throws
    /// CancellationError soon after its task is cancelled: WhisperKit checks before every decoding step.
    func transcribePreview(_ samples: [Float]) async throws -> String {
        try await Self.transcribe(samples, with: small)
    }

    private static func transcribe(_ samples: [Float], with model: WhisperKit?) async throws -> String {
        guard let model else { return "" }
        let options = DecodingOptions(
            language: "en",
            detectLanguage: false,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )
        let results = try await model.transcribe(audioArray: samples, decodeOptions: options)
        return results.map(\.text).joined(separator: " ")
    }

    /// For the --transcribe debug flag: decodes an audio file to 16 kHz mono samples.
    static func samples(fromFile path: String) throws -> [Float] {
        try AudioProcessor.loadAudioAsFloatArray(fromPath: path)
    }
}
