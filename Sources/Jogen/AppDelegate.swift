import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var accessibilityItem: NSMenuItem!
    private var monitor: AccessibilityTextMonitor!
    private var coordinator: ReviewCoordinator!
    private var settingsWindow: SettingsWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = AppSettings.shared
        let suggestionPanel = SuggestionPanel()
        let triggerPanel = SelectionTriggerPanel()
        coordinator = ReviewCoordinator(
            settings: settings,
            panel: suggestionPanel,
            triggerPanel: triggerPanel
        )

        monitor = AccessibilityTextMonitor()
        monitor.onCapture = { [weak self] capture in
            self?.coordinator.receive(capture)
        }
        monitor.onSelectionCleared = { [weak self] in
            self?.coordinator.selectionCleared()
        }
        monitor.onUnavailable = { [weak self] in
            self?.coordinator.temporarilyUnavailable()
        }
        monitor.start()

        settingsWindow = SettingsWindowController(settings: settings)
        settingsWindow.onSave = { [weak self] in
            self?.coordinator.reset()
            self?.monitor.refresh()
        }

        setupMainMenu()
        setupStatusItem()
        requestAccessibilityOnFirstLaunch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(
            NSMenuItem(
                title: "Paste",
                action: #selector(NSText.paste(_:)),
                keyEquivalent: "v"
            )
        )
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "Jogen")
            button.toolTip = "Jogen"
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(.separator())

        accessibilityItem = NSMenuItem(
            title: "Accessibility Access",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        menu.addItem(accessibilityItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Jogen", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        if AccessibilityTextMonitor.isTrusted {
            accessibilityItem.title = "Accessibility Access: Granted"
            accessibilityItem.state = .on
            monitor.refresh()
        } else {
            accessibilityItem.title = "Grant Accessibility Access…"
            accessibilityItem.state = .off
        }
    }

    private func requestAccessibilityOnFirstLaunch() {
        guard !AccessibilityTextMonitor.isTrusted else { return }
        let defaults = UserDefaults.standard
        let key = "didRequestAccessibility"
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        AccessibilityTextMonitor.requestAccess()
    }

    @objc private func showSettings() {
        coordinator.dismiss()
        settingsWindow.present()
    }

    @objc private func openAccessibilitySettings() {
        if !AccessibilityTextMonitor.isTrusted {
            AccessibilityTextMonitor.requestAccess()
        }
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
