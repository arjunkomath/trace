//
//  AppDelegate.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import Cocoa
import SwiftUI
import Carbon

extension NSEvent.ModifierFlags {
    init(carbonModifiers: UInt32) {
        var flags: NSEvent.ModifierFlags = []
        if carbonModifiers & UInt32(cmdKey) != 0 {
            flags.insert(.command)
        }
        if carbonModifiers & UInt32(optionKey) != 0 {
            flags.insert(.option)
        }
        if carbonModifiers & UInt32(controlKey) != 0 {
            flags.insert(.control)
        }
        if carbonModifiers & UInt32(shiftKey) != 0 {
            flags.insert(.shift)
        }
        self = flags
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = AppLogger.appDelegate
    private let settingsService = SettingsService()
    
    private var launcherWindow: LauncherWindow?
    private var hotkeyManager: HotkeyManager?
    private var globalEventMonitor: Any?
    private var skipQuitConfirmation = false
    private var statusItem: NSStatusItem?
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon: Bool = true
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app is truly a background app without dock icon
        NSApp.setActivationPolicy(.accessory)
        logger.info("✅ Set app activation policy to .accessory (background app)")
        
        // Initialize unified hotkey registry first
        _ = HotkeyRegistry.shared
        logger.info("✅ HotkeyRegistry initialized")
        
        setupLauncherWindow()
        setupHotkey()
        setupMenuBar()
        // REMOVED: requestAccessibilityPermissions() - now only requested when needed
        
        // Initialize window hotkey manager to register saved hotkeys
        _ = WindowHotkeyManager.shared
        
        // Initialize app hotkey manager to register saved app hotkeys
        _ = AppHotkeyManager.shared
        
        // Observe changes to menu bar preference
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuBarPreferenceChanged),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }
    
    deinit {
        hotkeyManager?.unregisterHotkey()
        stopGlobalEventMonitoring()
        NotificationCenter.default.removeObserver(self)
        logger.debug("AppDelegate deinitialized")
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupMenuBar() {
        guard showMenuBarIcon else { return }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "filemenu.and.selection", accessibilityDescription: "Trace")
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
            button.toolTip = "Trace - Click to open launcher"
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        setupMenuBarMenu()
    }
    
    private func setupMenuBarMenu() {
        let menu = NSMenu()
        
        // Set minimum width for the menu
        menu.minimumWidth = 200
        
        // Open Launcher with hotkey display
        let openItem = NSMenuItem(title: "Open Trace", action: #selector(showLauncher), keyEquivalent: "")
        openItem.target = self
        
        // Get the current hotkey and convert to key equivalent
        let keyCode = settingsService.hotkeyKeyCode
        let modifiers = settingsService.hotkeyModifiers
        
        // Convert to NSMenuItem key equivalent and modifier mask
        if let keyChar = keyCodeToString(keyCode) {
            openItem.keyEquivalent = keyChar
            openItem.keyEquivalentModifierMask = NSEvent.ModifierFlags(carbonModifiers: modifiers)
            // Disable the actual key equivalent functionality since we handle it globally
            openItem.isEnabled = true
        }
        
        menu.addItem(openItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(showPreferencesFromMenu), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit Trace", action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func statusItemClicked() {
        if let event = NSApp.currentEvent {
            if event.type == .rightMouseUp {
                // Right click shows menu - handled automatically by NSStatusItem
            } else {
                // Left click opens launcher
                showLauncher()
            }
        }
    }
    
    @objc private func menuBarPreferenceChanged() {
        if showMenuBarIcon {
            if statusItem == nil {
                setupMenuBar()
            } else {
                // Refresh the menu to update hotkey display
                setupMenuBarMenu()
            }
        } else {
            if let statusItem = statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
        }
    }
    
    @objc private func showPreferencesFromMenu() {
        showPreferences()
    }
    
    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }
    
    // MARK: - Helper Functions
    
    private func keyCodeToString(_ keyCode: UInt32) -> String? {
        // Convert common key codes to their string representations
        switch Int(keyCode) {
        case 49: return " "  // Space
        case 36: return "\r" // Return
        case 48: return "\t" // Tab
        case 51: return "\u{08}" // Delete
        case 53: return "\u{1B}" // Escape
        case 123: return "\u{F702}" // Left arrow
        case 124: return "\u{F703}" // Right arrow
        case 125: return "\u{F701}" // Down arrow
        case 126: return "\u{F700}" // Up arrow
        default:
            // For letter and number keys, use the KeyBindingView approach
            let keyBinding = KeyBindingView(keyCode: keyCode, modifiers: 0)
            if let lastKey = keyBinding.keys.last {
                // Remove modifier symbols and return just the key
                let key = lastKey.replacingOccurrences(of: "⌘", with: "")
                    .replacingOccurrences(of: "⌥", with: "")
                    .replacingOccurrences(of: "⌃", with: "")
                    .replacingOccurrences(of: "⇧", with: "")
                return key.lowercased()
            }
            return nil
        }
    }

    
    private func setupLauncherWindow() {
        launcherWindow = LauncherWindow()
    }
    
    private func setupHotkey() {
        hotkeyManager = HotkeyManager()
        hotkeyManager?.onHotkeyPressed = { [weak self] in
            // Track the current active window (for window management features)
            // The new permission system handles permissions on-demand
            WindowManager.shared.trackCurrentActiveWindow()
            
            // Show launcher immediately
            self?.toggleLauncher()
        }
        
        let keyCode = settingsService.hotkeyKeyCode
        let modifiers = settingsService.hotkeyModifiers
        
        do {
            try hotkeyManager?.registerHotkey(keyCode: keyCode, modifiers: modifiers)
        } catch {
            logger.error("Failed to register hotkey: \(error.localizedDescription)")
        }
    }
    
    // Removed requestAccessibilityPermissions - now handled on-demand by WindowManager
    

    
    @objc private func showLauncher() {
        launcherWindow?.show()
        startGlobalEventMonitoring()
    }
    
    func showPreferences() {
        // First check if settings window is already open
        if let settingsWindow = NSApp.windows.first(where: { $0.title.contains("Settings") || $0.title.contains("Preferences") }) {
            // Force the app to activate and bring the window to front
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)
            settingsWindow.orderFrontRegardless()
            return
        }
        
        // Use the main menu approach to open settings
        // This is the most reliable way for SwiftUI Settings scenes
        if let mainMenu = NSApp.mainMenu {
            for menuItem in mainMenu.items {
                if let submenu = menuItem.submenu {
                    for subMenuItem in submenu.items {
                        if subMenuItem.title.contains("Settings") || subMenuItem.title.contains("Preferences") {
                            // Activate the app first
                            NSApp.activate(ignoringOtherApps: true)
                            NSApp.sendAction(subMenuItem.action!, to: subMenuItem.target, from: nil)
                            
                            // After a brief delay, ensure the window is at front
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                if let settingsWindow = NSApp.windows.first(where: { $0.title.contains("Settings") || $0.title.contains("Preferences") }) {
                                    settingsWindow.orderFrontRegardless()
                                }
                            }
                            return
                        }
                    }
                }
            }
        }
        
        // Fallback: try the standard preferences action
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    private func toggleLauncher() {
        guard let launcherWindow = launcherWindow else { return }
        
        if launcherWindow.isVisible {
            launcherWindow.hide()
            stopGlobalEventMonitoring()
        } else {
            launcherWindow.show()
            startGlobalEventMonitoring()
        }
    }
    
    private func startGlobalEventMonitoring() {
        guard globalEventMonitor == nil else { return }
        
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.launcherWindow?.hide()
            self?.stopGlobalEventMonitoring()
        }
    }
    
    private func stopGlobalEventMonitoring() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager?.unregisterHotkey()
        stopGlobalEventMonitoring()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showLauncher()
        return true
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Allow bypass for app restart
        if skipQuitConfirmation {
            skipQuitConfirmation = false // Reset flag
            return .terminateNow
        }
        
        // Show confirmation dialog for quit attempts (like ⌘Q)
        let alert = NSAlert()
        alert.messageText = "Quit Trace?"
        alert.informativeText = "Are you sure you want to quit Trace? This will close the application."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        // Get the first button (Quit) and make it destructive
        if let quitButton = alert.buttons.first {
            quitButton.hasDestructiveAction = true
        }
        
        let response = alert.runModal()
        return response == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
    
    // MARK: - Public API
    
    func updateHotkey(keyCode: UInt32, modifiers: UInt32) throws {
        try hotkeyManager?.registerHotkey(keyCode: keyCode, modifiers: modifiers)
        // Update menu bar to show new hotkey
        if statusItem != nil {
            setupMenuBarMenu()
        }
    }
    
    func terminateWithoutConfirmation() {
        skipQuitConfirmation = true
        NSApp.terminate(nil)
    }
}
