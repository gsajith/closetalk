import AppKit
import AVFoundation
import ClosetalkCore
import os

/// Connects the hotkey to recording, transcription, and pasting, and keeps the menu bar icon in sync.
/// Everything here runs on the main thread; only transcription runs elsewhere.
@MainActor
final class DictationController {
    /// Clips shorter than a quarter second are almost always accidental.
    private static let minimumSamples = Recorder.sampleRate / 4
    private nonisolated static let log = Logger(subsystem: "dev.gsajith.Closetalk", category: "dictation")
    /// "Talk now" once the mic is live, and a different sound when recording ends.
    private static let startSound = NSSound(named: "Tink")
    private static let stopSound = NSSound(named: "Pop")
    /// Safety net if a key release never reaches us (e.g. the screen locked mid-hold).
    private static let maxRecordingLength: TimeInterval = 5 * 60

    private let menuBar: MenuBarController
    private let setup: SetupModel
    private let recorder = Recorder()
    private let transcriber = Transcriber()
    private var machine = HotkeyStateMachine()
    private var spacing = SpacingPolicy()
    private var monitor: HotkeyMonitor?
    /// Open while someone records a new shortcut.
    private var shortcutWindow: ShortcutRecorderWindow?
    private var modelReady = false
    private var isRecording = false
    /// Bumped per recording so a late "mic is live" callback from a cancelled recording is ignored.
    private var recordingID = 0
    private var pendingTranscriptions = 0
    private var loadProgress: Double?
    private var modelError: String?
    private var recordingTimeout: DispatchWorkItem?
    /// Transcriptions run one at a time, in order, so back-to-back dictations paste in the order spoken.
    private var lastTranscription: Task<Void, Never>?

    init(menuBar: MenuBarController, setup: SetupModel) {
        self.menuBar = menuBar
        self.setup = setup
        menuBar.onChangeShortcut = { [weak self] in self?.recordShortcut() }
    }

    /// Permissions are requested from the setup window, not here.
    func start() {
        loadModel()
        startMonitor()
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Self.log.debug("spacing reset: activated \(app?.bundleIdentifier ?? "?", privacy: .public)")
            MainActor.assumeIsolated { self?.spacing.reset() }
        }
        // A locked or sleeping Mac can swallow the key release, so stop listening then.
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.handle(.otherInput) }
            }
        }
    }

    /// Loads the model, retrying every 30 s. Failures are often a dropped connection during the first download.
    private func loadModel() {
        Task {
            while !modelReady {
                modelError = nil
                // Checked before loading: the load itself records that the first compile happened.
                let firstTime = !Transcriber.hasCompiledBefore
                do {
                    try await transcriber.load { p in
                        Task { @MainActor in
                            // A late progress report must not undo "ready".
                            guard !self.modelReady else { return }
                            self.loadProgress = p
                            self.setup.setModel(p.map { .downloading(fraction: $0) }
                                ?? .compiling(startedAt: Date(), firstTime: firstTime))
                            self.refreshMenu()
                        }
                    }
                    modelReady = true
                    setup.setModel(.ready)
                } catch {
                    Self.log.error("model load failed: \(error.localizedDescription, privacy: .public)")
                    modelError = "Model failed to load, retrying in 30 s: \(error.localizedDescription)"
                    setup.setModel(.failed(message: error.localizedDescription))
                    refreshMenu()
                    try? await Task.sleep(for: .seconds(30))
                }
            }
            refreshMenu()
        }
    }

    /// The tap needs Accessibility. Until it's granted, retry every couple of seconds. Trying to create
    /// the tap without it makes macOS show its own prompt, so wait until it's on: the setup window asks.
    private func startMonitor() {
        let monitor = HotkeyMonitor(shortcut: DictationShortcutSettings.shortcut) { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event) }
        }
        if AXIsProcessTrusted(), monitor.start() {
            self.monitor = monitor
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.startMonitor() }
        }
        refreshMenu()
    }

    /// Opens the recorder window. The event tap stops dictating and records keys until it closes.
    private func recordShortcut() {
        guard let monitor else { return refreshMenu() }
        if let shortcutWindow { return shortcutWindow.show() }
        let window = ShortcutRecorderWindow(current: DictationShortcutSettings.shortcut.name) { [weak self] in
            // Closed without saving, or closed after saving: either way go back to the saved shortcut.
            guard let self, shortcutWindow != nil else { return }
            shortcutWindow = nil
            monitor.listen(for: DictationShortcutSettings.shortcut)
        }
        shortcutWindow = window
        window.show()
        monitor.record { [weak self] step in
            MainActor.assumeIsolated { self?.handleRecorder(step) }
        }
    }

    private func handleRecorder(_ step: ShortcutRecorder.Step) {
        switch step {
        case .recording(let held): shortcutWindow?.showHeld(held)
        case .refused: shortcutWindow?.showRefused()
        case .cancelled: shortcutWindow?.close()
        case .done(let shortcut):
            DictationShortcutSettings.shortcut = shortcut
            monitor?.listen(for: shortcut)
            let window = shortcutWindow
            // Cleared first so closing the window doesn't reset the listener mid-hold.
            shortcutWindow = nil
            window?.showSaved(shortcut.name)
            refreshMenu()
        }
    }

    private func handle(_ event: HotkeyEvent) {
        if case .otherInput = event {
            // Every key press, click and scroll lands here, so this only logs at debug level.
            Self.log.debug("spacing reset: key or click")
            spacing.reset()
        }
        guard modelReady, let action = machine.handle(event) else { return }

        switch action {
        case .startRecording:
            recordingID += 1
            let id = recordingID
            let pressedAt = ProcessInfo.processInfo.systemUptime
            do {
                try recorder.start(device: MicrophoneSettings.selectedDevice()) { [weak self] in
                    guard let self, self.isRecording, self.recordingID == id else { return }
                    let delay = Int((ProcessInfo.processInfo.systemUptime - pressedAt) * 1000)
                    Self.log.notice("mic live \(delay) ms after key down")
                    Self.play(Self.startSound)
                }
                isRecording = true
                let timeout = DispatchWorkItem { [weak self] in
                    guard let self, self.isRecording, self.recordingID == id else { return }
                    Self.log.notice("recording hit the length limit, cancelling")
                    self.handle(.otherInput)
                }
                recordingTimeout = timeout
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.maxRecordingLength, execute: timeout)
            } catch {
                menuBar.update(.error("Microphone error: \(error.localizedDescription)"))
                return
            }
        case .cancelRecording:
            guard isRecording else { return }
            _ = recorder.stop()
            isRecording = false
            recordingTimeout?.cancel()
        case .finishRecording:
            guard isRecording else { return }
            let samples = recorder.stop()
            isRecording = false
            recordingTimeout?.cancel()
            Self.play(Self.stopSound)
            if samples.count >= Self.minimumSamples { transcribe(samples) }
        }
        refreshMenu()
    }

    private func transcribe(_ samples: [Float]) {
        pendingTranscriptions += 1
        lastTranscription = Task { [previous = lastTranscription, transcriber] in
            await previous?.value
            let started = ProcessInfo.processInfo.systemUptime
            var raw = ""
            do {
                raw = try await transcriber.transcribe(samples)
            } catch {
                Self.log.error("transcription failed: \(error.localizedDescription, privacy: .public)")
            }
            let elapsed = Int((ProcessInfo.processInfo.systemUptime - started) * 1000)
            let audioLength = samples.count * 1000 / Recorder.sampleRate
            Self.log.notice("transcribed \(audioLength) ms of audio in \(elapsed) ms")
            pendingTranscriptions -= 1
            if let text = TranscriptCleaner.clean(raw) {
                let now = ProcessInfo.processInfo.systemUptime
                let prefix = spacing.prefix(at: now)
                Self.log.notice("insert \(text.count) chars, leading space: \(!prefix.isEmpty)")
                Inserter.insert(prefix + text)
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
        menuBar.update(state)
    }

    private var state: AppState {
        if monitor == nil { return .error("Needs Accessibility permission") }
        // Checked fresh each time, so turning the mic on in System Settings clears it without a relaunch.
        if [.denied, .restricted].contains(AVCaptureDevice.authorizationStatus(for: .audio)) {
            return .error("Needs Microphone permission")
        }
        if let modelError { return .error(modelError) }
        if !modelReady { return .loadingModel(progress: loadProgress) }
        if isRecording { return .recording }
        return pendingTranscriptions > 0 ? .transcribing : .idle
    }
}
