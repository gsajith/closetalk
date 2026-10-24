/// The modifier key people hold to dictate. Raw values are what UserDefaults stores.
public enum DictationKey: String, CaseIterable {
    case rightCommand, rightOption, fn

    public init(storageValue: String?) {
        self = storageValue.flatMap(Self.init(rawValue:)) ?? .rightCommand
    }

    /// How the menu and status line name the key, as in "Hold right ⌘ to dictate."
    public var name: String {
        switch self {
        case .rightCommand: "right ⌘"
        case .rightOption: "right ⌥"
        case .fn: "fn"
        }
    }

    /// The virtual key code macOS reports in flagsChanged events for this key.
    public var keyCode: Int64 {
        switch self {
        case .rightCommand: 54
        case .rightOption: 61
        case .fn: 63
        }
    }

    /// The event flag bit that is set while this key is held. The right-side keys use
    /// device-dependent bits (NX_DEVICERCMDKEYMASK, NX_DEVICERALTKEYMASK) so the left key doesn't count.
    public var flagMask: UInt64 {
        switch self {
        case .rightCommand: 0x10
        case .rightOption: 0x40
        case .fn: 0x80_0000 // CGEventFlags.maskSecondaryFn
        }
    }
}
