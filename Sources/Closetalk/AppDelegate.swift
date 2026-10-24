import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController!
    private var dictation: DictationController!
    private var updater: Updater!

    func applicationDidFinishLaunching(_ notification: Notification) {
        updater = Updater()
        menuBar = MenuBarController(updatesItem: updater.menuItem)
        promptForAccessibility()
        dictation = DictationController(menuBar: menuBar)
        dictation.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Inserter.flushPendingRestore()
    }

    private func promptForAccessibility() {
        // Shows the system prompt pointing at System Settings if Accessibility isn't granted yet.
        // The microphone prompt comes from DictationController.start().
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
