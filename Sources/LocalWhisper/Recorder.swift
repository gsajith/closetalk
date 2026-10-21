import AVFoundation
import CoreAudio

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

    /// `onFirstAudio` runs on the main thread once real audio arrives. With Bluetooth mics like AirPods
    /// that can be most of a second after start(), while the headset switches into two-way mode.
    /// `device` nil means the system default input.
    func start(device: AudioDeviceID?, onFirstAudio: @escaping () -> Void) throws {
        lock.withLock { samples.removeAll(keepingCapacity: true) }
        var heardAudio = false
        let input = engine.inputNode
        try use(device: device ?? MicrophoneSettings.systemDefaultInputID(), on: input)
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
            // Some devices deliver pure zeros while they spin up; wait for a non-zero sample.
            if !heardAudio, chunk.contains(where: { $0 != 0 }) {
                heardAudio = true
                DispatchQueue.main.async(execute: onFirstAudio)
            }
        }
        do {
            try engine.start()
        } catch {
            // Leaving the tap installed would make the next installTap crash.
            input.removeTap(onBus: 0)
            throw error
        }
    }

    /// Points the engine's input unit at a specific device. Only valid while the engine is stopped.
    private func use(device: AudioDeviceID?, on input: AVAudioInputNode) throws {
        guard var device, let unit = input.audioUnit else { return }
        let status = AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
            &device, UInt32(MemoryLayout<AudioDeviceID>.size))
        if status != noErr {
            throw NSError(domain: "Recorder", code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: "Couldn't switch microphone (\(status))"])
        }
    }

    func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return lock.withLock { samples }
    }
}
