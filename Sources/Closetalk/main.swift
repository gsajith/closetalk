import AppKit

// Debug path: `Closetalk --transcribe <file>` prints the transcript and timing from the full model, then
// from the small model the live preview uses, then exits.
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--transcribe" {
    let path = CommandLine.arguments[2]
    let done = DispatchSemaphore(value: 0)
    Task {
        do {
            let transcriber = Transcriber()
            let loadStart = Date()
            try await transcriber.load(sampleFirst: false) { event in
                if case .downloading(let p) = event { print(String(format: "download %.0f%%", p * 100)) }
            }
            print("model ready in \(Int(Date().timeIntervalSince(loadStart) * 1000)) ms")
            let samples = try Transcriber.samples(fromFile: path)
            for run in 1...2 {
                let start = Date()
                let text = try await transcriber.transcribe(samples)
                print("run \(run): \(Int(Date().timeIntervalSince(start) * 1000)) ms: \(text)")
            }
            await transcriber.loadPreviewModel()
            for run in 1...2 {
                let start = Date()
                let text = try await transcriber.transcribePreview(samples)
                print("preview \(run): \(Int(Date().timeIntervalSince(start) * 1000)) ms: \(text)")
            }
        } catch {
            FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            exit(1)
        }
        done.signal()
    }
    done.wait()
    exit(0)
}

// Debug path: `Closetalk --island-preview` shows the recording island with made-up sound and words for
// 6 s, then transcribing for 2 s, then exits. For checking how it looks without dictating into another app.
if CommandLine.arguments.count == 2, CommandLine.arguments[1] == "--island-preview" {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let island = RecordingIsland()
        island.showRecording()
        var tick = 0.0
        Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { _ in
            tick += 0.35
            let rms = Float(0.05 + 0.05 * sin(tick) + Double.random(in: 0...0.05))
            MainActor.assumeIsolated { island.model.levels.append(rms: rms) }
        }
        // The preview's first words come in after a second, a few more each second after that.
        let words = "So I was thinking we should move the standup to Thursday, because half the team is out on Monday and the design review keeps slipping.".split(separator: " ")
        for second in 1...5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(second)) {
                island.model.transcript = words.prefix(second * 5).joined(separator: " ")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { island.showTranscribing() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { island.hide() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.5) { exit(0) }
        app.run()
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
