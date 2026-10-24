import Foundation
import ClosetalkCore

/// Stores the dictation shortcut in UserDefaults. There's no default: setup asks people to choose.
enum DictationShortcutSettings {
    private static let defaultsKey = "dictationShortcut"
    private static let upgradeCheckedKey = "dictationShortcutUpgradeChecked"

    static var shortcut: DictationShortcut? {
        get { DictationShortcut(storageData: UserDefaults.standard.data(forKey: defaultsKey)) }
        set { UserDefaults.standard.set(newValue?.storageData, forKey: defaultsKey) }
    }

    /// Closetalk 1.2 and earlier listened to right ⌘ without saving it. Someone upgrading from one of
    /// those keeps right ⌘, so dictation doesn't stop working. Runs once: a fresh install marks it done
    /// on its first launch, before any model exists, so it never picks up right ⌘ later.
    static func keepRightCommandForUpgrades() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: upgradeCheckedKey) else { return }
        defaults.set(true, forKey: upgradeCheckedKey)
        // A model that has been loaded before means an earlier version ran here.
        if shortcut == nil && Transcriber.hasCompiledBefore {
            shortcut = .modifiers([.rightCommand])
        }
    }
}
