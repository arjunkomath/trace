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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupLauncherWindow()
        setupHotkey()
        requestAccessibilityPermissions()
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
    
    private func requestAccessibilityPermissions() {
        let accessEnabled = AXIsProcessTrusted()
        
        if !accessEnabled {
            do {
                let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                let hasPermissions = AXIsProcessTrustedWithOptions(options)
                
                if !hasPermissions {
                    logger.warning("Accessibility permissions needed for global hotkey - please check System Preferences > Security & Privacy > Accessibility")
                }
            } catch {
                logger.error("Failed to request accessibility permissions: \(error.localizedDescription)")
            }
        }
    }
    

    
    @objc private func showLauncher() {
        launcherWindow?.show()
        startGlobalEventMonitoring()
    }
    
    func showPreferences() {
        // First check if settings window is already open
        if let settingsWindow = NSApp.windows.first(where: { $0.title.contains("Settings") || $0.title.contains("Preferences") }) {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Use the main menu approach to open settings
        // This is the most reliable way for SwiftUI Settings scenes
        if let mainMenu = NSApp.mainMenu {
            for menuItem in mainMenu.items {
                if let submenu = menuItem.submenu {
                    for subMenuItem in submenu.items {
                        if subMenuItem.title.contains("Settings") || subMenuItem.title.contains("Preferences") {
                            NSApp.sendAction(subMenuItem.action!, to: subMenuItem.target, from: nil)
                            NSApp.activate(ignoringOtherApps: true)
                            return
                        }
                    }
                }
            }
        }
        
        // Fallback: try the standard preferences action
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
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
    
    // MARK: - Public API
    
    func updateHotkey(keyCode: UInt32, modifiers: UInt32) throws {
        try hotkeyManager?.registerHotkey(keyCode: keyCode, modifiers: modifiers)
    }
}