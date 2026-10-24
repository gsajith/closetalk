import XCTest
@testable import ClosetalkCore

final class SetupProgressTests: XCTestCase {
    private func progress(mic: Bool = false, ax: Bool = false, key: Bool = false,
                          model: ModelSetup = .downloading(fraction: 0), tried: Bool = false) -> SetupProgress {
        SetupProgress(microphoneAllowed: mic, accessibilityAllowed: ax, shortcutChosen: key, model: model, triedIt: tried)
    }

    func testStepsAreDoneWhenTheirConditionHolds() {
        let p = progress(mic: true, ax: false, model: .ready, tried: false)
        XCTAssertTrue(p.isDone(.microphone))
        XCTAssertFalse(p.isDone(.accessibility))
        XCTAssertTrue(p.isDone(.model))
        XCTAssertFalse(p.isDone(.tryIt))
    }

    func testTryItUnlocksOnlyWhenEverythingElseIsDone() {
        XCTAssertFalse(progress(mic: true, ax: true, model: .compiling(startedAt: .distantPast, firstTime: true)).isAvailable(.tryIt))
        XCTAssertFalse(progress(mic: false, ax: true, key: true, model: .ready).isAvailable(.tryIt))
        XCTAssertFalse(progress(mic: true, ax: true, key: false, model: .ready).isAvailable(.tryIt))
        XCTAssertTrue(progress(mic: true, ax: true, key: true, model: .ready).isAvailable(.tryIt))
        XCTAssertTrue(progress().isAvailable(.model))
    }

    func testShortcutWaitsForAccessibility() {
        XCTAssertFalse(progress(mic: true).isAvailable(.shortcut))
        XCTAssertTrue(progress(ax: true).isAvailable(.shortcut))
        // Without Accessibility, Continue skips the shortcut step rather than landing on a locked one.
        XCTAssertEqual(progress(mic: true).nextUnfinished(after: .microphone), .accessibility)
        XCTAssertEqual(progress(mic: true).nextUnfinished(after: .accessibility), .model)
    }

    func testFirstUnfinishedStartsAtTheFirstMissingStep() {
        XCTAssertEqual(progress().firstUnfinished, .microphone)
        XCTAssertEqual(progress(mic: true, ax: true).firstUnfinished, .shortcut)
        XCTAssertEqual(progress(mic: true, ax: true, key: true).firstUnfinished, .model)
        XCTAssertEqual(progress(mic: true, ax: true, key: true, model: .ready).firstUnfinished, .tryIt)
        XCTAssertNil(progress(mic: true, ax: true, key: true, model: .ready, tried: true).firstUnfinished)
    }

    func testContinueSkipsDoneStepsAndWrapsAround() {
        // Microphone and model done: from Microphone, Continue goes to Accessibility.
        XCTAssertEqual(progress(mic: true, model: .ready).nextUnfinished(after: .microphone), .accessibility)
        // On the model step with only Microphone missing, Continue wraps back to it.
        XCTAssertEqual(progress(ax: true).nextUnfinished(after: .model), .microphone)
    }

    func testContinueNeverLandsOnALockedTryIt() {
        // Permissions and shortcut done, model still compiling: nothing to continue to from the model step.
        let p = progress(mic: true, ax: true, key: true, model: .compiling(startedAt: .distantPast, firstTime: true))
        XCTAssertNil(p.nextUnfinished(after: .model))
        XCTAssertEqual(p.nextUnfinished(after: .accessibility), .model)
    }

    func testCompileFractionFillsOnElapsedTimeButNeverCompletes() {
        XCTAssertEqual(CompileEstimate.fraction(elapsed: 0), 0)
        XCTAssertEqual(CompileEstimate.fraction(elapsed: 300), 0.5, accuracy: 0.001)
        XCTAssertEqual(CompileEstimate.fraction(elapsed: 3000), 0.95, accuracy: 0.001)
    }

    func testCompileTextCountsDownThenAdmitsItsRunningLong() {
        XCTAssertEqual(CompileEstimate.remainingText(elapsed: 0), "about 10 minutes left")
        XCTAssertEqual(CompileEstimate.remainingText(elapsed: 252), "about 6 minutes left")
        XCTAssertEqual(CompileEstimate.remainingText(elapsed: 540), "about a minute left")
        XCTAssertEqual(CompileEstimate.remainingText(elapsed: 650), "Taking longer than usual, still working")
        XCTAssertEqual(CompileEstimate.elapsedText(252), "4:12 so far")
    }
}
