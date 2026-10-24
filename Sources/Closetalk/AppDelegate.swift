import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController!
    private var dictation: DictationController!
    private var updater: Updater!
    private var setup: SetupWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        DictationShortcutSettings.keepRightCommandForUpgrades()
        updater = Updater()
        setup = SetupWindowController()
        menuBar = MenuBarController(updatesItem: updater.menuItem, openSetup: { [weak self] in self?.setup.show() })
        dictation = DictationController(menuBar: menuBar, setup: setup.model)
        dictation.start()
        // The window asks for both permissions and explains the one-time model compile, so it opens
        // on a first launch and whenever a permission has gone missing.
        setup.model.refreshStatus()
        if setup.model.needsSetup { setup.show() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Inserter.flushPendingRestore()
    }
}
