import AppKit
import AVFoundation
import ClosetalkCore
import SwiftUI

/// State behind the first-launch window. Permissions are polled while the window is open, because
/// macOS doesn't notify apps when the user flips them in System Settings. The model state comes
/// from DictationController.
@MainActor
@Observable
final class SetupModel {
    // Starts from what's on disk, so a model that's already downloaded never shows as downloading.
    private(set) var progress = SetupProgress(
        microphoneAllowed: false, accessibilityAllowed: false,
        shortcutChosen: DictationShortcutSettings.shortcut != nil,
        model: Transcriber.isDownloaded
            ? .compiling(startedAt: Date(), firstTime: !Transcriber.hasCompiledBefore)
            : .downloading(fraction: 0, startedAt: Date()),
        triedIt: false)
    var selected: SetupStep = .microphone
    /// Which way the last step change went, so the panes slide the right way.
    private(set) var movingForward = true
    /// Steps that just got done but haven't played their check yet. They show as not done until the
    /// window is back in front, so the person sees the check happen.
    private(set) var unchecked: Set<SetupStep> = []
    /// Permission steps whose button was clicked, while the person is in a system prompt or System
    /// Settings. Their button shows "Waiting…" until the permission comes through or they give up.
    private(set) var waiting: Set<SetupStep> = []
    /// Granting a permission hands focus to a system prompt or to System Settings, so the window uses
    /// this to come back to the front before playing the check.
    var bringToFront: (() -> Void)?
    /// Check-offs only play for changes that happen while the window is open, not for the catch-up
    /// when it opens.
    private var isWindowOpen = false
    private var askedForAccessibility = false
    /// Set by DictationController. Starting returns false when the event tap isn't running yet.
    var startRecordingShortcut: ((@escaping (ShortcutRecorder.Step) -> Void) -> Bool)?
    var stopRecordingShortcut: (() -> Void)?
    /// The shortcut step is listening for keys.
    private(set) var recordingShortcut = false
    /// The modifiers held right now while recording, like "right ⌥".
    private(set) var heldKeys = ""
    /// The last key pressed while recording would have stopped typing, so it wasn't saved.
    private(set) var shortcutRefused = false
    /// The practice field on the Try it step. Only a dictation landing there finishes setup, see dictationInserted().
    var practiceText = ""

    /// Stored rather than computed, so the view redraws when it changes.
    private(set) var microphoneDenied = MicrophonePermission.isDenied

    /// True on a first launch, or whenever a permission has gone missing since. Call
    /// refreshStatus() first.
    var needsSetup: Bool {
        !progress.microphoneAllowed || !progress.accessibilityAllowed || !progress.shortcutChosen
            || !Transcriber.hasCompiledBefore
    }

    func setSpeechModel(_ model: ModelSetup) {
        update { $0.model = model }
    }

    /// A dictation was just pasted. With the window in front on Try it, it landed in the practice field,
    /// which finishes setup. Typing or pasting there doesn't count: the step is about trying the key.
    func dictationInserted() {
        guard isWindowOpen, selected == .tryIt, NSApp.isActive else { return }
        update { $0.triedIt = true }
    }

    func setSampleModel(_ sample: SampleModel) {
        update { $0.sampleModel = sample }
    }

    func refreshStatus() {
        update {
            $0.microphoneAllowed = MicrophonePermission.isAllowed
            $0.accessibilityAllowed = AXIsProcessTrusted()
            $0.shortcutChosen = DictationShortcutSettings.shortcut != nil
        }
        let denied = MicrophonePermission.isDenied
        if denied != microphoneDenied { microphoneDenied = denied }
    }

    /// The window shows a step as done once its check has played.
    func showsDone(_ step: SetupStep) -> Bool {
        progress.isDone(step) && !unchecked.contains(step)
    }

    func windowOpened() {
        isWindowOpen = true
    }

    func windowClosed() {
        isWindowOpen = false
        unchecked = []
        waiting = []
        cancelRecordingShortcut()
    }

    /// Shows the macOS prompt the first time. After a denial macOS won't prompt again, so this opens
    /// the Microphone list in System Settings instead.
    func allowMicrophone() {
        waiting.insert(.microphone)
        if MicrophonePermission.canPrompt {
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async {
                    self.refreshStatus()
                    // Don't Allow ends the wait right away.
                    if !self.progress.microphoneAllowed { self.waiting.remove(.microphone) }
                }
            }
        } else {
            Self.openSettings("Privacy_Microphone")
        }
    }

    /// Coming back to Closetalk without granting the permission ends the wait, so the button works again.
    func appBecameActive() {
        refreshStatus()
        waiting = waiting.filter(progress.isDone)
    }

    /// Listens for the next key or combo pressed anywhere. Saving it is DictationController's job; this
    /// only follows along for the shortcut step.
    func recordShortcut() {
        heldKeys = ""
        shortcutRefused = false
        recordingShortcut = startRecordingShortcut? { [weak self] step in
            guard let self else { return }
            switch step {
            case .recording(let held):
                heldKeys = held
                shortcutRefused = false
            case .refused: shortcutRefused = true
            case .cancelled, .done: recordingShortcut = false
            }
        } ?? false
    }

    func cancelRecordingShortcut() {
        guard recordingShortcut else { return }
        recordingShortcut = false
        stopRecordingShortcut?()
    }

    /// The first click shows the macOS prompt, which adds Closetalk to the Accessibility list and has
    /// its own button to System Settings. Later clicks go straight to System Settings.
    func openAccessibilitySettings() {
        waiting.insert(.accessibility)
        if askedForAccessibility {
            Self.openSettings("Privacy_Accessibility")
        } else {
            askedForAccessibility = true
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
    }

    /// Opening the window lands on the first thing left to do, unless the step on screen still needs work.
    func selectStartingStep() {
        if progress.isDone(selected) { selected = progress.firstUnfinished ?? .tryIt }
    }

    func goToNext() {
        if let next = progress.nextUnfinished(after: selected) { go(to: next) }
    }

    func goBack() {
        if let previous = SetupStep(rawValue: selected.rawValue - 1) { go(to: previous) }
    }

    /// Slides to `step`, forward or back depending on where it sits in the list.
    func go(to step: SetupStep) {
        guard step != selected else { return }
        cancelRecordingShortcut()
        movingForward = step.rawValue > selected.rawValue
        // The leaving pane picks its slide direction up from movingForward when it redraws, so change
        // the step on the next pass, after that redraw.
        DispatchQueue.main.async {
            withAnimation(.snappy(duration: 0.35)) { self.selected = step }
        }
    }

    /// Applies a change, and plays the check for any step it finishes.
    private func update(_ change: (inout SetupProgress) -> Void) {
        let before = progress
        var next = progress
        change(&next)
        guard next != progress else { return }
        progress = next
        guard isWindowOpen else { return }
        for step in SetupStep.allCases where !before.isDone(step) && progress.isDone(step) {
            checkOff(step)
        }
        if before.sampleModel != .ready && progress.sampleModel == .ready { goTryTheSampleModel() }
    }

    /// The sample model unlocks Try it, so the model step moves on to it after a moment. The model step
    /// keeps its spinner until the full model is ready.
    private func goTryTheSampleModel() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard isWindowOpen, selected == .model, progress.isAvailable(.tryIt), !progress.isDone(.tryIt) else { return }
            go(to: .tryIt)
        }
    }

    /// Brings the window forward for a permission, plays the step's check, then slides on if that step
    /// is the one on screen.
    private func checkOff(_ step: SetupStep) {
        unchecked.insert(step)
        Task { @MainActor in
            if step == .microphone || step == .accessibility {
                // Gives a closing system prompt a moment, so it can't cover the window again.
                try? await Task.sleep(for: .milliseconds(400))
                bringToFront?()
            }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.spring(duration: 0.45, bounce: 0.4)) {
                unchecked.remove(step)
                waiting.remove(step)
            }
            try? await Task.sleep(for: .seconds(1))
            guard isWindowOpen, selected == step, let next = progress.nextUnfinished(after: step) else { return }
            go(to: next)
        }
    }

    private static func openSettings(_ pane: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
    }
}

/// Owns the first-launch window. Closetalk is a menu bar app, and macOS skips menu bar apps when it
/// hands focus back after a system prompt closes, so the window would drop behind the last regular
/// app. While the window is open, Closetalk runs as a regular app (with a Dock icon) instead.
@MainActor
final class SetupWindowController: NSObject, NSWindowDelegate {
    let model = SetupModel()
    private var window: NSWindow?
    private var poll: Timer?

    override init() {
        super.init()
        Self.installMainMenu()
        model.bringToFront = { [weak self] in
            guard let self, self.window?.isVisible == true else { return }
            self.bringToFront()
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.window?.isVisible == true else { return }
                self.model.appBecameActive()
            }
        }
    }

    /// Opens on `step` when given and available, like the dictation key from the menu. Otherwise on the
    /// first thing left to do.
    func show(at step: SetupStep? = nil) {
        model.refreshStatus()
        if window == nil { model.selected = model.progress.firstUnfinished ?? .tryIt }
        if let step, model.progress.isAvailable(step) {
            model.selected = step
        } else {
            model.selectStartingStep()
        }
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.setActivationPolicy(.regular)
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.refreshStatus() }
        }
        model.windowOpened()
        bringToFront()
    }

    /// macOS can decline to activate an app nobody clicked on, so also order the window in
    /// regardless; it then still appears on top, and becomes key once the user clicks it.
    private func bringToFront() {
        guard let window else { return }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    /// Text fields paste through the Edit menu's ⌘V, and dictation pastes with ⌘V, so the practice
    /// field needs an Edit menu. It only shows in the menu bar while the window is open.
    private static func installMainMenu() {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Closetalk", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let main = NSMenu()
        for submenu in [appMenu, editMenu] {
            let item = NSMenuItem()
            item.submenu = submenu
            main.addItem(item)
        }
        NSApp.mainMenu = main
    }

    func windowWillClose(_ notification: Notification) {
        poll?.invalidate()
        poll = nil
        model.practiceText = "" // Each visit starts with an empty practice field.
        model.windowClosed()
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false)
        window.title = "Welcome to Closetalk"
        window.contentView = NSHostingView(rootView: SetupView(model: model, close: { [weak window] in window?.close() }))
        window.isReleasedWhenClosed = false
        // Open on the Space the user is looking at, not the one the app happened to launch on.
        window.collectionBehavior = [.moveToActiveSpace]
        window.delegate = self
        window.center()
        return window
    }
}
