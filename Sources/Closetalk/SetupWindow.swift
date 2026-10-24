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
    /// Called when a permission comes through. Granting one hands focus to a system prompt or to
    /// System Settings, so the window uses this to come back to the front.
    var onPermissionGranted: (() -> Void)?
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
        let before = progress
        update {
            $0.microphoneAllowed = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            $0.accessibilityAllowed = AXIsProcessTrusted()
        }
        let granted = (!before.microphoneAllowed && progress.microphoneAllowed)
            || (!before.accessibilityAllowed && progress.accessibilityAllowed)
        if granted { onPermissionGranted?() }
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
        if let next = progress.nextUnfinished(after: selected) { selected = next }
    }

    func goBack() {
        if let previous = SetupStep(rawValue: selected.rawValue - 1) { selected = previous }
    }

    /// Applies a change, and moves on when it finishes the step on screen. Try it stays put so the
    /// user can read what they dictated.
    private func update(_ change: (inout SetupProgress) -> Void) {
        let wasDone = progress.isDone(selected)
        var next = progress
        change(&next)
        guard next != progress else { return }
        progress = next
        if !wasDone, progress.isDone(selected), selected != .tryIt, let step = progress.nextUnfinished(after: selected) {
            selected = step
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
        model.onPermissionGranted = { [weak self] in
            // Mostly for Accessibility, which is granted in System Settings: bring the window back
            // once it ticks. Waits a moment so a closing system prompt can't cover it again.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard let self, self.window?.isVisible == true, !NSApp.isActive else { return }
                self.bringToFront()
            }
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
