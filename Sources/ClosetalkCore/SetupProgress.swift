import Foundation

/// The steps of the first-launch window, in sidebar order.
public enum SetupStep: Int, CaseIterable, Sendable {
    case microphone, accessibility, shortcut, model, tryIt
}

/// Where the speech model is in its one-time setup.
public enum ModelSetup: Equatable, Sendable {
    /// `startedAt` lets the window estimate the time left from the download's speed.
    case downloading(fraction: Double, startedAt: Date)
    /// Loading after the download. `firstTime` means Core ML is compiling for the Neural Engine,
    /// which takes about 10 minutes once; later launches load in seconds.
    case compiling(startedAt: Date, firstTime: Bool)
    case ready
    /// The last attempt failed. The app retries on its own.
    case failed(message: String)
}

/// The small model a first launch loads so people can try dictation before the full one is ready.
public enum SampleModel: Equatable, Sendable {
    /// Not needed (the full model was ready before), or it failed to load.
    case none
    case loading
    case ready
}

/// What the first-launch window shows as done, and where Continue goes next.
public struct SetupProgress: Equatable, Sendable {
    public var microphoneAllowed: Bool
    public var accessibilityAllowed: Bool
    /// A dictation shortcut is saved.
    public var shortcutChosen: Bool
    /// The full speech model's state. A first launch also loads a small sample model, so people can try
    /// dictation while the full one downloads and compiles.
    public var model: ModelSetup
    public var sampleModel: SampleModel
    /// The practice field received a dictation.
    public var triedIt: Bool

    public init(microphoneAllowed: Bool, accessibilityAllowed: Bool, shortcutChosen: Bool, model: ModelSetup,
                sampleModel: SampleModel = .none, triedIt: Bool) {
        self.microphoneAllowed = microphoneAllowed
        self.accessibilityAllowed = accessibilityAllowed
        self.shortcutChosen = shortcutChosen
        self.model = model
        self.sampleModel = sampleModel
        self.triedIt = triedIt
    }

    public func isDone(_ step: SetupStep) -> Bool {
        switch step {
        case .microphone: microphoneAllowed
        case .accessibility: accessibilityAllowed
        case .shortcut: shortcutChosen
        case .model: model == .ready
        case .tryIt: triedIt
        }
    }

    /// Recording a shortcut listens through the event tap, which needs Accessibility. Try it needs the
    /// other steps, except that the sample model is enough. The rest can be done in any order.
    public func isAvailable(_ step: SetupStep) -> Bool {
        switch step {
        case .shortcut: accessibilityAllowed
        case .tryIt: microphoneAllowed && accessibilityAllowed && shortcutChosen && (model == .ready || sampleModel == .ready)
        default: true
        }
    }

    public var firstUnfinished: SetupStep? {
        SetupStep.allCases.first(where: isOpen)
    }

    /// The next unfinished, available step after `step`, wrapping around. Nil when there's nowhere to go.
    public func nextUnfinished(after step: SetupStep) -> SetupStep? {
        let all = SetupStep.allCases
        let rest = all[(step.rawValue + 1)...] + all[..<step.rawValue]
        return rest.first(where: isOpen)
    }

    /// Still to do, and not locked.
    private func isOpen(_ step: SetupStep) -> Bool {
        !isDone(step) && isAvailable(step)
    }
}

/// How long until the full speech model is ready, shown while it downloads.
public enum ModelEstimate {
    /// The download's time left at its current speed, plus a typical first compile. Nil while there's
    /// too little to go on, and outside the download.
    public static func remaining(_ model: ModelSetup, at now: Date) -> TimeInterval? {
        guard case .downloading(let fraction, let startedAt) = model else { return nil }
        let elapsed = now.timeIntervalSince(startedAt)
        guard fraction >= 0.02, elapsed >= 3 else { return nil }
        return elapsed * (1 - fraction) / fraction + CompileEstimate.typical
    }

    public static func text(_ remaining: TimeInterval) -> String {
        remaining <= 90 ? "About a minute left" : "About \(Int((remaining / 60).rounded(.up))) minutes left"
    }
}

/// Core ML reports no progress while it compiles, so the window shows elapsed time against a
/// typical duration instead. It took about 11 minutes on an M1 Max; the window says about 10.
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
