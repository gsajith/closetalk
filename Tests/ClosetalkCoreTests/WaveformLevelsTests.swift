import XCTest
@testable import ClosetalkCore

final class WaveformLevelsTests: XCTestCase {
    /// RMS for a loudness in decibels.
    private func rms(_ decibels: Double) -> Float { Float(pow(10, decibels / 20)) }

    func testSilenceStaysFlat() {
        var levels = WaveformLevels(count: 3)
        for _ in 0..<3 { levels.append(rms: rms(-60)) }
        XCTAssertEqual(levels.values, [0, 0, 0])
    }

    func testLoudSpeechSpreadsAcrossTheBarsInsteadOfFillingThem() {
        // Close to the mic, speech runs from about -20 dB to -5 dB. A fixed scale showed all of it full.
        var levels = WaveformLevels(count: 3)
        levels.append(rms: rms(-5))
        levels.append(rms: rms(-20))
        levels.append(rms: rms(-12.5))
        XCTAssertEqual(levels.values[0], 1, accuracy: 0.01)
        XCTAssertEqual(levels.values[1], 0.5, accuracy: 0.05)
        XCTAssertGreaterThan(levels.values[2], levels.values[1])
        XCTAssertLessThan(levels.values[2], levels.values[0])
    }

    func testTheScaleFollowsAVoiceThatGetsQuieter() {
        var levels = WaveformLevels(count: 1)
        levels.append(rms: rms(-5))
        for _ in 0..<60 { levels.append(rms: rms(-20)) } // a stretch of quieter speech
        XCTAssertEqual(levels.values[0], 1, accuracy: 0.01)
    }
}
