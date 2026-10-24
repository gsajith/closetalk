import XCTest
@testable import ClosetalkCore

final class DictationKeyTests: XCTestCase {
    func testMissingOrUnknownStorageFallsBackToRightCommand() {
        XCTAssertEqual(DictationKey(storageValue: nil), .rightCommand)
        XCTAssertEqual(DictationKey(storageValue: "capsLock"), .rightCommand)
    }

    func testStorageRoundTrips() {
        for key in DictationKey.allCases {
            XCTAssertEqual(DictationKey(storageValue: key.rawValue), key)
        }
    }
}
