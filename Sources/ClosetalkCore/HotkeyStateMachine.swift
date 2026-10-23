import Foundation

public enum HotkeyEvent {
    /// Timestamps are in seconds.
    case rightCommandDown(TimeInterval)
    case rightCommandUp(TimeInterval)
    /// Any key press or mouse click. While right Command is held this means a shortcut.
    case otherInput
}

public enum HotkeyAction: Equatable {
    case startRecording, finishRecording, cancelRecording
}

/// Push-to-talk logic for right Command: hold to record, release to finish.
/// A tap shorter than `minimumHold` or any other input while held cancels.
public struct HotkeyStateMachine {
    private enum State { case idle, held(since: TimeInterval) }

    private let minimumHold: TimeInterval
    private var state = State.idle

    public init(minimumHold: TimeInterval = 0.2) {
        self.minimumHold = minimumHold
    }

    public mutating func handle(_ event: HotkeyEvent) -> HotkeyAction? {
        switch (state, event) {
        case (.idle, .rightCommandDown(let t)):
            state = .held(since: t)
            return .startRecording
        case (.held(let since), .rightCommandUp(let t)):
            state = .idle
            return t - since < minimumHold ? .cancelRecording : .finishRecording
        case (.held, .otherInput):
            state = .idle
            return .cancelRecording
        default:
            return nil
        }
    }
}
