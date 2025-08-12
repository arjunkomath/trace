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
    
    
    private init() {
    }
    
    // MARK: - Window Management Permissions
    
    /// Tests if we can actually perform window management operations
    func testWindowManagementCapability() -> WindowManagementResult {
        logger.info("Testing window management capability...")
        
        // First check if we have basic accessibility permissions
        guard AXIsProcessTrusted() else {
            logger.warning("AXIsProcessTrusted returned false - permissions denied")
            return .permissionDenied
        }
        
        // Try to find a suitable application with windows
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              frontmostApp.bundleIdentifier != Bundle.main.bundleIdentifier else {
            logger.info("No suitable frontmost application - permissions granted but no target")
            return .noTargetApp
        }
        
        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)
        
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
        logger.info("Window management capability test passed!")
        return .available(testWindow)
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
        case .available(let window):
            let success = operation(window)
            if success {
                DispatchQueue.main.async {
                    self.windowManagementAvailable = true
                }
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
    case available(AXUIElement)  // Window management is available with target window
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