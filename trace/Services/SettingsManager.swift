//
//  SettingsManager.swift
//  trace
//
//  Created by Claude on 8/10/2025.
//

import Foundation
import os.log

// MARK: - Settings Data Structures

struct TraceSettings: Codable {
    // General Settings
    var resultsLayout: String = "compact"
    var showMenuBarIcon: Bool = true  // Default to true - show menu bar icon
    var launchAtLogin: Bool = false
    
    // Main Hotkey
    var mainHotkeyKeyCode: Int = 49 // Default: Space
    var mainHotkeyModifiers: Int = 524288 // Default: Option
    
    // Window Hotkeys
    var windowHotkeys: [String: WindowHotkeyData] = [:]
    
    // App Hotkeys  
    var appHotkeys: [String: AppHotkeyData] = [:]
    
    // Custom Folders
    var customFolders: [CustomFolderData] = []
    var folderHotkeys: [String: String] = [:]
    
    // Settings metadata
    var version: String = "1.0"
    var lastModified: Date = Date()
    
    struct WindowHotkeyData: Codable {
        let hotkey: String
        let keyCode: Int
        let modifiers: Int
    }
    
    struct AppHotkeyData: Codable {
        let hotkey: String
        let keyCode: Int
        let modifiers: Int
    }
    
    struct CustomFolderData: Codable {
        let id: String
        let name: String
        let path: String
        let isDefault: Bool
    }
}

// MARK: - Settings Manager

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    private let logger = Logger(subsystem: "com.techulus.trace", category: "SettingsManager")
    private let fileManager = FileManager.default
    
    @Published var settings: TraceSettings
    
    private let settingsURL: URL
    
    private init() {
        // Create settings directory in Application Support
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let traceSettingsDir = appSupportURL.appendingPathComponent("Trace", isDirectory: true)
        
        // Ensure directory exists
        try? fileManager.createDirectory(at: traceSettingsDir, withIntermediateDirectories: true)
        
        self.settingsURL = traceSettingsDir.appendingPathComponent("settings.json")
        
        // Load existing settings or create defaults
        if let loadedSettings = Self.loadSettings(from: settingsURL) {
            self.settings = loadedSettings
            logger.info("✅ Loaded existing settings from file")
            logger.info("🔑 Loaded main hotkey: keyCode=\(self.settings.mainHotkeyKeyCode), modifiers=\(self.settings.mainHotkeyModifiers)")
        } else {
            self.settings = TraceSettings()
            logger.info("📝 Created default settings (no existing file)")
            logger.info("🔑 Default main hotkey: keyCode=\(self.settings.mainHotkeyKeyCode), modifiers=\(self.settings.mainHotkeyModifiers)")
            // Save default settings immediately
            saveSettings()
        }
    }
    
    // MARK: - File Operations
    
    private static func loadSettings(from url: URL) -> TraceSettings? {
        let logger = Logger(subsystem: "com.techulus.trace", category: "SettingsManager")
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let settings = try decoder.decode(TraceSettings.self, from: data)
            logger.info("Successfully loaded settings from: \(url.path)")
            return settings
        } catch {
            logger.error("Failed to load settings: \(error.localizedDescription)")
            return nil
        }
    }
    
    func saveSettings() {
        settings.lastModified = Date()
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(settings)
            try data.write(to: settingsURL)
            logger.info("Successfully saved settings to: \(self.settingsURL.path)")
        } catch {
            logger.error("Failed to save settings: \(error.localizedDescription)")
        }
    }
    
    // MARK: - General Settings
    
    func updateResultsLayout(_ layout: String) {
        settings.resultsLayout = layout
        saveSettings()
    }
    
    func updateShowMenuBarIcon(_ show: Bool) {
        settings.showMenuBarIcon = show
        saveSettings()
    }
    
    func updateLaunchAtLogin(_ launch: Bool) {
        settings.launchAtLogin = launch
        saveSettings()
    }
    
    // MARK: - Main Hotkey
    
    func updateMainHotkey(keyCode: Int, modifiers: Int) {
        logger.info("🔑 Updating main hotkey: keyCode=\(keyCode), modifiers=\(modifiers)")
        settings.mainHotkeyKeyCode = keyCode
        settings.mainHotkeyModifiers = modifiers
        saveSettings()
        logger.info("🔑 Main hotkey saved: keyCode=\(self.settings.mainHotkeyKeyCode), modifiers=\(self.settings.mainHotkeyModifiers)")
    }
    
    // MARK: - Window Hotkey
    
    func updateWindowHotkey(for position: String, hotkey: String, keyCode: Int, modifiers: Int) {
        settings.windowHotkeys[position] = TraceSettings.WindowHotkeyData(
            hotkey: hotkey,
            keyCode: keyCode,
            modifiers: modifiers
        )
        saveSettings()
    }
    
    func removeWindowHotkey(for position: String) {
        settings.windowHotkeys.removeValue(forKey: position)
        saveSettings()
    }
    
    func getWindowHotkey(for position: String) -> TraceSettings.WindowHotkeyData? {
        return settings.windowHotkeys[position]
    }
    
    // MARK: - App Hotkeys
    
    func updateAppHotkey(for bundleId: String, hotkey: String, keyCode: Int, modifiers: Int) {
        settings.appHotkeys[bundleId] = TraceSettings.AppHotkeyData(
            hotkey: hotkey,
            keyCode: keyCode,
            modifiers: modifiers
        )
        saveSettings()
    }
    
    func removeAppHotkey(for bundleId: String) {
        settings.appHotkeys.removeValue(forKey: bundleId)
        saveSettings()
    }
    
    func getAppHotkey(for bundleId: String) -> TraceSettings.AppHotkeyData? {
        return settings.appHotkeys[bundleId]
    }
    
    func getAllAppHotkeys() -> [String: String] {
        var result: [String: String] = [:]
        for (bundleId, hotkeyData) in settings.appHotkeys {
            result[bundleId] = hotkeyData.hotkey
        }
        return result
    }
    
    // MARK: - Custom Folders
    
    func addCustomFolder(_ folder: TraceSettings.CustomFolderData) {
        settings.customFolders.append(folder)
        saveSettings()
    }
    
    func updateCustomFolder(_ folder: TraceSettings.CustomFolderData) {
        if let index = settings.customFolders.firstIndex(where: { $0.id == folder.id }) {
            settings.customFolders[index] = folder
            saveSettings()
        }
    }
    
    func removeCustomFolder(withId id: String) {
        settings.customFolders.removeAll { $0.id == id }
        saveSettings()
    }
    
    // MARK: - Folder Hotkeys
    
    func updateFolderHotkey(for folderId: String, hotkey: String?) {
        if let hotkey = hotkey {
            settings.folderHotkeys[folderId] = hotkey
        } else {
            settings.folderHotkeys.removeValue(forKey: folderId)
        }
        saveSettings()
    }
    
    func getFolderHotkey(for folderId: String) -> String? {
        return settings.folderHotkeys[folderId]
    }
    
    // MARK: - Import/Export
    
    func exportSettings() -> TraceSettings {
        // Return current settings with updated metadata
        var exportSettings = settings
        exportSettings.lastModified = Date()
        return exportSettings
    }
    
    func importSettings(_ importedSettings: TraceSettings, overwriteExisting: Bool = false) throws {
        logger.info("Importing settings (overwrite: \(overwriteExisting))...")
        
        if overwriteExisting {
            // Replace all settings
            settings = importedSettings
        } else {
            // Merge settings, keeping existing values when they exist
            
            // General settings - only update if current values are defaults
            if settings.resultsLayout == "compact" {
                settings.resultsLayout = importedSettings.resultsLayout
            }
            
            // Main hotkey - only update if current is default
            if settings.mainHotkeyKeyCode == 49 && settings.mainHotkeyModifiers == 524288 {
                settings.mainHotkeyKeyCode = importedSettings.mainHotkeyKeyCode
                settings.mainHotkeyModifiers = importedSettings.mainHotkeyModifiers
            }
            
            // Window hotkeys - add new ones, keep existing
            for (position, hotkeyData) in importedSettings.windowHotkeys {
                if settings.windowHotkeys[position] == nil {
                    settings.windowHotkeys[position] = hotkeyData
                }
            }
            
            // App hotkeys - add new ones, keep existing
            for (bundleId, hotkeyData) in importedSettings.appHotkeys {
                if settings.appHotkeys[bundleId] == nil {
                    settings.appHotkeys[bundleId] = hotkeyData
                }
            }
            
            // Custom folders - add new ones
            for folder in importedSettings.customFolders {
                if !settings.customFolders.contains(where: { $0.id == folder.id }) {
                    settings.customFolders.append(folder)
                }
            }
            
            // Folder hotkeys - add new ones, keep existing
            for (folderId, hotkey) in importedSettings.folderHotkeys {
                if settings.folderHotkeys[folderId] == nil {
                    settings.folderHotkeys[folderId] = hotkey
                }
            }
            
            // Usage data is handled separately by UsageTracker service
        }
        
        // Update metadata
        settings.version = importedSettings.version
        settings.lastModified = Date()
        
        // Save the merged/replaced settings
        saveSettings()
        
        logger.info("Successfully imported settings")
    }
    
    func exportToFile() throws -> URL {
        let exportSettings = exportSettings()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData = try encoder.encode(exportSettings)
        
        // Create filename with timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "trace_settings_\(timestamp).json"
        
        // Get Documents directory
        let documentsURL = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fileURL = documentsURL.appendingPathComponent(filename)
        
        try jsonData.write(to: fileURL)
        
        logger.info("Exported settings to: \(fileURL.path)")
        return fileURL
    }
    
    func importFromFile(_ fileURL: URL, overwriteExisting: Bool = false) throws {
        let jsonData = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let importedSettings = try decoder.decode(TraceSettings.self, from: jsonData)
        
        // Validate version compatibility
        guard importedSettings.version == "1.0" else {
            throw SettingsError.incompatibleVersion(importedSettings.version)
        }
        
        try importSettings(importedSettings, overwriteExisting: overwriteExisting)
        
        logger.info("Successfully imported settings from: \(fileURL.path)")
    }
    
    // MARK: - Migration from UserDefaults
    
    func migrateFromUserDefaults() {
        // Check if we've already migrated (settings file exists with non-default values)
        if fileManager.fileExists(atPath: settingsURL.path) {
            logger.info("Settings file already exists, skipping UserDefaults migration")
            return
        }
        
        logger.info("Starting migration from UserDefaults...")
        
        let userDefaults = UserDefaults.standard
        var migrated = false
        
        // Migrate general settings
        if let resultsLayout = userDefaults.string(forKey: "resultsLayout") {
            settings.resultsLayout = resultsLayout
            migrated = true
        }
        
        if userDefaults.object(forKey: "showMenuBarIcon") != nil {
            settings.showMenuBarIcon = userDefaults.bool(forKey: "showMenuBarIcon")
            migrated = true
        }
        
        // Migrate main hotkey
        if userDefaults.object(forKey: "hotkey_keyCode") != nil {
            settings.mainHotkeyKeyCode = userDefaults.integer(forKey: "hotkey_keyCode")
            settings.mainHotkeyModifiers = userDefaults.integer(forKey: "hotkey_modifiers")
            migrated = true
        }
        
        // Migrate window hotkeys
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix("window_") && key.hasSuffix("_hotkey") {
                let positionPart = String(key.dropFirst(7).dropLast(7)) // Remove "window_" and "_hotkey"
                if let hotkey = userDefaults.string(forKey: key), !hotkey.isEmpty {
                    let keyCode = userDefaults.integer(forKey: "window_\(positionPart)_keycode")
                    let modifiers = userDefaults.integer(forKey: "window_\(positionPart)_modifiers")
                    
                    settings.windowHotkeys[positionPart] = TraceSettings.WindowHotkeyData(
                        hotkey: hotkey,
                        keyCode: keyCode,
                        modifiers: modifiers
                    )
                    migrated = true
                }
            }
        }
        
        // Migrate app hotkeys
        for key in userDefaults.dictionaryRepresentation().keys {
            if key.hasPrefix("app_") && key.hasSuffix("_hotkey") {
                let bundleId = String(key.dropFirst(4).dropLast(7)) // Remove "app_" and "_hotkey"
                if let hotkey = userDefaults.string(forKey: key), !hotkey.isEmpty {
                    let keyCode = userDefaults.integer(forKey: "app_\(bundleId)_keycode")
                    let modifiers = userDefaults.integer(forKey: "app_\(bundleId)_modifiers")
                    
                    settings.appHotkeys[bundleId] = TraceSettings.AppHotkeyData(
                        hotkey: hotkey,
                        keyCode: keyCode,
                        modifiers: modifiers
                    )
                    migrated = true
                }
            }
        }
        
        // Migrate custom folders
        if let data = userDefaults.data(forKey: "com.trace.customFolders"),
           let folders = try? JSONDecoder().decode([FolderShortcut].self, from: data) {
            for folder in folders where !folder.isDefault {
                settings.customFolders.append(TraceSettings.CustomFolderData(
                    id: folder.id,
                    name: folder.name,
                    path: folder.path,
                    isDefault: folder.isDefault
                ))
            }
            migrated = true
        }
        
        // Migrate folder hotkeys
        if let data = userDefaults.data(forKey: "com.trace.folderHotkeys"),
           let hotkeys = try? JSONDecoder().decode([String: String].self, from: data) {
            settings.folderHotkeys.merge(hotkeys) { _, new in new }
            migrated = true
        }
        
        if migrated {
            saveSettings()
            logger.info("Successfully migrated settings from UserDefaults")
            
            // Clear UserDefaults after successful migration
            clearUserDefaults()
        } else {
            logger.info("No UserDefaults to migrate")
        }
    }
    
    private func clearUserDefaults() {
        let userDefaults = UserDefaults.standard
        let keysToRemove = [
            "resultsLayout", "showMenuBarIcon", "hotkey_keyCode", "hotkey_modifiers",
            "com.trace.customFolders", "com.trace.folderHotkeys"
        ]
        
        for key in keysToRemove {
            userDefaults.removeObject(forKey: key)
        }
        
        // Remove window hotkeys
        let allKeys = Array(userDefaults.dictionaryRepresentation().keys)
        for key in allKeys {
            if (key.hasPrefix("window_") && (key.hasSuffix("_hotkey") || key.hasSuffix("_keycode") || key.hasSuffix("_modifiers"))) ||
               (key.hasPrefix("app_") && (key.hasSuffix("_hotkey") || key.hasSuffix("_keycode") || key.hasSuffix("_modifiers"))) {
                userDefaults.removeObject(forKey: key)
            }
        }
        
        logger.info("Cleared migrated UserDefaults keys")
    }
}

// MARK: - Error Types

enum SettingsError: LocalizedError {
    case incompatibleVersion(String)
    case fileNotFound
    case invalidFormat
    case importFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .incompatibleVersion(let version):
            return "Settings file version \(version) is not compatible with this version of Trace"
        case .fileNotFound:
            return "Settings file not found"
        case .invalidFormat:
            return "Invalid settings file format"
        case .importFailed(let reason):
            return "Failed to import settings: \(reason)"
        }
    }
}
