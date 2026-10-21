import AppKit

// Debug path: `LocalWhisper --transcribe <file>` prints the transcript and timing, then exits.
if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--transcribe" {
    let path = CommandLine.arguments[2]
    let done = DispatchSemaphore(value: 0)
    Task {
        do {
            let transcriber = Transcriber()
            let loadStart = Date()
            try await transcriber.load { p in print(String(format: "download %.0f%%", p * 100)) }
            print("model ready in \(Int(Date().timeIntervalSince(loadStart) * 1000)) ms")
            let samples = try Transcriber.samples(fromFile: path)
            for run in 1...2 {
                let start = Date()
                let text = try await transcriber.transcribe(samples)
                print("run \(run): \(Int(Date().timeIntervalSince(start) * 1000)) ms: \(text)")
            }
        } catch {
            print("error: \(error)")
        }
        done.signal()
    }
    done.wait()
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
