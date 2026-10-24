import Carbon

/// The current keyboard layout's key map, for naming keys like D or ; in the shortcut recorder.
/// Reading the layout goes through the input source manager, which asserts it runs on the main thread
/// (asking from the event tap's thread crashed the app), so it's read there when recording starts.
/// Translating keys with the copy works on any thread.
struct KeyboardLayout {
    private let data: Data
    private let keyboardType: UInt32

    @MainActor static func current() -> KeyboardLayout? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        // Bridging to Data copies the bytes, so they outlive the input source.
        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        return KeyboardLayout(data: data, keyboardType: UInt32(LMGetKbdType()))
    }

    /// What the key types with no modifiers held, or nil for keys that type nothing visible, like F-keys,
    /// which come back as control characters.
    func characters(for keyCode: Int64) -> String? {
        // Any app can post a key event, with any code. Out of range means no key, not a crash.
        guard let key = UInt16(exactly: keyCode) else { return nil }
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = data.withUnsafeBytes { raw in
            UCKeyTranslate(
                raw.baseAddress!.assumingMemoryBound(to: UCKeyboardLayout.self), key,
                UInt16(kUCKeyActionDisplay), 0, keyboardType, OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState, characters.count, &length, &characters)
        }
        guard status == noErr, length > 0 else { return nil }
        let text = String(utf16CodeUnits: characters, count: length)
        let invisible = CharacterSet.controlCharacters.union(.whitespaces)
        return text.unicodeScalars.contains { !invisible.contains($0) } ? text : nil
    }
}
