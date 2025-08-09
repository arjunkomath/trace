//
//  AppDelegate.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import Cocoa
import SwiftUI
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = AppLogger.appDelegate
    private let settingsService = SettingsService()
    
    private var launcherWindow: LauncherWindow?
    private var hotkeyManager: HotkeyManager?
    private var globalEventMonitor: Any?
    private var skipQuitConfirmation = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app is truly a background app without dock icon
        NSApp.setActivationPolicy(.accessory)
        logger.info("✅ Set app activation policy to .accessory (background app)")
        
        // Initialize unified hotkey registry first
        _ = HotkeyRegistry.shared
        logger.info("✅ HotkeyRegistry initialized")
        
        setupLauncherWindow()
        setupHotkey()
        // REMOVED: requestAccessibilityPermissions() - now only requested when needed
        
        // Initialize window hotkey manager to register saved hotkeys
        _ = WindowHotkeyManager.shared
        
        // Initialize app hotkey manager to register saved app hotkeys
        _ = AppHotkeyManager.shared
    }
    
    deinit {
        hotkeyManager?.unregisterHotkey()
        stopGlobalEventMonitoring()
        logger.debug("AppDelegate deinitialized")
    }
    

    
    private func setupLauncherWindow() {
        launcherWindow = LauncherWindow()
    }
    
    private func setupHotkey() {
        hotkeyManager = HotkeyManager()
        hotkeyManager?.onHotkeyPressed = { [weak self] in
            // Only track window if we have permissions (for window management features)
            // Don't request permissions here - just silently skip if not granted
            if WindowManager.shared.hasAccessibilityPermissions() {
                WindowManager.shared.trackCurrentActiveWindow()
            }
            
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
    }
    
    func terminateWithoutConfirmation() {
        skipQuitConfirmation = true
        NSApp.terminate(nil)
    }
}
