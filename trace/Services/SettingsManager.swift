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
    static let defaultLauncherVerticalPositionRatio = 0.78
    
    // General Settings
    var resultsLayout: String = "compact"
    var showMenuBarIcon: Bool = true  // Default to true - show menu bar icon
    var launchAtLogin: Bool = false
    var hasCompletedOnboarding: Bool = false
    var calendarSearchEnabled: Bool = false
    var accentColor: String = TraceAccent.system.rawValue
    var launcherVerticalPositionRatio: Double = TraceSettings.defaultLauncherVerticalPositionRatio
    var caffeinateFlags: String = CaffeinateManager.defaultFlags
    var dictationEnabled: Bool = false
    var dictationHotkey: String = ""
    var dictationHotkeyKeyCode: Int = 0
    var dictationHotkeyModifiers: Int = 0
    
    // Main Hotkey
    var mainHotkeyKeyCode: Int = 49 // Default: Space
    var mainHotkeyModifiers: Int = 2048 // Default: Option
    
    // Window Hotkeys
    var windowHotkeys: [String: WindowHotkeyData] = [:]
    
    // App Hotkeys  
    var appHotkeys: [String: AppHotkeyData] = [:]
    
    // Quick Links
    var quickLinks: [QuickLinkData] = []
    var quickLinksHasLoadedBefore: Bool = false
    
    // Settings metadata
    var version: String = "1.0"
    var lastModified: Date = Date()
    
    // Custom decoder to handle backward compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // flags
        resultsLayout = try container.decodeIfPresent(String.self, forKey: .resultsLayout) ?? "compact"
        showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        calendarSearchEnabled = try container.decodeIfPresent(Bool.self, forKey: .calendarSearchEnabled) ?? false
        accentColor = try container.decodeIfPresent(String.self, forKey: .accentColor) ?? TraceAccent.system.rawValue
        launcherVerticalPositionRatio = Self.clampLauncherVerticalPositionRatio(
            try container.decodeIfPresent(Double.self, forKey: .launcherVerticalPositionRatio) ?? Self.defaultLauncherVerticalPositionRatio
        )
        caffeinateFlags = try container.decodeIfPresent(String.self, forKey: .caffeinateFlags) ?? CaffeinateManager.defaultFlags
        dictationEnabled = try container.decodeIfPresent(Bool.self, forKey: .dictationEnabled) ?? false
        dictationHotkey = try container.decodeIfPresent(String.self, forKey: .dictationHotkey) ?? ""
        dictationHotkeyKeyCode = try container.decodeIfPresent(Int.self, forKey: .dictationHotkeyKeyCode) ?? 0
        dictationHotkeyModifiers = try container.decodeIfPresent(Int.self, forKey: .dictationHotkeyModifiers) ?? 0
        
        // hotkey
        mainHotkeyKeyCode = try container.decodeIfPresent(Int.self, forKey: .mainHotkeyKeyCode) ?? 49
        mainHotkeyModifiers = try container.decodeIfPresent(Int.self, forKey: .mainHotkeyModifiers) ?? 2048
        
        // configurations
        windowHotkeys = try container.decodeIfPresent([String: WindowHotkeyData].self, forKey: .windowHotkeys) ?? [:]
        appHotkeys = try container.decodeIfPresent([String: AppHotkeyData].self, forKey: .appHotkeys) ?? [:]
        quickLinks = try container.decodeIfPresent([QuickLinkData].self, forKey: .quickLinks) ?? []
        quickLinksHasLoadedBefore = try container.decodeIfPresent(Bool.self, forKey: .quickLinksHasLoadedBefore) ?? false
        
        // meta
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0"
        lastModified = try container.decodeIfPresent(Date.self, forKey: .lastModified) ?? Date()
    }
    
    init() {
        // All defaults are set in property declarations above
    }
    
    static func clampLauncherVerticalPositionRatio(_ ratio: Double) -> Double {
        min(max(ratio, 0), 1)
    }
    
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
    
    struct QuickLinkData: Codable {
        let id: String
        let name: String
        let urlString: String
        let iconName: String?
        let keywords: [String]
        let hotkey: String?
        let keyCode: Int
        let modifiers: Int
        let isSystemDefault: Bool
    }
}

// MARK: - Settings Manager

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    private let logger = AppLogger.settingsManager
    private let fileManager = FileManager.default
    
    @Published var settings: TraceSettings
    
    private let settingsURL: URL
    
    private init() {
        let traceSettingsDir = AppConstants.appDataDirectory
        
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
        let logger = AppLogger.settingsManager
        
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
        // Update lastModified synchronously before encoding
        settings.lastModified = Date()
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(settings)
            try data.write(to: settingsURL, options: .atomic)
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
    
    func updateOnboardingCompleted(_ completed: Bool) {
        settings.hasCompletedOnboarding = completed
        saveSettings()
    }
    
    func updateCalendarSearchEnabled(_ enabled: Bool) {
        settings.calendarSearchEnabled = enabled
        saveSettings()
    }
    
    var selectedAccent: TraceAccent {
        TraceAccent(rawValue: settings.accentColor) ?? .system
    }
    
    func updateAccentColor(_ accent: TraceAccent) {
        settings.accentColor = accent.rawValue
        saveSettings()
    }
    
    func updateLauncherVerticalPositionRatio(_ ratio: Double) {
        let clampedRatio = TraceSettings.clampLauncherVerticalPositionRatio(ratio)
        guard abs(settings.launcherVerticalPositionRatio - clampedRatio) > 0.0001 else { return }
        
        settings.launcherVerticalPositionRatio = clampedRatio
        saveSettings()
    }

    func updateCaffeinateFlags(_ flags: String) {
        guard settings.caffeinateFlags != flags else { return }

        settings.caffeinateFlags = flags
        saveSettings()
    }

    // MARK: - Dictation

    func updateDictationEnabled(_ enabled: Bool) {
        guard settings.dictationEnabled != enabled else { return }

        settings.dictationEnabled = enabled
        saveSettings()
    }

    func updateDictationHotkey(hotkey: String, keyCode: Int, modifiers: Int) {
        settings.dictationHotkey = hotkey
        settings.dictationHotkeyKeyCode = keyCode
        settings.dictationHotkeyModifiers = modifiers
        saveSettings()
    }

    func clearDictationHotkey() {
        settings.dictationHotkey = ""
        settings.dictationHotkeyKeyCode = 0
        settings.dictationHotkeyModifiers = 0
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
    
    
    // MARK: - Quick Links
    
    func addQuickLink(_ quickLink: TraceSettings.QuickLinkData) {
        settings.quickLinks.append(quickLink)
        saveSettings()
    }
    
    func updateQuickLink(_ quickLink: TraceSettings.QuickLinkData) {
        if let index = settings.quickLinks.firstIndex(where: { $0.id == quickLink.id }) {
            settings.quickLinks[index] = quickLink
            saveSettings()
        }
    }
    
    func removeQuickLink(withId id: String) {
        settings.quickLinks.removeAll { $0.id == id }
        saveSettings()
    }
    
    func getQuickLinks() -> [TraceSettings.QuickLinkData] {
        return settings.quickLinks
    }
    
    func updateQuickLinksHasLoadedBefore(_ hasLoaded: Bool) {
        settings.quickLinksHasLoadedBefore = hasLoaded
        saveSettings()
    }
    
    // MARK: - Quick Link Hotkeys
    
    func updateQuickLinkHotkey(for quickLinkId: String, hotkey: String?) {
        if let index = settings.quickLinks.firstIndex(where: { $0.id == quickLinkId }) {
            let quickLink = settings.quickLinks[index]
            let updatedQuickLink = TraceSettings.QuickLinkData(
                id: quickLink.id,
                name: quickLink.name,
                urlString: quickLink.urlString,
                iconName: quickLink.iconName,
                keywords: quickLink.keywords,
                hotkey: hotkey,
                keyCode: quickLink.keyCode,
                modifiers: quickLink.modifiers,
                isSystemDefault: quickLink.isSystemDefault
            )
            settings.quickLinks[index] = updatedQuickLink
            saveSettings()
        }
    }
    
    func getQuickLinkHotkey(for quickLinkId: String) -> String? {
        return settings.quickLinks.first { $0.id == quickLinkId }?.hotkey
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
            
            if settings.accentColor == TraceAccent.system.rawValue {
                settings.accentColor = importedSettings.accentColor
            }
            
            if settings.launcherVerticalPositionRatio == TraceSettings.defaultLauncherVerticalPositionRatio {
                settings.launcherVerticalPositionRatio = importedSettings.launcherVerticalPositionRatio
            }

            // Main hotkey - only update if current is default
            if settings.mainHotkeyKeyCode == 49 && settings.mainHotkeyModifiers == 2048 {
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
            
            // Quick links - add new ones
            for quickLink in importedSettings.quickLinks {
                if !settings.quickLinks.contains(where: { $0.id == quickLink.id }) {
                    settings.quickLinks.append(quickLink)
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
