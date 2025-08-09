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
    
    private let logger = Logger(subsystem: AppConstants.bundleIdentifier, category: "ControlCenter")
    
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
    
    /// Returns the current app appearance (true for dark, false for light)
    func getCurrentAppearance() -> Bool {
        if #available(macOS 10.14, *) {
            let appearance = NSApp.effectiveAppearance
            return appearance.name == .darkAqua
        }
        return false
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
            let isDark = getCurrentAppearance()
            let title = isDark ? "Switch to Light Mode" : "Switch to Dark Mode"
            let subtitle = "Toggle system appearance"
            let icon = isDark ? "sun.max" : "moon"
            
            commands.append(ControlCenterCommand(
                id: "toggle_appearance",
                title: title,
                subtitle: subtitle,
                icon: icon,
                category: "Appearance",
                action: { [weak self] in
                    self?.toggleSystemAppearance()
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
    let category: String
    let action: () -> Void
}