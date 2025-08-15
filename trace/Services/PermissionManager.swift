//
//  PermissionManager.swift
//  trace
//
//  Created by Claude on 8/10/2025.
//

import AppKit
import ApplicationServices
import os.log

/// Capability-based permission system that tests actual functionality instead of relying on system APIs
class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    private let logger = AppLogger.permissionManager
    
    /// Published properties for SwiftUI views to observe
    @Published var windowManagementAvailable = false
    @Published private(set) var systemEventsAvailable = false
    
    /// Track the last active application before Trace became frontmost
    internal var lastActiveApplication: NSRunningApplication?
    
    /// Notification observer for app activation
    private var appActivationObserver: Any?
    
    private init() {
        setupAppActivationObserver()
    }
    
    deinit {
        if let observer = appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
    
    // MARK: - App Activation Monitoring
    
    /// Sets up observer for application activation notifications
    private func setupAppActivationObserver() {
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }
        logger.debug("✅ App activation observer setup complete")
    }
    
    /// Handles app activation notifications
    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return
        }
        
        lastActiveApplication = app
        logger.debug("App activated: \(app.localizedName ?? app.bundleIdentifier ?? "Unknown")")
    }
    
    // MARK: - Window Management Permissions
    
    /// Updates the last active application before showing Trace launcher
    func updateLastActiveApplication() {
        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastActiveApplication = frontmostApp
            logger.debug("Stored last active application: \(frontmostApp.localizedName ?? frontmostApp.bundleIdentifier ?? "Unknown")")
        }
    }
    
    /// Tests if we can actually perform window management operations
    func testWindowManagementCapability() -> WindowManagementResult {
        logger.info("Testing window management capability...")
        
        // First check if we have basic accessibility permissions
        guard AXIsProcessTrusted() else {
            logger.warning("AXIsProcessTrusted returned false - permissions denied")
            return .permissionDenied
        }
        
        // Try to find a suitable application with windows
        let targetApp = findTargetApplication()
        guard let app = targetApp else {
            logger.info("No suitable target application found - permissions granted but no target")
            return .noTargetApp
        }
        
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        
        // Test if we can get the window list
        var windows: CFTypeRef?
        let windowsResult = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows)
        
        guard windowsResult == .success,
              let windowArray = windows as? [AXUIElement],
              !windowArray.isEmpty else {
            logger.info("App has no accessible windows - permissions granted but no windows")
            return .noWindows
        }
        
        let testWindow = windowArray[0]
        logger.info("Window management capability test passed for app: \(app.localizedName ?? app.bundleIdentifier ?? "Unknown")")
        return .available(window: testWindow, app: app)
    }
    
    /// Finds a suitable target application for window management
    private func findTargetApplication() -> NSRunningApplication? {
        // Always prefer the stored last active application when available
        // This ensures we target the window the user was working on before opening Trace
        if let lastApp = lastActiveApplication {
            return lastApp
        }
        
        // Fallback: frontmost app if it's not Trace
        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            return frontmostApp
        }
        
        // Third try: find recently active applications (excluding Trace and system apps)
        let runningApps = NSWorkspace.shared.runningApplications
        let candidateApps = runningApps.filter { app in
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { return false }
            guard app.activationPolicy == .regular else { return false }
            
            // Skip system and utility apps that typically don't have manageable windows
            let excludedBundleIds = [
                "com.apple.finder",
                "com.apple.dock",
                "com.apple.systemuiserver",
                "com.apple.notificationcenterui",
                "com.apple.controlcenter"
            ]
            
            if let bundleId = app.bundleIdentifier, excludedBundleIds.contains(bundleId) {
                return false
            }
            
            return true
        }
        
        // Sort by activation policy and try to find one with windows
        let sortedApps = candidateApps.sorted { app1, app2 in
            // Prefer recently active apps
            return app1.isActive || (!app2.isActive && app1.bundleIdentifier?.localizedCompare(app2.bundleIdentifier ?? "") == .orderedAscending)
        }
        
        for app in sortedApps {
            // Quick check if this app has windows
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windows: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows)
            
            if result == .success,
               let windowArray = windows as? [AXUIElement],
               !windowArray.isEmpty {
                logger.debug("Found suitable fallback application: \(app.localizedName ?? app.bundleIdentifier ?? "Unknown")")
                return app
            }
        }
        
        logger.debug("No suitable application with windows found")
        return nil
    }
    
    /// Attempts to request accessibility permissions with proper user guidance
    func requestWindowManagementPermissions() {
        logger.info("Requesting accessibility permissions...")
        
        // First check if we might already have permissions
        let testResult = testWindowManagementCapability()
        if case .available = testResult {
            DispatchQueue.main.async {
                self.windowManagementAvailable = true
            }
            return
        }
        
        // Show only system permission dialog
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        // Don't show additional custom dialogs - let the system handle it
    }
    
    /// Performs a window management operation with automatic permission handling
    func performWindowOperation(_ operation: @escaping (AXUIElement) -> Bool, 
                              onSuccess: @escaping () -> Void = {},
                              onFailure: @escaping (WindowManagementError) -> Void = { _ in }) {
        
        let capability = testWindowManagementCapability()
        
        switch capability {
        case .available(let window, let app):
            let success = operation(window)
            if success {
                DispatchQueue.main.async {
                    self.windowManagementAvailable = true
                }
                
                // Restore focus to the target application after successful window operation
                app.activate(options: [.activateIgnoringOtherApps])
                logger.debug("Restored focus to app: \(app.localizedName ?? app.bundleIdentifier ?? "Unknown")")
                
                onSuccess()
            } else {
                onFailure(.operationFailed)
            }
            
        case .permissionDenied:
            DispatchQueue.main.async {
                self.windowManagementAvailable = false
            }
            onFailure(.permissionDenied)
            
        case .noTargetApp:
            onFailure(.noTargetApp)
            
        case .noWindows:
            onFailure(.noWindows)
        }
    }
    
    // MARK: - System Events (AppleScript) Permissions
    
    /// Tests if we can execute AppleScript commands for system control
    func testSystemEventsCapability() -> Bool {
        logger.info("Testing system events capability...")
        
        let script = """
            tell application "System Events"
                name of current desktop
            end tell
        """
        
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let _ = appleScript?.executeAndReturnError(&error)
        
        if error != nil {
            logger.warning("System events test failed: \(error?.description ?? "Unknown error")")
            DispatchQueue.main.async {
                self.systemEventsAvailable = false
            }
            return false
        }
        
        logger.info("System events capability test passed!")
        DispatchQueue.main.async {
            self.systemEventsAvailable = true
        }
        return true
    }
    
    /// Executes an AppleScript with automatic permission handling
    func executeAppleScript(_ script: String, 
                           onSuccess: @escaping (NSAppleEventDescriptor?) -> Void = { _ in },
                           onFailure: @escaping (String) -> Void = { _ in }) {
        
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        let result = appleScript?.executeAndReturnError(&error)
        
        if let error = error {
            let errorMessage = error.description
            logger.error("AppleScript execution failed: \(errorMessage)")
            DispatchQueue.main.async {
                self.systemEventsAvailable = false
            }
            
            if errorMessage.contains("not allowed assistive access") || 
               errorMessage.contains("accessibility") {
                onFailure("AppleScript requires accessibility permissions. Please grant permissions in System Settings.")
            } else {
                onFailure("AppleScript failed: \(errorMessage)")
            }
        } else {
            DispatchQueue.main.async {
                self.systemEventsAvailable = true
            }
            onSuccess(result)
        }
    }
    
    // MARK: - App Activation Helpers
    
    /// Activates the application that owns the given window to restore focus
    private func activateApplicationForWindow(_ window: AXUIElement) {
        var appPid: pid_t = 0
        let pidResult = AXUIElementGetPid(window, &appPid)
        
        if pidResult == .success,
           let targetApp = NSRunningApplication(processIdentifier: appPid) {
            // Activate the app to restore focus after window manipulation
            targetApp.activate(options: [.activateIgnoringOtherApps])
            logger.debug("Restored focus to app: \(targetApp.localizedName ?? targetApp.bundleIdentifier ?? "Unknown")")
        } else {
            logger.warning("Failed to activate app for window - could not get process ID")
        }
    }
    
    // MARK: - UI Helpers
    
    /// Shows an error message for window management failures
    func showWindowManagementError(_ error: WindowManagementError) {
        let (title, message) = error.userFriendlyDescription
        
        DispatchQueue.main.async {
            if case .permissionDenied = error {
                // For permission denied, just request permissions without showing additional dialog
                self.requestWindowManagementPermissions()
            } else {
                // For other errors, show a toast instead of modal dialog
                ToastManager.shared.showError("\(title): \(message)")
            }
        }
    }
}

// MARK: - Supporting Types

enum WindowManagementResult {
    case available(window: AXUIElement, app: NSRunningApplication)  // Window management is available with target window and app
    case permissionDenied       // Need accessibility permissions
    case noTargetApp           // No suitable target application
    case noWindows             // Target app has no windows
}

enum WindowManagementError {
    case permissionDenied
    case noTargetApp
    case noWindows
    case operationFailed
    
    var userFriendlyDescription: (title: String, message: String) {
        switch self {
        case .permissionDenied:
            return (
                "Permission Required",
                "Trace needs accessibility permission to manage windows. Click 'Grant Permission' to open System Settings."
            )
        case .noTargetApp:
            return (
                "No Target Application",
                "Please click on another application's window first, then try the window management command."
            )
        case .noWindows:
            return (
                "No Windows Available",
                "The target application doesn't have any windows to manage."
            )
        case .operationFailed:
            return (
                "Operation Failed",
                "The window management operation could not be completed. The target window may not support this operation."
            )
        }
    }
}