import AppKit

/// The small window that records a new dictation shortcut. The event tap does the listening
/// (see HotkeyMonitor.record), so this window only shows what's happening.
@MainActor
final class ShortcutRecorderWindow: NSObject, NSWindowDelegate {
    private static let hint = "Modifier keys like right ⌘ or fn work on their own. Other keys need ⌃, ⌥ or ⌘. Esc cancels."

    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 380, height: 170),
        styleMask: [.titled, .closable], backing: .buffered, defer: false)
    private let instruction = NSTextField(labelWithString: "Press the key or keys you want to hold while you talk.")
    private let shortcutLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(wrappingLabelWithString: hint)
    private let onClose: () -> Void

    /// `current` is the shortcut in use, shown until a key is pressed. `onClose` runs however the window closes.
    init(current: String, onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
        panel.title = "Dictation key"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.delegate = self

        shortcutLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        shortcutLabel.textColor = .secondaryLabelColor
        shortcutLabel.stringValue = current
        hintLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.alignment = .center

        let stack = NSStackView(views: [instruction, shortcutLabel, hintLabel])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 20, right: 24)
        panel.contentView = stack
    }

    func show() {
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    /// Shows the modifiers held right now, or nothing between presses.
    func showHeld(_ name: String) {
        shortcutLabel.textColor = .labelColor
        shortcutLabel.stringValue = name
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.stringValue = Self.hint
    }

    func showRefused() {
        hintLabel.textColor = .systemRed
        hintLabel.stringValue = "That key needs ⌃, ⌥ or ⌘ with it, or it would stop typing."
    }

    /// Shows the saved shortcut for a moment, then closes.
    func showSaved(_ name: String) {
        instruction.stringValue = "Saved. Hold it to dictate."
        shortcutLabel.textColor = .labelColor
        shortcutLabel.stringValue = name
        hintLabel.stringValue = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.close() }
    }

    func close() {
        panel.close()
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        MainActor.assumeIsolated { onClose() }
    }
}
