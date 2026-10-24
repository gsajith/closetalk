import Foundation

/// The recording island's bars: the microphone's recent loudness, oldest first, each 0...1.
///
/// Heights are relative to the loudest recent chunk, not a fixed scale: how loud speech arrives depends
/// on the mic and how close it is, and a fixed scale left most bars either full or flat.
public struct WaveformLevels: Equatable {
    /// A chunk this far below the peak shows as a flat bar. Speech moves within about this range.
    static let range = 30.0
    /// The peak never drops below this, so a quiet room stays flat instead of being scaled up.
    static let quietestPeak = -25.0
    /// How far the peak eases down per chunk of audio, so the scale follows a voice that gets quieter.
    static let peakDecay = 0.4

    public private(set) var values: [Double]
    private var peak = quietestPeak

    public init(count: Int = 12) {
        values = Array(repeating: 0, count: count)
    }

    /// Adds the loudness of the latest chunk of audio and drops the oldest bar.
    public mutating func append(rms: Float) {
        let level = Self.decibels(rms)
        peak = max(level, peak - Self.peakDecay, Self.quietestPeak)
        values.removeFirst()
        values.append(min(max((level - (peak - Self.range)) / Self.range, 0), 1))
    }

    static func decibels(_ rms: Float) -> Double {
        rms > 0 ? 20 * log10(Double(rms)) : -120
    }
}
