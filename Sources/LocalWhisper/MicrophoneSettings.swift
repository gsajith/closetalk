import CoreAudio
import Foundation
import LocalWhisperCore

/// Lists input devices through Core Audio and stores the user's mic choice in UserDefaults.
enum MicrophoneSettings {
    private static let defaultsKey = "microphone"

    static var preference: MicrophonePreference {
        get { MicrophonePreference(storageValue: UserDefaults.standard.string(forKey: defaultsKey)) }
        set { UserDefaults.standard.set(newValue.storageValue, forKey: defaultsKey) }
    }

    /// The device to record from right now, or nil for the system default input.
    static func selectedDeviceID() -> AudioDeviceID? {
        let all = available()
        guard let mic = preference.resolve(among: all.map(\.mic)) else { return nil }
        return all.first(where: { $0.mic == mic })?.id
    }

    /// Every device with at least one input channel.
    static func available() -> [(mic: Microphone, id: AudioDeviceID)] {
        let ids: [AudioDeviceID] = readArray(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDevices)
        return ids.compactMap { id in
            let inputStreams: [AudioStreamID] = readArray(id, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
            guard !inputStreams.isEmpty,
                  let uid: CFString = readValue(id, kAudioDevicePropertyDeviceUID),
                  let name: CFString = readValue(id, kAudioObjectPropertyName)
            else { return nil }
            let transport: UInt32 = readValue(id, kAudioDevicePropertyTransportType) ?? 0
            return (Microphone(uid: uid as String, name: name as String, isBuiltIn: transport == kAudioDeviceTransportTypeBuiltIn), id)
        }
    }

    static func systemDefaultInputID() -> AudioDeviceID? {
        readValue(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultInputDevice)
    }

    private static func address(_ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func readValue<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                                     scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> T? {
        var addr = address(selector, scope)
        var size = UInt32(MemoryLayout<T>.size)
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        guard AudioObjectGetPropertyData(object, &addr, 0, nil, &size, pointer) == noErr else { return nil }
        return pointer.move()
    }

    private static func readArray<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                                     scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> [T] {
        var addr = address(selector, scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<T>.stride
        let pointer = UnsafeMutablePointer<T>.allocate(capacity: count)
        defer { pointer.deallocate() }
        guard AudioObjectGetPropertyData(object, &addr, 0, nil, &size, pointer) == noErr else { return [] }
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }
}
