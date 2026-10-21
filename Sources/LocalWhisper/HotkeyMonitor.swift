import AppKit
import LocalWhisperCore

/// Marks events we post ourselves (the Cmd+V paste) so the tap can skip them.
let syntheticEventTag: Int64 = 0x4C57

/// Watches global keyboard and mouse input through a CGEvent tap and reports HotkeyEvents on the main thread.
/// It's an active tap (needs Accessibility, not Input Monitoring) but passes every event through unchanged.
/// The tap runs on its own thread: an active tap holds up every keystroke on the system until it returns,
/// so it must never wait on the main thread (e.g. while the mic starts).
final class HotkeyMonitor {
    private static let rightCommandKeyCode: Int64 = 54
    /// Device-dependent flag bit for the right Command key (NX_DEVICERCMDKEYMASK).
    private static let rightCommandFlag: UInt64 = 0x10

    private let onEvent: (HotkeyEvent) -> Void
    private var tap: CFMachPort?

    init(onEvent: @escaping (HotkeyEvent) -> Void) {
        self.onEvent = onEvent
    }

    /// Returns false when the tap can't be created, which means Accessibility isn't granted yet.
    func start() -> Bool {
        let types: [CGEventType] = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userInfo!).takeUnretainedValue()
                monitor.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
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
        thread.name = "LocalWhisper.HotkeyTap"
        thread.qualityOfService = .userInteractive
        thread.start()
        return true
    }

    private func emit(_ event: HotkeyEvent) {
        DispatchQueue.main.async { self.onEvent(event) }
    }

    private static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    private static var rightCommandIsDown: Bool {
        CGEventSource.flagsState(.combinedSessionState).rawValue & rightCommandFlag != 0
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // macOS turns slow or interrupted taps off; turn it back on.
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            // A release that happened while we were off would leave a recording running forever.
            if !Self.rightCommandIsDown { emit(.rightCommandUp(Self.now)) }
        case _ where event.getIntegerValueField(.eventSourceUserData) == syntheticEventTag:
            break
        case .flagsChanged:
            guard event.getIntegerValueField(.keyboardEventKeycode) == Self.rightCommandKeyCode else { return }
            let isDown = event.flags.rawValue & Self.rightCommandFlag != 0
            emit(isDown ? .rightCommandDown(Self.now) : .rightCommandUp(Self.now))
        default:
            emit(.otherInput)
        }
    }
}
