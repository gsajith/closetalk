import AppKit
import AVFoundation
import LocalWhisperCore
import os

/// Connects the hotkey to recording, transcription, and pasting, and keeps the menu bar icon in sync.
/// Everything here runs on the main thread; only transcription runs elsewhere.
@MainActor
final class DictationController {
    /// Clips shorter than this are almost always accidental.
    private static let minimumSamples = 16_000 / 4
    private static let log = Logger(subsystem: "dev.gsajith.LocalWhisper", category: "dictation")
    /// "Talk now" once the mic is live, and a different sound when recording ends.
    private static let startSound = NSSound(named: "Tink")
    private static let stopSound = NSSound(named: "Pop")

    private let menuBar: MenuBarController
    private let recorder = Recorder()
    private let transcriber = Transcriber()
    private var machine = HotkeyStateMachine()
    private var spacing = SpacingPolicy()
    private var monitor: HotkeyMonitor?
    private var modelReady = false
    private var isRecording = false
    /// Bumped per recording so a late "mic is live" callback from a cancelled recording is ignored.
    private var recordingID = 0
    private var pendingTranscriptions = 0
    private var micDenied = false
    /// Transcriptions run one at a time, in order, so back-to-back dictations paste in the order spoken.
    private var lastTranscription: Task<Void, Never>?

    init(menuBar: MenuBarController) {
        self.menuBar = menuBar
    }

    func start() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                self.micDenied = !granted
                self.refreshMenu()
            }
        }
        loadModel()
        startMonitor()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.spacing.reset() }
        }
    }

    private func loadModel() {
        Task {
            do {
                try await transcriber.load { p in
                    Task { @MainActor in self.menuBar.update(.loadingModel(progress: p)) }
                }
                modelReady = true
                refreshMenu()
            } catch {
                menuBar.update(.error("Model failed to load: \(error.localizedDescription)"))
            }
        }
    }

    /// The tap needs Accessibility. Until it's granted, retry every couple of seconds.
    private func startMonitor() {
        let monitor = HotkeyMonitor { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }
        if monitor.start() {
            self.monitor = monitor
            refreshMenu()
        } else {
            menuBar.update(.error("Needs Accessibility permission"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.startMonitor() }
        }
    }

    private func handle(_ event: HotkeyEvent) {
        if case .otherInput = event { spacing.reset() }
        guard modelReady, let action = machine.handle(event) else { return }

        switch action {
        case .startRecording:
            recordingID += 1
            let id = recordingID
            let pressedAt = ProcessInfo.processInfo.systemUptime
            do {
                try recorder.start(device: MicrophoneSettings.selectedDeviceID()) { [weak self] in
                    guard let self, self.isRecording, self.recordingID == id else { return }
                    let delay = Int((ProcessInfo.processInfo.systemUptime - pressedAt) * 1000)
                    Self.log.info("mic live \(delay) ms after key down")
                    Self.play(Self.startSound)
                }
                isRecording = true
            } catch {
                menuBar.update(.error("Microphone error: \(error.localizedDescription)"))
                return
            }
        case .cancelRecording:
            guard isRecording else { return }
            _ = recorder.stop()
            isRecording = false
        case .finishRecording:
            guard isRecording else { return }
            let samples = recorder.stop()
            isRecording = false
            Self.play(Self.stopSound)
            if samples.count >= Self.minimumSamples { transcribe(samples) }
        }
        refreshMenu()
    }

    private func transcribe(_ samples: [Float]) {
        pendingTranscriptions += 1
        lastTranscription = Task { [previous = lastTranscription, transcriber] in
            await previous?.value
            let raw = (try? await transcriber.transcribe(samples)) ?? ""
            pendingTranscriptions -= 1
            if let text = TranscriptCleaner.clean(raw) {
                let now = ProcessInfo.processInfo.systemUptime
                Inserter.insert(spacing.prefix(at: now) + text)
                spacing.recordInsert(at: now)
            }
            refreshMenu()
        }
    }

    private static func play(_ sound: NSSound?) {
        sound?.stop()
        sound?.play()
    }

    private func refreshMenu() {
        if monitor == nil { return menuBar.update(.error("Needs Accessibility permission")) }
        if micDenied { return menuBar.update(.error("Needs Microphone permission")) }
        if !modelReady { return }
        if isRecording { menuBar.update(.recording) }
        else if pendingTranscriptions > 0 { menuBar.update(.transcribing) }
        else { menuBar.update(.idle) }
    }
}
