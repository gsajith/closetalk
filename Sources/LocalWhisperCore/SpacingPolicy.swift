import Foundation

/// Decides whether a dictation needs a leading space so back-to-back dictations don't run together.
public struct SpacingPolicy {
    private let window: TimeInterval
    private var lastInsert: TimeInterval?

    public init(window: TimeInterval = 60) {
        self.window = window
    }

    public func prefix(at now: TimeInterval) -> String {
        guard let lastInsert, now - lastInsert < window else { return "" }
        return " "
    }

    public mutating func recordInsert(at now: TimeInterval) {
        lastInsert = now
    }

    /// Call when the user types, clicks, or switches apps: the cursor may have moved.
    public mutating func reset() {
        lastInsert = nil
    }
}
