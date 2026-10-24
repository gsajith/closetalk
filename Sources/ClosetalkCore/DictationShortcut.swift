import Foundation

/// A modifier key on one side of the keyboard. Case order is Apple's display order: fn ⌃ ⌥ ⇧ ⌘.
public enum ModifierKey: String, CaseIterable, Codable, Comparable {
    case fn, leftControl, rightControl, leftOption, rightOption, leftShift, rightShift, leftCommand, rightCommand

    public static func < (a: ModifierKey, b: ModifierKey) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }

    /// The event flag bit that is set while this key is held. The sided keys use the device-dependent
    /// bits (NX_DEVICE*KEYMASK); fn uses NX_SECONDARYFNMASK.
    var flag: UInt64 {
        switch self {
        case .fn: 0x80_0000
        case .leftControl: 0x01
        case .rightControl: 0x2000
        case .leftOption: 0x20
        case .rightOption: 0x40
        case .leftShift: 0x02
        case .rightShift: 0x04
        case .leftCommand: 0x08
        case .rightCommand: 0x10
        }
    }

    var symbol: String {
        switch self {
        case .fn: "fn"
        case .leftControl, .rightControl: "⌃"
        case .leftOption, .rightOption: "⌥"
        case .leftShift, .rightShift: "⇧"
        case .leftCommand, .rightCommand: "⌘"
        }
    }

    /// "right ⌘", "left ⌥" or "fn".
    var name: String {
        switch self {
        case .fn: symbol
        case .leftControl, .leftOption, .leftShift, .leftCommand: "left \(symbol)"
        default: "right \(symbol)"
        }
    }

    static func held(in flags: UInt64) -> Set<ModifierKey> {
        Set(allCases.filter { flags & $0.flag != 0 })
    }
}

/// What people hold to dictate.
public enum DictationShortcut: Codable, Equatable {
    /// One or more modifier keys on their own, like right ⌘. Sides count, so left ⌘ stays free.
    case modifiers(Set<ModifierKey>)
    /// A key with modifiers, like ⌃⌥Space. Either side of a modifier counts.
    case key(code: Int64, label: String, modifiers: Set<ModifierKey>)

    /// How the menu names the shortcut: "right ⌘", "right ⌥ + right ⌘", "⌃⌥Space".
    public var name: String {
        switch self {
        case .modifiers(let keys):
            return keys.sorted().map(\.name).joined(separator: " + ")
        case .key(_, let label, let modifiers):
            let symbols = Self.symbols(modifiers)
            let fn = symbols.contains("fn") ? "fn " : ""
            return fn + symbols.filter { $0 != "fn" }.joined() + label
        }
    }

    /// Nil when nothing is stored yet, or what's stored can't be read. There's no built-in default:
    /// setup asks people to choose.
    public init?(storageData: Data?) {
        guard let storageData, let shortcut = try? JSONDecoder().decode(Self.self, from: storageData) else { return nil }
        self = shortcut
    }

    public var storageData: Data {
        // Encoding a plain enum of strings and numbers can't fail.
        try! JSONEncoder().encode(self)
    }

    /// Each modifier's symbol once, in display order, so left ⌥ and right ⌥ both read as ⌥.
    static func symbols(_ keys: Set<ModifierKey>) -> [String] {
        var seen: [String] = []
        for key in keys.sorted() where !seen.contains(key.symbol) { seen.append(key.symbol) }
        return seen
    }
}

/// Keyboard input as the event tap sees it. Flags are CGEventFlags raw values.
public enum KeyInput {
    case flagsChanged(flags: UInt64)
    case keyDown(code: Int64, flags: UInt64, isRepeat: Bool)
    case keyUp(code: Int64, flags: UInt64)
}

/// Turns keyboard input into push-to-talk events for one shortcut, and says which events to hide
/// from other apps so a combo like ⌃⌥Space doesn't also type a space.
public struct ShortcutMatcher {
    public struct Output: Equatable {
        public var event: HotkeyEvent?
        public var swallow: Bool

        public init(event: HotkeyEvent? = nil, swallow: Bool = false) {
            self.event = event
            self.swallow = swallow
        }
    }

    public let shortcut: DictationShortcut
    private var held = false
    /// A key shortcut's key went down and we hid it, so its key up gets hidden too.
    private var hidingKeyUp = false

    public init(shortcut: DictationShortcut) {
        self.shortcut = shortcut
    }

    public mutating func handle(_ input: KeyInput, at time: TimeInterval) -> Output {
        switch shortcut {
        case .modifiers(let keys): handleModifiers(keys, input, time)
        case .key(let code, _, let modifiers): handleKey(code, modifiers, input, time)
        }
    }

    private mutating func handleModifiers(_ keys: Set<ModifierKey>, _ input: KeyInput, _ time: TimeInterval) -> Output {
        switch input {
        case .flagsChanged(let flags):
            let now = ModifierKey.held(in: flags)
            if !held && now == keys {
                held = true
                return Output(event: .keyDown(time))
            }
            if held && now != keys {
                held = false
                // Letting go of a shortcut key ends dictation. Adding another modifier means a shortcut.
                return Output(event: now.isSubset(of: keys) ? .keyUp(time) : .otherInput)
            }
            return Output()
        case .keyDown:
            return Output(event: .otherInput)
        case .keyUp:
            return Output()
        }
    }

    private mutating func handleKey(
        _ code: Int64, _ modifiers: Set<ModifierKey>, _ input: KeyInput, _ time: TimeInterval
    ) -> Output {
        let wanted = DictationShortcut.symbols(modifiers)
        func pressed(_ flags: UInt64) -> [String] {
            let symbols = DictationShortcut.symbols(ModifierKey.held(in: flags))
            // macOS sets the fn flag on F-key and arrow presses by itself, so only count it when asked for.
            return wanted.contains("fn") ? symbols : symbols.filter { $0 != "fn" }
        }

        switch input {
        case .keyDown(let key, let flags, let isRepeat):
            // The key still repeating after its modifier was let go shouldn't type either.
            if key == code && isRepeat && hidingKeyUp { return Output(swallow: true) }
            guard key == code, pressed(flags) == wanted else { return Output(event: .otherInput) }
            if isRepeat || held { return Output(swallow: true) }
            held = true
            hidingKeyUp = true
            return Output(event: .keyDown(time), swallow: true)
        case .keyUp(let key, _):
            guard key == code, hidingKeyUp else { return Output() }
            hidingKeyUp = false
            if !held { return Output(swallow: true) }
            held = false
            return Output(event: .keyUp(time), swallow: true)
        case .flagsChanged(let flags):
            // Letting go of a modifier before the key also ends dictation.
            guard held, !Set(wanted).isSubset(of: Set(pressed(flags))) else { return Output() }
            held = false
            return Output(event: .keyUp(time))
        }
    }
}

/// Builds a shortcut from what someone presses in the recorder window.
public struct ShortcutRecorder {
    public enum Step: Equatable {
        /// Still recording. The text names the modifiers held right now.
        case recording(String)
        case done(DictationShortcut)
        /// A key that would stop typing normally, like a plain letter. Recording continues.
        case refused
        case cancelled
    }

    private static let escape: Int64 = 53
    private static let functionKeys: [Int64: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9",
        109: "F10", 103: "F11", 111: "F12", 105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17",
        79: "F18", 80: "F19", 90: "F20",
    ]
    /// Keys macOS reports with the fn flag set whether or not fn is held.
    private static let navigationKeys: [Int64: String] = [
        123: "←", 124: "→", 125: "↓", 126: "↑", 115: "Home", 119: "End", 116: "Page Up", 121: "Page Down", 117: "⌦",
    ]
    private static let otherKeys: [Int64: String] = [49: "Space", 36: "Return", 76: "Enter", 48: "Tab", 51: "Delete"]

    /// Every modifier held at some point since the last key-free moment.
    private var peak: Set<ModifierKey> = []

    public init() {}

    /// `characters` is what the key types without modifiers, used to label letter and symbol keys.
    public mutating func handle(_ input: KeyInput, characters: String? = nil) -> Step {
        switch input {
        case .flagsChanged(let flags):
            let held = ModifierKey.held(in: flags)
            if held.isEmpty && !peak.isEmpty { return .done(.modifiers(peak)) }
            peak.formUnion(held)
            return .recording(DictationShortcut.modifiers(held).name)
        case .keyDown(let code, let flags, _):
            var modifiers = ModifierKey.held(in: flags)
            if code == Self.escape && modifiers.isEmpty { return .cancelled }
            let special = Self.functionKeys[code] ?? Self.navigationKeys[code]
            if special != nil { modifiers.remove(.fn) }
            // Without ⌃, ⌥, ⌘ or fn the key would stop typing, except F-keys, which don't type anything.
            let typingSafe = DictationShortcut.symbols(modifiers).contains { $0 != "⇧" }
            guard typingSafe || Self.functionKeys[code] != nil else {
                // Start over, so letting go of ⇧ afterwards doesn't record ⇧ on its own.
                peak = []
                return .refused
            }
            let label = special ?? Self.otherKeys[code] ?? characters.flatMap { $0.isEmpty ? nil : $0.uppercased() } ?? "Key \(code)"
            return .done(.key(code: code, label: label, modifiers: modifiers))
        case .keyUp(_, let flags):
            return .recording(DictationShortcut.modifiers(ModifierKey.held(in: flags)).name)
        }
    }
}
