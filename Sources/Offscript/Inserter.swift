import AppKit

/// Pastes text into the focused app: put it on the clipboard, send Cmd+V, then restore the old clipboard.
/// Paste works in terminals and Electron apps where synthetic typing is slow or garbled.
@MainActor
enum Inserter {
    private static let vKeyCode: CGKeyCode = 9
    /// Long enough for a busy app to read the clipboard before we put the old contents back.
    /// User copies during this window are safe: the restore checks changeCount first.
    private static let restoreDelay: TimeInterval = 1.0

    /// The user's clipboard while a restore is pending, and the changeCount of our last write.
    /// Kept across back-to-back inserts so a second insert doesn't snapshot our own transcript.
    private static var saved: [NSPasteboardItem]?
    private static var ourChange = 0
    private static var pendingRestore: DispatchWorkItem?

    static func insert(_ text: String) {
        let pasteboard = NSPasteboard.general
        // Snapshot unless a restore is pending and nobody has touched the clipboard since our write.
        if saved == nil || pasteboard.changeCount != ourChange {
            saved = snapshot(pasteboard)
        }
        pendingRestore?.cancel()

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // Tells clipboard managers not to record this entry.
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        ourChange = pasteboard.changeCount

        postCommandV()

        let restore = DispatchWorkItem {
            defer { saved = nil; pendingRestore = nil }
            // If something else wrote to the clipboard in the meantime, leave it alone.
            guard pasteboard.changeCount == ourChange, let items = saved else { return }
            pasteboard.clearContents()
            if !items.isEmpty { pasteboard.writeObjects(items) }
        }
        pendingRestore = restore
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay, execute: restore)
    }

    /// Copies every item and every type, so images and files survive, not only text.
    private static func snapshot(_ pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        for keyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: keyDown) else { continue }
            event.flags = .maskCommand
            event.setIntegerValueField(.eventSourceUserData, value: syntheticEventTag)
            event.post(tap: .cghidEventTap)
        }
    }
}
