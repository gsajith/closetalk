import XCTest
@testable import OffscriptCore

final class TranscriptCleanerTests: XCTestCase {
    func testRemovesLeadingFillerAndCapitalizes() {
        XCTAssertEqual(TranscriptCleaner.clean("Um, so the build is failing."), "So the build is failing.")
    }

    func testRemovesMidSentenceFiller() {
        XCTAssertEqual(TranscriptCleaner.clean("Run the uh tests again"), "Run the tests again")
    }

    func testTrimsWhitespace() {
        XCTAssertEqual(TranscriptCleaner.clean("  hello world  "), "hello world")
    }

    func testKeepsWordsThatStartLikeFillers() {
        XCTAssertEqual(TranscriptCleaner.clean("Check the umbrella config"), "Check the umbrella config")
    }

    func testStripsBracketedAnnotations() {
        XCTAssertEqual(TranscriptCleaner.clean("[Music] fix the bug"), "fix the bug")
    }

    func testKeepsCodeLikeBracketsAndParens() {
        XCTAssertEqual(TranscriptCleaner.clean("Call foo() with args[0]"), "Call foo() with args[0]")
        XCTAssertEqual(TranscriptCleaner.clean("Use the (optional) flag"), "Use the (optional) flag")
    }

    func testStripsAsteriskAnnotations() {
        XCTAssertNil(TranscriptCleaner.clean("*sad music*"))
        XCTAssertEqual(TranscriptCleaner.clean("*laughs* okay let's go"), "okay let's go")
        XCTAssertEqual(TranscriptCleaner.clean("Compute 2 * 3 * 4"), "Compute 2 * 3 * 4")
    }

    func testReturnsNilForNothingToInsert() {
        for raw in ["", "Um.", "[BLANK_AUDIO]", " Thank you.", "Thanks for watching!", "(silence)", "(music)", "[ Silence ]"] {
            XCTAssertNil(TranscriptCleaner.clean(raw), "expected nil for \(raw)")
        }
    }
}
