import XCTest
@testable import LocalWhisperCore

final class SpacingPolicyTests: XCTestCase {
    func testNoSpaceBeforeFirstInsert() {
        var s = SpacingPolicy()
        XCTAssertEqual(s.prefix(at: 0), "")
    }

    func testSpaceWithinWindowOnly() {
        var s = SpacingPolicy()
        s.recordInsert(at: 0)
        XCTAssertEqual(s.prefix(at: 30), " ")
        XCTAssertEqual(s.prefix(at: 61), "")
    }

    func testResetDropsSpace() {
        var s = SpacingPolicy()
        s.recordInsert(at: 100)
        s.reset()
        XCTAssertEqual(s.prefix(at: 101), "")
    }
}
