import AppKit
import ServiceManagement

enum AppState {
    case loadingModel(progress: Double?)
    case idle
    case recording
    case transcribing
    case error(String)
}

/// Owns the status item: its icon reflects AppState, its menu holds status, permissions, and quit.
final class MenuBarController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let accessibilityItem = NSMenuItem(
        title: "Grant Accessibility permission…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

    override init() {
        super.init()
        let menu = NSMenu()
        menu.autoenablesItems = false
        statusLine.isEnabled = false
        accessibilityItem.target = self
        loginItem.target = self
        menu.addItem(statusLine)
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(NSMenuItem(title: "Quit LocalWhisper", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        menu.delegate = self
        item.menu = menu
        update(.loadingModel(progress: nil))
    }

    func update(_ state: AppState) {
        let (symbol, text, tint): (String, String, NSColor?) = switch state {
        case .loadingModel(let p?): ("arrow.down.circle", "Downloading model… \(Int(p * 100))%", nil)
        // The first load compiles the model for the Neural Engine, which can take minutes.
        case .loadingModel(nil): ("arrow.down.circle", "Loading model… (first launch can take several minutes)", nil)
        case .idle: ("mic", "Ready. Hold right ⌘ to dictate.", nil)
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
    }
}
