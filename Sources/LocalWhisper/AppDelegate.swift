import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController()
        requestPermissions()
    }

    private func requestPermissions() {
        // Shows the system prompt pointing at System Settings if we're not trusted yet.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
    }
}
