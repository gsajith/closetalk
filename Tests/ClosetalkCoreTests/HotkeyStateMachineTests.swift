import XCTest
@testable import ClosetalkCore

final class HotkeyStateMachineTests: XCTestCase {
    func testHoldThenReleaseFinishes() {
        var m = HotkeyStateMachine()
        XCTAssertEqual(m.handle(.keyDown(0)), .startRecording)
        XCTAssertEqual(m.handle(.keyUp(1.0)), .finishRecording)
    }

    func testQuickTapCancels() {
        var m = HotkeyStateMachine()
        XCTAssertEqual(m.handle(.keyDown(2)), .startRecording)
        XCTAssertEqual(m.handle(.keyUp(2.1)), .cancelRecording)
    }

    func testOtherInputWhileHeldCancelsAndReleaseIsIgnored() {
        var m = HotkeyStateMachine()
        XCTAssertEqual(m.handle(.keyDown(3)), .startRecording)
        XCTAssertEqual(m.handle(.otherInput), .cancelRecording)
        XCTAssertNil(m.handle(.keyUp(4)))
    }

    func testIdleIgnoresOtherInputAndRelease() {
        var m = HotkeyStateMachine()
        XCTAssertNil(m.handle(.otherInput))
        XCTAssertNil(m.handle(.keyUp(7)))
    }

    func testRepeatedDownWhileHeldDoesNotRestart() {
        var m = HotkeyStateMachine()
        XCTAssertEqual(m.handle(.keyDown(5)), .startRecording)
        XCTAssertNil(m.handle(.keyDown(5.5)))
        XCTAssertEqual(m.handle(.keyUp(6)), .finishRecording)
    }

    func testNewPressAfterFinishStartsAgain() {
        var m = HotkeyStateMachine()
        _ = m.handle(.keyDown(0))
        _ = m.handle(.keyUp(1))
        XCTAssertEqual(m.handle(.keyDown(1.1)), .startRecording)
    }
}
