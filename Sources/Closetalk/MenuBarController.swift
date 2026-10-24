import AppKit
import ClosetalkCore
import ServiceManagement

enum AppState {
    case loadingModel(progress: Double?)
    case idle
    case recording
    case transcribing
    case error(String)
}

/// Owns the status item: its icon reflects AppState, its menu holds status, permissions, settings,
/// updates and quit.
final class MenuBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(
        title: "Grant Accessibility permission…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
    private let microphoneItem = NSMenuItem(title: "Microphone", action: nil, keyEquivalent: "")
    private let dictationKeyItem = NSMenuItem(title: "Dictation key", action: nil, keyEquivalent: "")
    /// Kept so the status line can be redrawn when the dictation key changes.
    private var state = AppState.loadingModel(progress: nil)
    private let loginItem = NSMenuItem(title: "Launch at login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

    /// `updatesItem` is the updater's "Check for Updates…" item, placed above Quit.
    init(updatesItem: NSMenuItem) {
        super.init()
        let menu = NSMenu()
        menu.autoenablesItems = false
        statusLine.isEnabled = false
        accessibilityItem.target = self
        loginItem.target = self
        menu.addItem(statusLine)
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())
        microphoneItem.submenu = NSMenu()
        menu.addItem(microphoneItem)
        dictationKeyItem.submenu = NSMenu()
        for key in DictationKey.allCases {
            let item = NSMenuItem(title: key.name.capitalizedFirst, action: #selector(selectDictationKey(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = key.rawValue
            dictationKeyItem.submenu?.addItem(item)
        }
        menu.addItem(dictationKeyItem)
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(updatesItem)
        menu.addItem(NSMenuItem(title: "Quit Closetalk", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.delegate = self
        item.menu = menu
        update(.loadingModel(progress: nil))
    }

    func update(_ state: AppState) {
        self.state = state
        let (symbol, text, tint): (String, String, NSColor?) = switch state {
        case .loadingModel(let p?): ("arrow.down.circle", "Downloading model… \(Int(p * 100))%", nil)
        // The first load compiles the model for the Neural Engine, which can take minutes.
        case .loadingModel(nil): ("arrow.down.circle", "Loading model… (first launch can take several minutes)", nil)
        case .idle: ("mic", "Ready. Hold \(DictationKeySettings.key.name) to dictate.", nil)
        case .recording: ("mic.fill", "Recording…", .systemRed)
        case .transcribing: ("waveform", "Transcribing…", nil)
        case .error(let message): ("exclamationmark.triangle", message, nil)
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: text)
        if let tint {
            item.button?.image = image?.withSymbolConfiguration(.init(paletteColors: [tint]))
        } else {
            image?.isTemplate = true
            item.button?.image = image
        }
        statusLine.title = text
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    /// Rebuilt each time the menu opens so plugged-in or removed mics show up.
    private func rebuildMicrophoneMenu() {
        guard let submenu = microphoneItem.submenu else { return }
        submenu.removeAllItems()
        let mics = MicrophoneSettings.available().map(\.mic)
        let selected = MicrophoneSettings.preference.resolve(among: mics)

        func add(_ title: String, _ choice: MicrophonePreference, isOn: Bool) {
            let item = NSMenuItem(title: title, action: #selector(selectMicrophone(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = choice
            item.state = isOn ? .on : .off
            submenu.addItem(item)
        }
        add("System default", .systemDefault, isOn: selected == nil)
        submenu.addItem(.separator())
        for mic in mics {
            // The built-in mic is stored as .builtIn rather than by UID, so the choice survives UID changes.
            add(mic.name, mic.isBuiltIn ? .builtIn : .device(uid: mic.uid), isOn: mic == selected)
        }
    }

    @objc private func selectMicrophone(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? MicrophonePreference else { return }
        MicrophoneSettings.preference = choice
    }

    @objc private func selectDictationKey(_ sender: NSMenuItem) {
        DictationKeySettings.key = DictationKey(storageValue: sender.representedObject as? String)
        update(state)
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            update(.error("Launch at login failed: \(error.localizedDescription)"))
        }
    }
}

extension MenuBarController: NSMenuDelegate {
    // Refresh items that depend on system state each time the menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        accessibilityItem.isHidden = AXIsProcessTrusted()
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        rebuildMicrophoneMenu()
        let key = DictationKeySettings.key
        for item in dictationKeyItem.submenu?.items ?? [] {
            item.state = item.representedObject as? String == key.rawValue ? .on : .off
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
