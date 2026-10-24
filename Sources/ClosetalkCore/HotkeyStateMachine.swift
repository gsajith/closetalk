import Foundation

public enum HotkeyEvent: Equatable {
    /// The dictation key went down or up. Timestamps are in seconds.
    case keyDown(TimeInterval)
    case keyUp(TimeInterval)
    /// Any key press or mouse click. While the dictation key is held this means a shortcut.
    case otherInput
}

public enum HotkeyAction: Equatable {
    case startRecording, finishRecording, cancelRecording
}

/// Push-to-talk logic for the dictation key: hold to record, release to finish.
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
        case (.idle, .keyDown(let t)):
            state = .held(since: t)
            return .startRecording
        case (.held(let since), .keyUp(let t)):
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
