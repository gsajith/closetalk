import AppKit
import ClosetalkCore

/// Marks events we post ourselves (the Cmd+V paste) so the tap can skip them.
let syntheticEventTag: Int64 = 0x4C57

/// Watches global keyboard and mouse input through a CGEvent tap and reports HotkeyEvents on the main thread.
/// It's an active tap (needs Accessibility, not Input Monitoring). It passes events through, except a key
/// shortcut's own key presses, and every key press while the recorder window is recording a new shortcut.
/// The tap runs on its own thread: an active tap holds up every keystroke on the system until it returns,
/// so it must never wait on the main thread (e.g. while the mic starts).
final class HotkeyMonitor {
    private enum Mode {
        /// Nil until a shortcut is chosen: keys still count as other input, but nothing dictates.
        case listening(ShortcutMatcher?)
        case recording(ShortcutRecorder, layout: KeyboardLayout?, onStep: (ShortcutRecorder.Step) -> Void)
    }

    /// NX_SYSDEFINED: media and brightness keys arrive as this type, not keyDown.
    private static let systemDefined = CGEventType(rawValue: 14)!
    /// NX_SUBTYPE_AUX_CONTROL_BUTTONS: the media/brightness key subtype of systemDefined events.
    private static let auxControlButtons: Int16 = 8
    private static let ownPID = Int64(ProcessInfo.processInfo.processIdentifier)

    private static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    private let onEvent: (HotkeyEvent) -> Void
    private var tap: CFMachPort?
    /// Read and changed on the tap thread, swapped from the main thread, so guarded by `lock`.
    private var mode: Mode
    private let lock = NSLock()

    init(shortcut: DictationShortcut?, onEvent: @escaping (HotkeyEvent) -> Void) {
        self.onEvent = onEvent
        mode = .listening(shortcut.map(ShortcutMatcher.init))
    }

    /// Returns false when the tap can't be created, which means Accessibility isn't granted yet.
    func start() -> Bool {
        let types: [CGEventType] = [
            .flagsChanged, .keyDown, .keyUp, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel,
            Self.systemDefined,
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userInfo!).takeUnretainedValue()
                return monitor.handle(type: type, event: event) ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        let thread = Thread {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        thread.name = "Closetalk.HotkeyTap"
        thread.qualityOfService = .userInteractive
        thread.start()
        return true
    }

    /// Listens for `shortcut` from the next key press on, ending any recording.
    func listen(for shortcut: DictationShortcut?) {
        lock.withLock { mode = .listening(shortcut.map(ShortcutMatcher.init)) }
    }

    /// Records the next shortcut pressed anywhere. `onStep` runs on the main thread. On done or cancelled
    /// the monitor stops recording, and the caller decides what to listen for with `listen(for:)`.
    @MainActor func record(onStep: @escaping (ShortcutRecorder.Step) -> Void) {
        let layout = KeyboardLayout.current()
        lock.withLock { mode = .recording(ShortcutRecorder(), layout: layout, onStep: onStep) }
    }

    private func emit(_ event: HotkeyEvent) {
        DispatchQueue.main.async { self.onEvent(event) }
    }

    /// Returns true to hide the event from every other app.
    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // macOS turns slow or interrupted taps off; turn it back on.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            resyncAfterTapWasOff()
            return false
        }
        if event.getIntegerValueField(.eventSourceUserData) == syntheticEventTag { return false }

        let code = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags.rawValue
        let input: KeyInput? = switch type {
        case .flagsChanged: .flagsChanged(flags: flags)
        case .keyDown: .keyDown(code: code, flags: flags, isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
        case .keyUp: .keyUp(code: code, flags: flags)
        default: nil
        }

        lock.lock()
        defer { lock.unlock() }
        switch mode {
        case .recording(var recorder, let layout, let onStep):
            guard let input else { return false }
            // Not NSEvent.charactersIgnoringModifiers: it asks the input source manager, which crashes off
            // the main thread. See KeyboardLayout.
            let characters = type == .keyDown ? layout?.characters(for: code) : nil
            let step = recorder.handle(input, characters: characters)
            switch step {
            case .done, .cancelled: mode = .listening(DictationShortcutSettings.shortcut.map(ShortcutMatcher.init))
            case .recording, .refused: mode = .recording(recorder, layout: layout, onStep: onStep)
            }
            DispatchQueue.main.async { onStep(step) }
            // Keys pressed while recording are meant for the recorder, not the app in front.
            return type == .keyDown || type == .keyUp

        case .listening(let current):
            if type != .flagsChanged && event.getIntegerValueField(.eventTargetUnixProcessID) == Self.ownPID {
                // Clicks and keys in our own menu can't move the cursor in the app being dictated into.
                return false
            }
            if let input {
                guard var matcher = current else {
                    if case .keyDown = input { emit(.otherInput) }
                    return false
                }
                let output = matcher.handle(input, at: Self.now)
                mode = .listening(matcher)
                if let hotkeyEvent = output.event { emit(hotkeyEvent) }
                return output.swallow
            }
            switch type {
            case .scrollWheel:
                // Momentum scrolling keeps firing after the fingers lift; only a real scroll counts.
                if event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 0 { emit(.otherInput) }
            case Self.systemDefined:
                if NSEvent(cgEvent: event)?.subtype.rawValue == Self.auxControlButtons { emit(.otherInput) }
            default:
                emit(.otherInput)
            }
            return false
        }
    }

    /// A release that happened while the tap was off would leave a recording running forever, so replay the
    /// current key state through the matcher.
    private func resyncAfterTapWasOff() {
        lock.lock()
        defer { lock.unlock() }
        guard case .listening(var matcher?) = mode else { return }
        let flags = CGEventSource.flagsState(.combinedSessionState).rawValue
        var events = [matcher.handle(.flagsChanged(flags: flags), at: Self.now).event]
        // The stored code comes from a key event, so it fits, but a bad value shouldn't crash the tap.
        if case .key(let code, _, _) = matcher.shortcut, let key = CGKeyCode(exactly: code),
           !CGEventSource.keyState(.combinedSessionState, key: key) {
            events.append(matcher.handle(.keyUp(code: code, flags: flags), at: Self.now).event)
        }
        mode = .listening(matcher)
        events.compactMap { $0 }.forEach(emit)
    }
}
