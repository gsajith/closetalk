import XCTest
@testable import OffscriptCore

final class HotkeyStateMachineTests: XCTestCase {
    func testHoldThenReleaseFinishes() {
        var m = HotkeyStateMachine()
        XCTAssertEqual(m.handle(.rightCommandDown(0)), .startRecording)
        XCTAssertEqual(m.handle(.rightCommandUp(1.0)), .finishRecording)
    }

    func testQuickTapCancels() {
        var m = HotkeyStateMachine()
        XCTAssertEqual(m.handle(.rightCommandDown(2)), .startRecording)
        XCTAssertEqual(m.handle(.rightCommandUp(2.1)), .cancelRecording)
    }

    func testOtherInputWhileHeldCancelsAndReleaseIsIgnored() {
        var m = HotkeyStateMachine()
        XCTAssertEqual(m.handle(.rightCommandDown(3)), .startRecording)
        XCTAssertEqual(m.handle(.otherInput), .cancelRecording)
        XCTAssertNil(m.handle(.rightCommandUp(4)))
    }

    func testIdleIgnoresOtherInputAndRelease() {
        var m = HotkeyStateMachine()
        XCTAssertNil(m.handle(.otherInput))
        XCTAssertNil(m.handle(.rightCommandUp(7)))
    }

    func testRepeatedDownWhileHeldDoesNotRestart() {
        var m = HotkeyStateMachine()
        XCTAssertEqual(m.handle(.rightCommandDown(5)), .startRecording)
        XCTAssertNil(m.handle(.rightCommandDown(5.5)))
        XCTAssertEqual(m.handle(.rightCommandUp(6)), .finishRecording)
    }

    func testNewPressAfterFinishStartsAgain() {
        var m = HotkeyStateMachine()
        _ = m.handle(.rightCommandDown(0))
        _ = m.handle(.rightCommandUp(1))
        XCTAssertEqual(m.handle(.rightCommandDown(1.1)), .startRecording)
    }
}
