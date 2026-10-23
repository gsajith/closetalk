import Foundation

public struct Microphone: Equatable {
    public let uid: String
    public let name: String
    public let isBuiltIn: Bool

    public init(uid: String, name: String, isBuiltIn: Bool) {
        self.uid = uid
        self.name = name
        self.isBuiltIn = isBuiltIn
    }
}

/// Which mic to record from. Defaults to the built-in mic: it starts instantly,
/// where Bluetooth headsets take time to switch into two-way mode on every recording.
public enum MicrophonePreference: Equatable {
    case builtIn
    case systemDefault
    case device(uid: String)

    /// Returns the mic to use, or nil to use the system default input.
    /// A chosen device that's no longer connected falls back to the built-in mic.
    public func resolve(among mics: [Microphone]) -> Microphone? {
        let builtIn = mics.first(where: \.isBuiltIn)
        switch self {
        case .builtIn: return builtIn
        case .systemDefault: return nil
        case .device(let uid): return mics.first(where: { $0.uid == uid }) ?? builtIn
        }
    }

    public init(storageValue: String?) {
        switch storageValue {
        case nil, "builtIn": self = .builtIn
        case "systemDefault": self = .systemDefault
        case let uid?: self = .device(uid: uid)
        }
    }

    public var storageValue: String {
        switch self {
        case .builtIn: "builtIn"
        case .systemDefault: "systemDefault"
        case .device(let uid): uid
        }
    }
}
