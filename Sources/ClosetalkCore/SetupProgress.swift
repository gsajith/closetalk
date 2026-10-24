import Foundation

/// The steps of the first-launch window, in sidebar order.
public enum SetupStep: Int, CaseIterable, Sendable {
    case microphone, accessibility, model, tryIt
}

/// Where the speech model is in its one-time setup.
public enum ModelSetup: Equatable, Sendable {
    case downloading(fraction: Double)
    /// Loading after the download. `firstTime` means Core ML is compiling for the Neural Engine,
    /// which takes about 10 minutes once; later launches load in seconds.
    case compiling(startedAt: Date, firstTime: Bool)
    case ready
    /// The last attempt failed. The app retries on its own.
    case failed(message: String)
}

/// What the first-launch window shows as done, and where Continue goes next.
public struct SetupProgress: Equatable, Sendable {
    public var microphoneAllowed: Bool
    public var accessibilityAllowed: Bool
    public var model: ModelSetup
    /// The practice field received a dictation.
    public var triedIt: Bool

    public init(microphoneAllowed: Bool, accessibilityAllowed: Bool, model: ModelSetup, triedIt: Bool) {
        self.microphoneAllowed = microphoneAllowed
        self.accessibilityAllowed = accessibilityAllowed
        self.model = model
        self.triedIt = triedIt
    }

    public func isDone(_ step: SetupStep) -> Bool {
        switch step {
        case .microphone: microphoneAllowed
        case .accessibility: accessibilityAllowed
        case .model: model == .ready
        case .tryIt: triedIt
        }
    }

    /// Try it needs everything else first; the other steps can be done in any order.
    public func isAvailable(_ step: SetupStep) -> Bool {
        guard step == .tryIt else { return true }
        return microphoneAllowed && accessibilityAllowed && model == .ready
    }

    public var firstUnfinished: SetupStep? {
        SetupStep.allCases.first { !isDone($0) && isAvailable($0) }
    }

    /// The next unfinished, available step after `step`, wrapping around. Nil when there's nowhere to go.
    public func nextUnfinished(after step: SetupStep) -> SetupStep? {
        let all = SetupStep.allCases
        let rest = all[(step.rawValue + 1)...] + all[..<step.rawValue]
        return rest.first { !isDone($0) && isAvailable($0) }
    }
}

/// Core ML reports no progress while it compiles, so the window shows elapsed time against a
/// typical duration instead (about 11 minutes on an M1 Max).
public enum CompileEstimate {
    public static let typical: TimeInterval = 600

    /// Fills on elapsed time but stops short of full, so the bar never claims to be done early.
    public static func fraction(elapsed: TimeInterval) -> Double {
        min(max(elapsed, 0) / typical, 0.95)
    }

    public static func remainingText(elapsed: TimeInterval) -> String {
        let remaining = typical - elapsed
        if remaining <= 0 { return "Taking longer than usual, still working" }
        if remaining <= 90 { return "about a minute left" }
        return "about \(Int((remaining / 60).rounded(.up))) minutes left"
    }

    public static func elapsedText(_ elapsed: TimeInterval) -> String {
        let seconds = max(Int(elapsed), 0)
        return String(format: "%d:%02d so far", seconds / 60, seconds % 60)
    }
}
