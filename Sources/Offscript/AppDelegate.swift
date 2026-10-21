import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController!
    private var dictation: DictationController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar = MenuBarController()
        requestPermissions()
        dictation = DictationController(menuBar: menuBar)
        dictation.start()
    }

    private func requestPermissions() {
        // Shows the system prompt pointing at System Settings if we're not trusted yet.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
