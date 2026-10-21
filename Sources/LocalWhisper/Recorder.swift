import AVFoundation

/// Captures the default microphone as 16 kHz mono Float samples, the format Whisper expects.
/// The mic is only open between start() and stop(), so the macOS mic indicator stays off when idle.
final class Recorder {
    private let engine = AVAudioEngine()
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
    private let lock = NSLock()
    private var samples: [Float] = []

    init() {
        // Touching inputNode and preparing up front makes start() fast.
        _ = engine.inputNode
        engine.prepare()
    }

    func start() throws {
        lock.withLock { samples.removeAll(keepingCapacity: true) }
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw NSError(domain: "Recorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "No microphone available"])
        }
        let ratio = targetFormat.sampleRate / inputFormat.sampleRate

        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
            guard let out = AVAudioPCMBuffer(pcmFormat: self.targetFormat, frameCapacity: capacity) else { return }
            var fed = false
            converter.convert(to: out, error: nil) { _, status in
                if fed {
                    status.pointee = .noDataNow
                    return nil
                }
                fed = true
                status.pointee = .haveData
                return buffer
            }
            guard let channel = out.floatChannelData?[0] else { return }
            let chunk = UnsafeBufferPointer(start: channel, count: Int(out.frameLength))
            self.lock.withLock { self.samples.append(contentsOf: chunk) }
        }
        try engine.start()
    }

    func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return lock.withLock { samples }
    }
}
