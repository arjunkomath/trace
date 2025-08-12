//
//  Logging.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import Foundation
import os.log

/// Centralized logging utility for the app
enum AppLogger {
    /// Creates a logger for the specified category
    /// - Parameter category: The logging category (e.g., "AppDelegate", "AppSearchManager")
    /// - Returns: A configured Logger instance
    static func logger(for category: String) -> Logger {
        Logger(subsystem: AppConstants.bundleIdentifier, category: category)
    }
    
    // MARK: - Predefined Loggers
    
    static let appDelegate = logger(for: "AppDelegate")
    static let appSearchManager = logger(for: "AppSearchManager")
    static let hotkeyManager = logger(for: "HotkeyManager")
    static let settingsView = logger(for: "SettingsView")
    static let launcherView = logger(for: "LauncherView")
    static let launcherWindow = logger(for: "LauncherWindow")
    static let windowManager = logger(for: "WindowManager")
    static let networkUtilities = logger(for: "NetworkUtilities")
    static let usageTracker = logger(for: "UsageTracker")
    static let hotkeyRegistry = logger(for: "HotkeyRegistry")
    static let windowHotkeyManager = logger(for: "WindowHotkeyManager")
    static let settingsManager = logger(for: "SettingsManager")
    static let actionExecutor = logger(for: "ActionExecutor")
    static let appHotkeyManager = logger(for: "AppHotkeyManager")
    static let folderManager = logger(for: "FolderManager")
    static let permissionManager = logger(for: "PermissionManager")
    static let controlCenterManager = logger(for: "ControlCenterManager")
}