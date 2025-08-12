//
//  AppDelegate.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import Cocoa
import SwiftUI
import Carbon
import Sparkle

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
    private let settingsManager = SettingsManager.shared
    
    private var launcherWindow: LauncherWindow?
    private var hotkeyManager: HotkeyManager?
    private var globalEventMonitor: Any?
    private var skipQuitConfirmation = false
    private var statusItem: NSStatusItem?
    private var onboardingWindow: OnboardingWindow?
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    
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
        
        // Request notification permissions on app launch
        PermissionManager.shared.requestNotificationPermissions()
        
        // Initialize window hotkey manager to register saved hotkeys
        _ = WindowHotkeyManager.shared
        
        // Initialize app hotkey manager to register saved app hotkeys
        _ = AppHotkeyManager.shared
        
        // Show onboarding if first time user
        if !settingsManager.settings.hasCompletedOnboarding {
            showOnboarding()
        }
        
        // Observe changes to settings file
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsChanged),
            name: .NSManagedObjectContextDidSave,
            object: nil
        )
    }
    
    deinit {
        hotkeyManager?.unregisterHotkey()
        stopGlobalEventMonitoring()
        onboardingWindow?.hide()
        onboardingWindow = nil
        NotificationCenter.default.removeObserver(self)
        logger.debug("AppDelegate deinitialized")
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupMenuBar() {
        guard settingsManager.settings.showMenuBarIcon else { return }
        
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
        menu.addItem(openItem)
        
        // Check for Updates - Connect directly to Sparkle as per documentation
        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = updaterController
        menu.addItem(updateItem)
        
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
    
    @objc private func settingsChanged() {
        // Check if menu bar preference changed
        if settingsManager.settings.showMenuBarIcon {
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
    
    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }
    
    // MARK: - Helper Functions
    
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
        
        let keyCode = UInt32(settingsManager.settings.mainHotkeyKeyCode)
        let modifiers = UInt32(settingsManager.settings.mainHotkeyModifiers)
        
        logger.info("🚀 Setting up main hotkey from settings: keyCode=\(keyCode), modifiers=\(modifiers)")
        
        do {
            try hotkeyManager?.registerHotkey(keyCode: keyCode, modifiers: modifiers)
            logger.info("✅ Main hotkey registered successfully")
        } catch {
            logger.error("❌ Failed to register hotkey: \(error.localizedDescription)")
        }
    }
    
    // Removed requestAccessibilityPermissions - now handled on-demand by WindowManager
    

    
    @objc private func showLauncher() {
        launcherWindow?.show()
        startGlobalEventMonitoring()
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
    
    // MARK: - Onboarding
    
    private func showOnboarding() {
        onboardingWindow = OnboardingWindow { [weak self] in
            self?.completeOnboarding()
        }
        onboardingWindow?.show()
        logger.info("✅ Onboarding window shown for first-time user")
    }
    
    private func completeOnboarding() {
        settingsManager.updateOnboardingCompleted(true)
        onboardingWindow?.hide()
        onboardingWindow = nil
        logger.info("✅ Onboarding completed")
        
        // Optionally show the launcher after onboarding
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showLauncher()
        }
    }
    
    
    // MARK: - Public API
    
    func updateHotkey(keyCode: UInt32, modifiers: UInt32) throws {
        try hotkeyManager?.registerHotkey(keyCode: keyCode, modifiers: modifiers)
        
        // Save to SettingsManager for persistence
        settingsManager.updateMainHotkey(keyCode: Int(keyCode), modifiers: Int(modifiers))
        
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
