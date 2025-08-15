//
//  ControlCenterManager.swift
//  trace
//
//  Created by Arjun on 9/8/2025.
//

import Foundation
import AppKit
import os.log

/// Manages system control center commands like appearance toggle
class ControlCenterManager {
    static let shared = ControlCenterManager()
    
    private let logger = AppLogger.controlCenterManager
    
    private init() {}
    
    // MARK: - Public Interface
    
    /// Toggles the system appearance between dark and light mode
    func toggleSystemAppearance() {
        logger.info("🌓 Toggling system appearance")
        
        guard hasAppleEventsPermission() else {
            requestAppleEventsPermission()
            return
        }
        
        let script = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to not dark mode
            end tell
        end tell
        """
        
        executeAppleScript(script)
    }
    
    /// Sets the system appearance to a specific mode
    func setDarkMode(_ enabled: Bool) {
        logger.info("🌓 Setting dark mode: \(enabled)")
        
        guard hasAppleEventsPermission() else {
            requestAppleEventsPermission()
            return
        }
        
        let script = """
        tell application "System Events"
            tell appearance preferences
                set dark mode to \(enabled)
            end tell
        end tell
        """
        
        executeAppleScript(script)
    }
    
    
    // MARK: - Control Center Commands
    
    func getControlCenterCommands(matching query: String) -> [ControlCenterCommand] {
        var commands: [ControlCenterCommand] = []
        
        // Appearance toggle command
        if matchesQuery(query, terms: [
            "dark mode", "light mode", "appearance", "theme", "dark", "light",
            "toggle appearance", "switch theme", "mode", "appearance mode",
            "toggle", "switch", "toggle dark", "toggle light", "toggle mode"
        ]) {
            let title = "Toggle Appearance"
            let subtitle = "Switch between Light and Dark mode"
            let icon = "circle.lefthalf.filled"
            
            commands.append(ControlCenterCommand(
                id: "toggle_appearance",
                title: title,
                subtitle: subtitle,
                icon: icon,
                category: .appearance,
                action: { [weak self] in
                    self?.toggleSystemAppearance()
                }
            ))
        }
        
        // System Settings commands
        commands.append(contentsOf: getSystemSettingsCommands(matching: query))
        
        return commands
    }
    
    // MARK: - System Settings Commands
    
    func getSystemSettingsCommands(matching query: String) -> [ControlCenterCommand] {
        var commands: [ControlCenterCommand] = []
        
        // Bluetooth Settings
        if matchesQuery(query, terms: [
            "bluetooth", "bt", "wireless", "pairing", "bluetooth settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "bluetooth_settings",
                title: "Bluetooth Settings",
                subtitle: "Open Bluetooth preferences",
                icon: "antenna.radiowaves.left.and.right",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.preferences.Bluetooth")
                }
            ))
        }
        
        // WiFi/Network Settings
        if matchesQuery(query, terms: [
            "wifi", "wi-fi", "wireless", "network", "internet", "network settings", "wifi settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "wifi_settings",
                title: "WiFi Settings",
                subtitle: "Open WiFi & Network preferences",
                icon: "wifi",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.Network-Settings.extension?Wi-Fi")
                }
            ))
        }
        
        // System Update
        if matchesQuery(query, terms: [
            "update", "software update", "system update", "upgrade", "updates", "software upgrade"
        ]) {
            commands.append(ControlCenterCommand(
                id: "system_update",
                title: "Software Update",
                subtitle: "Check for system updates",
                icon: "gear.badge.questionmark",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.Software-Update-Settings.extension")
                }
            ))
        }
        
        // Security & Privacy
        if matchesQuery(query, terms: [
            "security", "privacy", "permissions", "firewall", "security settings", "privacy settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "security_privacy",
                title: "Security & Privacy",
                subtitle: "Open Security & Privacy settings",
                icon: "lock.shield",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension")
                }
            ))
        }
        
        // Notifications
        if matchesQuery(query, terms: [
            "notifications", "alerts", "banners", "notification settings", "notification center"
        ]) {
            commands.append(ControlCenterCommand(
                id: "notifications",
                title: "Notifications",
                subtitle: "Configure notification settings",
                icon: "bell",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.Notifications-Settings.extension")
                }
            ))
        }
        
        // Apple ID
        if matchesQuery(query, terms: [
            "apple id", "appleid", "icloud", "apple account", "account settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "apple_id",
                title: "Apple ID",
                subtitle: "Manage your Apple ID settings",
                icon: "person.crop.circle",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.systempreferences.AppleIDSettings")
                }
            ))
        }
        
        // Sharing
        if matchesQuery(query, terms: [
            "sharing", "file sharing", "screen sharing", "remote login", "sharing settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "sharing",
                title: "Sharing",
                subtitle: "Configure sharing preferences",
                icon: "square.and.arrow.up",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.preferences.sharing")
                }
            ))
        }
        
        // Screen Time
        if matchesQuery(query, terms: [
            "screen time", "screentime", "app limits", "downtime", "screen time settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "screen_time",
                title: "Screen Time",
                subtitle: "Manage Screen Time settings",
                icon: "hourglass",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.Screen-Time-Settings.extension")
                }
            ))
        }
        
        // Keyboard Settings
        if matchesQuery(query, terms: [
            "keyboard", "typing", "shortcuts", "key repeat", "modifier keys", "keyboard settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "keyboard_settings",
                title: "Keyboard",
                subtitle: "Configure keyboard and typing preferences",
                icon: "keyboard",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
                }
            ))
        }
        
        // Mouse Settings
        if matchesQuery(query, terms: [
            "mouse", "clicking", "scrolling", "pointer", "mouse settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "mouse_settings",
                title: "Mouse",
                subtitle: "Configure mouse and pointer preferences",
                icon: "computermouse",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.preference.mouse")
                }
            ))
        }
        
        // Trackpad Settings
        if matchesQuery(query, terms: [
            "trackpad", "gestures", "tap to click", "tracking speed", "trackpad settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "trackpad_settings",
                title: "Trackpad",
                subtitle: "Configure trackpad gestures and preferences",
                icon: "trackpad",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.Trackpad-Settings.extension")
                }
            ))
        }
        
        // Display Settings
        if matchesQuery(query, terms: [
            "display", "monitor", "resolution", "brightness", "displays", "screen", "display settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "display_settings",
                title: "Displays",
                subtitle: "Configure display resolution and arrangement",
                icon: "display",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.Displays-Settings.extension")
                }
            ))
        }
        
        // Dock Settings
        if matchesQuery(query, terms: [
            "dock", "dock size", "magnification", "hiding", "dock settings", "dock preferences"
        ]) {
            commands.append(ControlCenterCommand(
                id: "dock_settings",
                title: "Dock & Menu Bar",
                subtitle: "Configure Dock appearance and behavior",
                icon: "dock.rectangle",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.preference.dock")
                }
            ))
        }
        
        // Date & Time Settings
        if matchesQuery(query, terms: [
            "date", "time", "clock", "timezone", "date time", "time zone", "date settings", "time settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "datetime_settings",
                title: "Date & Time",
                subtitle: "Set date, time, and time zone",
                icon: "clock",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.Date-Time-Settings.extension")
                }
            ))
        }
        
        // Battery Settings
        if matchesQuery(query, terms: [
            "battery", "power", "energy", "low power mode", "battery health", "battery settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "battery_settings",
                title: "Battery",
                subtitle: "Monitor battery usage and power settings",
                icon: "battery.100percent",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.Battery-Settings.extension")
                }
            ))
        }
        
        // Login Items
        if matchesQuery(query, terms: [
            "login items", "startup", "launch", "startup items", "login", "startup programs"
        ]) {
            commands.append(ControlCenterCommand(
                id: "login_items",
                title: "Login Items",
                subtitle: "Manage apps that open at login",
                icon: "person.badge.key",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
                }
            ))
        }
        
        // Time Machine
        if matchesQuery(query, terms: [
            "time machine", "backup", "backups", "restore", "time machine settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "time_machine",
                title: "Time Machine",
                subtitle: "Configure automatic backups",
                icon: "clock.arrow.circlepath",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.TimeMachine-Settings.extension")
                }
            ))
        }
        
        // Control Center Settings
        if matchesQuery(query, terms: [
            "control center", "menu bar", "control center settings", "menu bar settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "control_center_settings",
                title: "Control Center",
                subtitle: "Customize Control Center and menu bar",
                icon: "switch.2",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.Control-Center-Settings.extension")
                }
            ))
        }
        
        // Game Center
        if matchesQuery(query, terms: [
            "game center", "gaming", "games", "game center settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "game_center",
                title: "Game Center",
                subtitle: "Manage Game Center preferences",
                icon: "gamecontroller",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.Game-Center-Settings.extension")
                }
            ))
        }
        
        // Extensions
        if matchesQuery(query, terms: [
            "extensions", "plugins", "add-ons", "extensions settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "extensions_settings",
                title: "Extensions",
                subtitle: "Manage system extensions and plugins",
                icon: "puzzlepiece.extension",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.Extensions-Settings.extension")
                }
            ))
        }
        
        // Accessibility
        if matchesQuery(query, terms: [
            "accessibility", "voiceover", "zoom", "assistive", "accessibility settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "accessibility_settings",
                title: "Accessibility",
                subtitle: "Configure accessibility features",
                icon: "accessibility",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.preference.universalaccess")
                }
            ))
        }
        
        // Sidecar
        if matchesQuery(query, terms: [
            "sidecar", "ipad", "extended display", "sidecar settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "sidecar_settings",
                title: "Sidecar",
                subtitle: "Use iPad as extended display",
                icon: "ipad.and.arrow.forward",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.preference.sidecar")
                }
            ))
        }
        
        // Internet Accounts
        if matchesQuery(query, terms: [
            "internet accounts", "email", "mail", "accounts", "cloud accounts", "email accounts"
        ]) {
            commands.append(ControlCenterCommand(
                id: "internet_accounts",
                title: "Internet Accounts",
                subtitle: "Add email, contacts, and calendar accounts",
                icon: "at",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.preferences.internetaccounts")
                }
            ))
        }
        
        // Wallpaper
        if matchesQuery(query, terms: [
            "wallpaper", "background", "desktop background", "wallpaper settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "wallpaper_settings",
                title: "Wallpaper",
                subtitle: "Change desktop wallpaper",
                icon: "photo.on.rectangle",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.preferences.wallpaper")
                }
            ))
        }
        
        // Passwords & Passkeys
        if matchesQuery(query, terms: [
            "passwords", "passkeys", "keychain", "password manager", "passwords settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "passwords_settings",
                title: "Passwords",
                subtitle: "Manage passwords and passkeys",
                icon: "key",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.preferences.passkeys")
                }
            ))
        }
        
        // Printers & Scanners
        if matchesQuery(query, terms: [
            "printers", "scanners", "printing", "scanning", "print", "scan", "printer settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "printers_scanners",
                title: "Printers & Scanners",
                subtitle: "Add and manage printers and scanners",
                icon: "printer",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.preference.printfax")
                }
            ))
        }
        
        // Energy Saver
        if matchesQuery(query, terms: [
            "energy saver", "power management", "sleep", "energy", "energy settings"
        ]) {
            commands.append(ControlCenterCommand(
                id: "energy_saver",
                title: "Energy Saver",
                subtitle: "Configure power management settings",
                icon: "leaf",
                category: .systemSettings,
                action: { [weak self] in
                    self?.openSystemPreference("x-apple.systempreferences:com.apple.Energy-Saver-Settings.extension")
                }
            ))
        }
        
        return commands
    }
    
    // MARK: - Permission Management
    
    /// Checks if the app has Apple Events permission
    private func hasAppleEventsPermission() -> Bool {
        let testScript = """
        tell application "System Events"
            tell appearance preferences
                return dark mode
            end tell
        end tell
        """
        
        var error: NSDictionary?
        let scriptObject = NSAppleScript(source: testScript)
        scriptObject?.executeAndReturnError(&error)
        
        if let error = error {
            let errorCode = error[NSAppleScript.errorNumber] as? Int
            if errorCode == -1743 {
                logger.info("📝 Apple Events permission required")
                return false
            }
            logger.error("❌ AppleScript error: \(errorCode ?? 0)")
            return false
        }
        
        return true
    }
    
    /// Requests Apple Events permission from the user
    private func requestAppleEventsPermission() {
        logger.info("📝 Requesting Apple Events permission from user")
        showPermissionDialog()
    }
    
    /// Shows a dialog to guide the user through granting Apple Events permission
    private func showPermissionDialog() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Automation Permission Required"
            alert.informativeText = """
            Trace needs permission to control system appearance.
            
            To grant permission:
            1. Click "Open System Settings"
            2. Go to Privacy & Security → Automation
            3. Find "Trace" and enable "System Events"
            4. Try the dark mode toggle again
            
            If Trace doesn't appear, try the alternative method.
            """
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Try Alternative")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .informational
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.openSystemSettings()
            } else if response == .alertSecondButtonReturn {
                self.tryAlternativePermissionMethod()
            }
        }
    }
    
    /// Opens System Settings to the Automation panel
    private func openSystemSettings() {
        let settingsURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        if let url = URL(string: settingsURL) {
            NSWorkspace.shared.open(url)
            logger.info("✅ Opened System Settings Automation panel")
        } else {
            logger.error("❌ Failed to open System Settings")
        }
    }
    
    /// Alternative method using osascript to trigger permission registration
    private func tryAlternativePermissionMethod() {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", "tell application \"System Events\" to return dark mode of appearance preferences"]
        
        do {
            try task.run()
            logger.info("✅ Executed osascript alternative method")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let alert = NSAlert()
                alert.messageText = "Alternative Method Complete"
                alert.informativeText = "Check System Settings → Automation for 'osascript' or 'Terminal' and enable System Events."
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        } catch {
            logger.error("❌ Alternative method failed: \(error)")
        }
    }
    
    // MARK: - Private Helpers
    
    /// Opens a specific System Preference pane using URL scheme
    private func openSystemPreference(_ urlString: String) {
        logger.info("🔧 Opening system preference: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            logger.error("❌ Invalid system preference URL: \(urlString)")
            return
        }
        
        if NSWorkspace.shared.open(url) {
            logger.info("✅ Successfully opened system preference")
        } else {
            logger.error("❌ Failed to open system preference: \(urlString)")
        }
    }
    
    /// Executes an AppleScript and logs the result
    private func executeAppleScript(_ script: String) {
        var error: NSDictionary?
        let scriptObject = NSAppleScript(source: script)
        scriptObject?.executeAndReturnError(&error)
        
        if let error = error {
            let errorCode = error[NSAppleScript.errorNumber] as? Int ?? 0
            logger.error("❌ AppleScript failed with error \(errorCode): \(error)")
        } else {
            logger.info("✅ AppleScript executed successfully")
        }
    }
    
    /// Checks if a query matches any of the provided search terms
    private func matchesQuery(_ query: String, terms: [String]) -> Bool {
        let queryLower = query.lowercased()
        return terms.contains { term in
            let termLower = term.lowercased()
            return termLower.contains(queryLower) || queryLower.contains(termLower)
        }
    }
}

// MARK: - Control Center Command Model

struct ControlCenterCommand {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let category: ResultCategory
    let action: () -> Void
}