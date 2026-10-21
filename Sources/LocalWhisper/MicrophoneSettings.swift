import AVFoundation
import CoreAudio
import LocalWhisperCore

/// Lists microphones and stores the user's choice in UserDefaults.
enum MicrophoneSettings {
    private static let defaultsKey = "microphone"

    static var preference: MicrophonePreference {
        get { MicrophonePreference(storageValue: UserDefaults.standard.string(forKey: defaultsKey)) }
        set { UserDefaults.standard.set(newValue.storageValue, forKey: defaultsKey) }
    }

    /// The device to record from right now, or nil for the system default input.
    static func selectedDevice() -> AVCaptureDevice? {
        let all = available()
        guard let mic = preference.resolve(among: all.map(\.mic)) else { return nil }
        return all.first(where: { $0.mic == mic })?.device
    }

    static func available() -> [(mic: Microphone, device: AVCaptureDevice)] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone], mediaType: .audio, position: .unspecified)
            .devices
            .map { device in
                let isBuiltIn = UInt32(bitPattern: device.transportType) == kAudioDeviceTransportTypeBuiltIn
                return (Microphone(uid: device.uniqueID, name: device.localizedName, isBuiltIn: isBuiltIn), device)
            }
    }
}
