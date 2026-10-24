import XCTest
@testable import ClosetalkCore

// Flag bits as macOS reports them: device-dependent side bits plus the side-agnostic masks.
private let rightCmd: UInt64 = 0x10 | 0x10_0000
private let leftCmd: UInt64 = 0x08 | 0x10_0000
private let rightOpt: UInt64 = 0x40 | 0x8_0000
private let leftCtrl: UInt64 = 0x01 | 0x4_0000
private let leftShift: UInt64 = 0x02 | 0x2_0000
private let fn: UInt64 = 0x80_0000
private let space: Int64 = 49
private let f5: Int64 = 96
private let keyD: Int64 = 2
private let rightCommandAlone = DictationShortcut.modifiers([.rightCommand])

final class ShortcutMatcherTests: XCTestCase {
    func testRightCommandAloneStartsAndStops() {
        var m = ShortcutMatcher(shortcut: rightCommandAlone)
        XCTAssertEqual(m.handle(.flagsChanged(flags: rightCmd), at: 1), .init(event: .keyDown(1)))
        XCTAssertEqual(m.handle(.flagsChanged(flags: 0), at: 2), .init(event: .keyUp(2)))
    }

    func testLeftCommandDoesNotTriggerRightCommand() {
        var m = ShortcutMatcher(shortcut: rightCommandAlone)
        XCTAssertEqual(m.handle(.flagsChanged(flags: leftCmd), at: 1), .init())
    }

    func testAddingAModifierWhileHeldCountsAsOtherInput() {
        var m = ShortcutMatcher(shortcut: rightCommandAlone)
        _ = m.handle(.flagsChanged(flags: rightCmd), at: 1)
        XCTAssertEqual(m.handle(.flagsChanged(flags: rightCmd | leftShift), at: 2), .init(event: .otherInput))
    }

    func testTwoModifierShortcutNeedsBoth() {
        var m = ShortcutMatcher(shortcut: .modifiers([.rightOption, .rightCommand]))
        XCTAssertEqual(m.handle(.flagsChanged(flags: rightOpt), at: 1), .init())
        XCTAssertEqual(m.handle(.flagsChanged(flags: rightOpt | rightCmd), at: 2), .init(event: .keyDown(2)))
        XCTAssertEqual(m.handle(.flagsChanged(flags: rightOpt), at: 3), .init(event: .keyUp(3)))
    }

    func testTypingIsOtherInputAndPassesThrough() {
        var m = ShortcutMatcher(shortcut: rightCommandAlone)
        XCTAssertEqual(m.handle(.keyDown(code: keyD, flags: 0, isRepeat: false), at: 1), .init(event: .otherInput))
    }

    func testKeyComboIsSwallowedWhileHeld() {
        var m = ShortcutMatcher(shortcut: .key(code: space, label: "Space", modifiers: [.leftControl, .rightOption]))
        let flags = leftCtrl | rightOpt
        XCTAssertEqual(m.handle(.keyDown(code: space, flags: flags, isRepeat: false), at: 1),
                       .init(event: .keyDown(1), swallow: true))
        XCTAssertEqual(m.handle(.keyDown(code: space, flags: flags, isRepeat: true), at: 1.5), .init(swallow: true))
        XCTAssertEqual(m.handle(.keyUp(code: space, flags: flags), at: 2), .init(event: .keyUp(2), swallow: true))
    }

    func testKeyComboMatchesEitherSideOfAModifier() {
        var m = ShortcutMatcher(shortcut: .key(code: space, label: "Space", modifiers: [.rightOption]))
        let leftOpt: UInt64 = 0x20 | 0x8_0000
        XCTAssertEqual(m.handle(.keyDown(code: space, flags: leftOpt, isRepeat: false), at: 1),
                       .init(event: .keyDown(1), swallow: true))
    }

    func testKeyWithoutItsModifiersTypesNormally() {
        var m = ShortcutMatcher(shortcut: .key(code: space, label: "Space", modifiers: [.rightOption]))
        XCTAssertEqual(m.handle(.keyDown(code: space, flags: 0, isRepeat: false), at: 1), .init(event: .otherInput))
        XCTAssertEqual(m.handle(.keyUp(code: space, flags: 0), at: 2), .init())
    }

    func testReleasingTheModifierFirstFinishesAndTheKeyUpIsStillSwallowed() {
        var m = ShortcutMatcher(shortcut: .key(code: space, label: "Space", modifiers: [.rightOption]))
        _ = m.handle(.keyDown(code: space, flags: rightOpt, isRepeat: false), at: 1)
        XCTAssertEqual(m.handle(.flagsChanged(flags: 0), at: 2), .init(event: .keyUp(2)))
        XCTAssertEqual(m.handle(.keyUp(code: space, flags: 0), at: 2.1), .init(swallow: true))
    }

    func testHeldKeyRepeatsStayHiddenAfterTheModifierIsReleased() {
        var m = ShortcutMatcher(shortcut: .key(code: space, label: "Space", modifiers: [.rightOption]))
        _ = m.handle(.keyDown(code: space, flags: rightOpt, isRepeat: false), at: 1)
        _ = m.handle(.flagsChanged(flags: 0), at: 2)
        XCTAssertEqual(m.handle(.keyDown(code: space, flags: 0, isRepeat: true), at: 2.1), .init(swallow: true))
    }

    func testFnFlagIsIgnoredUnlessTheShortcutUsesFn() {
        // macOS sets the fn flag on F-key and arrow presses by itself.
        var m = ShortcutMatcher(shortcut: .key(code: f5, label: "F5", modifiers: []))
        XCTAssertEqual(m.handle(.keyDown(code: f5, flags: fn, isRepeat: false), at: 1),
                       .init(event: .keyDown(1), swallow: true))
    }
}

final class ShortcutRecorderTests: XCTestCase {
    func testReleasingModifiersRecordsEveryModifierThatWasHeld() {
        var r = ShortcutRecorder()
        XCTAssertEqual(r.handle(.flagsChanged(flags: rightOpt)), .recording("right ⌥"))
        XCTAssertEqual(r.handle(.flagsChanged(flags: rightOpt | rightCmd)), .recording("right ⌥ + right ⌘"))
        XCTAssertEqual(r.handle(.flagsChanged(flags: rightCmd)), .recording("right ⌘"))
        XCTAssertEqual(r.handle(.flagsChanged(flags: 0)), .done(.modifiers([.rightOption, .rightCommand])))
    }

    func testKeyWithModifiersRecordsACombo() {
        var r = ShortcutRecorder()
        _ = r.handle(.flagsChanged(flags: leftCtrl | rightOpt))
        XCTAssertEqual(r.handle(.keyDown(code: space, flags: leftCtrl | rightOpt, isRepeat: false), characters: " "),
                       .done(.key(code: space, label: "Space", modifiers: [.leftControl, .rightOption])))
    }

    func testFKeyAloneIsAllowedAndDropsTheAutomaticFnFlag() {
        var r = ShortcutRecorder()
        XCTAssertEqual(r.handle(.keyDown(code: f5, flags: fn, isRepeat: false), characters: nil),
                       .done(.key(code: f5, label: "F5", modifiers: [])))
    }

    func testPlainOrShiftedLettersAreRefused() {
        var r = ShortcutRecorder()
        XCTAssertEqual(r.handle(.keyDown(code: keyD, flags: 0, isRepeat: false), characters: "d"), .refused)
        XCTAssertEqual(r.handle(.keyDown(code: keyD, flags: leftShift, isRepeat: false), characters: "D"), .refused)
    }

    func testReleasingModifiersAfterARefusedKeyDoesNotRecordThem() {
        var r = ShortcutRecorder()
        _ = r.handle(.flagsChanged(flags: leftShift))
        XCTAssertEqual(r.handle(.keyDown(code: keyD, flags: leftShift, isRepeat: false), characters: "D"), .refused)
        XCTAssertEqual(r.handle(.flagsChanged(flags: 0)), .recording(""))
    }

    func testEscapeCancels() {
        var r = ShortcutRecorder()
        XCTAssertEqual(r.handle(.keyDown(code: 53, flags: 0, isRepeat: false), characters: "\u{1b}"), .cancelled)
    }
}

final class DictationShortcutTests: XCTestCase {
    func testNames() {
        XCTAssertEqual(rightCommandAlone.name, "right ⌘")
        XCTAssertEqual(DictationShortcut.modifiers([.fn]).name, "fn")
        XCTAssertEqual(DictationShortcut.key(code: space, label: "Space", modifiers: [.rightCommand, .leftControl]).name,
                       "⌃⌘Space")
        XCTAssertEqual(DictationShortcut.key(code: f5, label: "F5", modifiers: []).name, "F5")
    }

    func testStorageRoundTripsAndHasNoDefault() {
        let combo = DictationShortcut.key(code: space, label: "Space", modifiers: [.leftControl])
        XCTAssertEqual(DictationShortcut(storageData: combo.storageData), combo)
        XCTAssertNil(DictationShortcut(storageData: nil))
        XCTAssertNil(DictationShortcut(storageData: Data("junk".utf8)))
    }
}
