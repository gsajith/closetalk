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
    private(set) var progress = SetupProgress(
        microphoneAllowed: false, accessibilityAllowed: false, model: .downloading(fraction: 0), triedIt: false)
    var selected: SetupStep = .microphone
    /// The practice field on the Try it step. Any dictation landing there finishes setup.
    var practiceText = "" {
        didSet { update { $0.triedIt = !practiceText.isEmpty } }
    }

    var microphoneDenied: Bool {
        [.denied, .restricted].contains(AVCaptureDevice.authorizationStatus(for: .audio))
    }

    /// True on a first launch, or whenever a permission has gone missing since.
    var needsSetup: Bool {
        refreshPermissions()
        return !progress.microphoneAllowed || !progress.accessibilityAllowed || !Transcriber.hasCompiledBefore
    }

    func setModel(_ model: ModelSetup) {
        update { $0.model = model }
    }

    func refreshPermissions() {
        update {
            $0.microphoneAllowed = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            $0.accessibilityAllowed = AXIsProcessTrusted()
        }
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

    func openAccessibilitySettings() {
        // Asking once adds Closetalk to the Accessibility list, so there's something to switch on.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        Self.openSettings("Privacy_Accessibility")
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

/// Owns the first-launch window. Closetalk is a menu bar app, so showing the window also has to
/// bring the app to the front.
@MainActor
final class SetupWindowController: NSObject, NSWindowDelegate {
    let model = SetupModel()
    private var window: NSWindow?
    private var poll: Timer?

    func show() {
        model.refreshPermissions()
        if !model.progress.isDone(model.selected) || window == nil {
            model.selected = model.progress.firstUnfinished ?? .tryIt
        }
        let window = self.window ?? makeWindow()
        self.window = window
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.model.refreshPermissions() }
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        poll?.invalidate()
        poll = nil
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false)
        window.title = "Welcome to Closetalk"
        window.contentView = NSHostingView(rootView: SetupView(model: model, close: { [weak window] in window?.close() }))
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }
}
