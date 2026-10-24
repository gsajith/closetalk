import Foundation
import ClosetalkCore

/// Stores the dictation key in UserDefaults. The event tap reads it on its own thread for each
/// modifier change, which UserDefaults allows, so a new choice applies on the next press.
enum DictationKeySettings {
    private static let defaultsKey = "dictationKey"

    static var key: DictationKey {
        get { DictationKey(storageValue: UserDefaults.standard.string(forKey: defaultsKey)) }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey) }
    }
}
