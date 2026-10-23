import AppKit
import Sparkle

/// Owns Sparkle: checks the appcast in Info.plist (SUFeedURL) on a schedule and from the menu.
/// Closetalk has no Dock icon, so Sparkle's alert for a scheduled update can open behind other
/// windows. The menu item also says an update is waiting until the user deals with it.
@MainActor
final class Updater: NSObject, SPUStandardUserDriverDelegate {
    private static let defaultTitle = "Check for Updates…"

    let menuItem = NSMenuItem(title: Updater.defaultTitle, action: #selector(checkForUpdates), keyEquivalent: "")
    private var controller: SPUStandardUpdaterController?

    override init() {
        super.init()
        menuItem.target = self
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
    }

    @objc private func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    // Sparkle calls these on the main thread.

    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        guard !state.userInitiated else { return }
        let version = update.displayVersionString
        MainActor.assumeIsolated { menuItem.title = "Update available: \(version)…" }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        MainActor.assumeIsolated { menuItem.title = Updater.defaultTitle }
    }
}
