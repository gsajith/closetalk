import AVFoundation

/// Captures a microphone as 16 kHz mono Float samples, the format Whisper expects.
/// Uses AVCaptureSession rather than AVAudioEngine: the engine caches the input format, and Bluetooth
/// headsets change sample rate while switching into two-way mode, which made the engine throw and crash.
/// The capture session converts to 16 kHz itself, whatever the device does.
/// The mic is only open between start() and stop(), so the macOS mic indicator stays off when idle.
final class Recorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    /// Starting and stopping block for tens of milliseconds, so they run here instead of the main thread.
    private let sessionQueue = DispatchQueue(label: "Closetalk.Recorder.session")
    private let bufferQueue = DispatchQueue(label: "Closetalk.Recorder.buffers")
    private var session: AVCaptureSession?  // sessionQueue only

    private let lock = NSLock()
    private var samples: [Float] = []
    private var onFirstAudio: (() -> Void)?

    /// `device` nil means the system default input. `onFirstAudio` runs on the main thread once
    /// real audio arrives, which for Bluetooth headsets can be most of a second after start().
    func start(device: AVCaptureDevice?, onFirstAudio: @escaping () -> Void) throws {
        guard let device = device ?? AVCaptureDevice.default(for: .audio) else {
            throw NSError(domain: "Recorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "No microphone available"])
        }
        let session = AVCaptureSession()
        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureAudioDataOutput()
        output.audioSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
        ]
        output.setSampleBufferDelegate(self, queue: bufferQueue)
        guard session.canAddInput(input), session.canAddOutput(output) else {
            throw NSError(domain: "Recorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Can't record from \(device.localizedName)"])
        }
        session.addInput(input)
        session.addOutput(output)

        lock.withLock {
            samples.removeAll(keepingCapacity: true)
            self.onFirstAudio = onFirstAudio
        }
        sessionQueue.async {
            self.session = session
            session.startRunning()
        }
    }

    func stop() -> [Float] {
        sessionQueue.sync {
            session?.stopRunning()
            session = nil
        }
        bufferQueue.sync {}  // Let any buffer already in flight land.
        return lock.withLock {
            onFirstAudio = nil
            // Hand the audio over and drop our copy, so it isn't kept in memory between dictations.
            defer { samples = [] }
            return samples
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        let length = CMBlockBufferGetDataLength(block)
        guard length > 0 else { return }
        var chunk = [Float](repeating: 0, count: length / MemoryLayout<Float>.size)
        guard chunk.withUnsafeMutableBytes({ CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: $0.baseAddress!) }) == noErr
        else { return }

        // Some devices deliver pure zeros while they spin up; wait for a non-zero sample.
        let callback: (() -> Void)? = lock.withLock {
            samples.append(contentsOf: chunk)
            guard let pending = onFirstAudio, chunk.contains(where: { $0 != 0 }) else { return nil }
            onFirstAudio = nil
            return pending
        }
        if let callback { DispatchQueue.main.async(execute: callback) }
    }
}
