import Foundation
import ClosetalkCore

/// Stores the dictation shortcut in UserDefaults.
enum DictationShortcutSettings {
    private static let defaultsKey = "dictationShortcut"

    static var shortcut: DictationShortcut {
        get { DictationShortcut(storageData: UserDefaults.standard.data(forKey: defaultsKey)) }
        set { UserDefaults.standard.set(newValue.storageData, forKey: defaultsKey) }
    }
}
