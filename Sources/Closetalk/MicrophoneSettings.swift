import AVFoundation
import CoreAudio
import ClosetalkCore

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

/// Reads the microphone permission from two APIs, because neither is right on its own.
/// AVCaptureDevice.authorizationStatus keeps its first answer for the life of the process, so it never
/// sees the mic turned on in System Settings. AVAudioApplication.recordPermission does, but still says
/// undetermined for a moment after Don't Allow.
enum MicrophonePermission {
    static var isAllowed: Bool {
        AVAudioApplication.shared.recordPermission == .granted
            || AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static var isDenied: Bool {
        !isAllowed && (AVAudioApplication.shared.recordPermission == .denied
            || [.denied, .restricted].contains(AVCaptureDevice.authorizationStatus(for: .audio)))
    }

    /// Whether macOS will still show its prompt. After the first answer, only System Settings can change it.
    static var canPrompt: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined
    }
}
