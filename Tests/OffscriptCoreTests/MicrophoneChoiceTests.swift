import XCTest
@testable import OffscriptCore

final class MicrophoneChoiceTests: XCTestCase {
    let builtIn = Microphone(uid: "BuiltInMic", name: "MacBook Pro Microphone", isBuiltIn: true)
    let airPods = Microphone(uid: "AirPods", name: "AirPods", isBuiltIn: false)

    func testDefaultsToBuiltIn() {
        XCTAssertEqual(MicrophonePreference.builtIn.resolve(among: [airPods, builtIn]), builtIn)
    }

    func testSystemDefaultResolvesToNil() {
        XCTAssertNil(MicrophonePreference.systemDefault.resolve(among: [airPods, builtIn]))
    }

    func testChosenDeviceWhenPresent() {
        XCTAssertEqual(MicrophonePreference.device(uid: "AirPods").resolve(among: [airPods, builtIn]), airPods)
    }

    func testMissingDeviceFallsBackToBuiltIn() {
        XCTAssertEqual(MicrophonePreference.device(uid: "Gone").resolve(among: [airPods, builtIn]), builtIn)
    }

    func testNoBuiltInFallsBackToSystemDefault() {
        XCTAssertNil(MicrophonePreference.builtIn.resolve(among: [airPods]))
    }

    func testStorageRoundTrip() {
        for pref in [MicrophonePreference.builtIn, .systemDefault, .device(uid: "AirPods")] {
            XCTAssertEqual(MicrophonePreference(storageValue: pref.storageValue), pref)
        }
        XCTAssertEqual(MicrophonePreference(storageValue: nil), .builtIn)
    }
}
