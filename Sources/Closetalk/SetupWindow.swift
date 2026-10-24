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
        model: Transcriber.isDownloaded
            ? .compiling(startedAt: Date(), firstTime: !Transcriber.hasCompiledBefore)
            : .downloading(fraction: 0),
        triedIt: false)
    var selected: SetupStep = .microphone
    /// Which way the last step change went, so the panes slide the right way.
    private(set) var movingForward = true
    /// Steps that just got done but haven't played their check yet. They show as not done until the
    /// window is back in front, so the person sees the check happen.
    private(set) var unchecked: Set<SetupStep> = []
    /// Granting a permission hands focus to a system prompt or to System Settings, so the window uses
    /// this to come back to the front before playing the check.
    var bringToFront: (() -> Void)?
    /// Check-offs only play for changes that happen while the window is open, not for the catch-up
    /// when it opens.
    private var isWindowOpen = false
    private var askedForAccessibility = false
    /// The practice field on the Try it step. Any dictation landing there finishes setup.
    var practiceText = "" {
        didSet { update { $0.triedIt = !practiceText.isEmpty } }
    }

    var microphoneDenied: Bool {
        [.denied, .restricted].contains(AVCaptureDevice.authorizationStatus(for: .audio))
    }

    /// True on a first launch, or whenever a permission has gone missing since. Call
    /// refreshPermissions() first.
    var needsSetup: Bool {
        !progress.microphoneAllowed || !progress.accessibilityAllowed || !Transcriber.hasCompiledBefore
    }

    func setSpeechModel(_ model: ModelSetup) {
        update { $0.model = model }
    }

    func refreshPermissions() {
        update {
            $0.microphoneAllowed = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            $0.accessibilityAllowed = AXIsProcessTrusted()
        }
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
    }

    /// Shows the macOS prompt the first time. After a denial macOS won't prompt again, so this opens
    /// the Microphone list in System Settings instead.
    func allowMicrophone() {
        if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async { self.refreshPermissions() }
            }
        } else {
            Self.openSettings("Privacy_Microphone")
        }
    }

    /// The first click shows the macOS prompt, which adds Closetalk to the Accessibility list and has
    /// its own button to System Settings. Later clicks go straight to System Settings.
    func openAccessibilitySettings() {
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
        movingForward = step.rawValue > selected.rawValue
        // The leaving pane picks its slide direction up from movingForward when it redraws, so change
        // the step on the next pass, after that redraw.
        DispatchQueue.main.async {
            withAnimation(.snappy(duration: 0.35)) { self.selected = step }
        }
    }

    /// Applies a change, and plays the check for any step it finishes. Try it has no check: the person
    /// stays there to read what they dictated.
    private func update(_ change: (inout SetupProgress) -> Void) {
        let before = progress
        var next = progress
        change(&next)
        guard next != progress else { return }
        progress = next
        guard isWindowOpen else { return }
        for step in [SetupStep.microphone, .accessibility, .model] where !before.isDone(step) && progress.isDone(step) {
            checkOff(step)
        }
    }

    /// Brings the window forward for a permission, plays the step's check, then slides on if that step
    /// is the one on screen.
    private func checkOff(_ step: SetupStep) {
        unchecked.insert(step)
        Task { @MainActor in
            if step != .model {
                // Gives a closing system prompt a moment, so it can't cover the window again.
                try? await Task.sleep(for: .milliseconds(400))
                bringToFront?()
            }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.spring(duration: 0.45, bounce: 0.4)) { _ = unchecked.remove(step) }
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
    }

    func show() {
        model.refreshPermissions()
        if window == nil { model.selected = model.progress.firstUnfinished ?? .tryIt }
        model.selectStartingStep()
        let window = self.window ?? makeWindow()
        self.window = window
        NSApp.setActivationPolicy(.regular)
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.refreshPermissions() }
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
