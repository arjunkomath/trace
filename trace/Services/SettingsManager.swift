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
    /// Per-source visibility in launcher search. Missing keys default to enabled.
    var enabledSearchResultSources: [String: Bool] = SearchResultSource.defaultEnabledMap
    var accentColor: String = TraceAccent.system.rawValue
    var launcherVerticalPositionRatio: Double = TraceSettings.defaultLauncherVerticalPositionRatio
    var caffeinateFlags: String = CaffeinateManager.defaultFlags
    /// Empty string means camera selection follows the macOS system preference.
    var mirrorCameraDeviceID: String = ""
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
        if let savedSources = try container.decodeIfPresent([String: Bool].self, forKey: .enabledSearchResultSources) {
            enabledSearchResultSources = SearchResultSource.mergedWithDefaults(savedSources)
        } else {
            // Existing installs: keep previous calendar preference, enable everything else.
            enabledSearchResultSources = SearchResultSource.defaultEnabledMap
            enabledSearchResultSources[SearchResultSource.calendar.rawValue] = calendarSearchEnabled
        }
        accentColor = try container.decodeIfPresent(String.self, forKey: .accentColor) ?? TraceAccent.system.rawValue
        launcherVerticalPositionRatio = Self.clampLauncherVerticalPositionRatio(
            try container.decodeIfPresent(Double.self, forKey: .launcherVerticalPositionRatio) ?? Self.defaultLauncherVerticalPositionRatio
        )
        caffeinateFlags = try container.decodeIfPresent(String.self, forKey: .caffeinateFlags) ?? CaffeinateManager.defaultFlags
        mirrorCameraDeviceID = try container.decodeIfPresent(String.self, forKey: .mirrorCameraDeviceID) ?? ""
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

struct SyncSettingsState: Codable {
    let version: Int
    let updatedAt: String
    let updatedBy: String?
    let sha256: String
    let settings: TraceSettings
}

struct SyncSettingsUploadRequest: Codable {
    let baseVersion: Int
    let updatedBy: String
    let settings: TraceSettings
}

private struct SyncConflictResponse: Codable {
    let currentVersion: Int
}

// MARK: - Settings Manager

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    private let logger = AppLogger.settingsManager
    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard
    private let syncServerURLKey = "sync_server_url"
    private let syncServerTokenKey = "sync_server_token"
    private let syncLastVersionKey = "sync_last_version"
    
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

    // MARK: - Sync Server Settings

    var syncServerURL: String {
        get { userDefaults.string(forKey: syncServerURLKey) ?? "" }
        set { userDefaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: syncServerURLKey) }
    }

    var syncServerToken: String {
        get { userDefaults.string(forKey: syncServerTokenKey) ?? "" }
        set { userDefaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: syncServerTokenKey) }
    }

    var syncLastVersion: Int {
        get { userDefaults.integer(forKey: syncLastVersionKey) }
        set { userDefaults.set(newValue, forKey: syncLastVersionKey) }
    }

    @MainActor
    func testSyncServerConnection() async throws -> SyncSettingsState? {
        let request = try makeSyncRequest(path: "/v1/settings", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = try httpStatusCode(from: response)

        switch statusCode {
        case 200:
            return try decodeSyncState(from: data)
        case 404:
            return nil
        case 401:
            throw SyncServerError.unauthorized
        default:
            throw SyncServerError.unexpectedStatus(statusCode)
        }
    }

    @MainActor
    func uploadSettingsToSyncServer() async throws -> SyncSettingsState {
        try await uploadSettingsToSyncServer(baseVersion: syncLastVersion, retryEmptyRemoteConflict: true)
    }

    @MainActor
    private func uploadSettingsToSyncServer(baseVersion: Int, retryEmptyRemoteConflict: Bool) async throws -> SyncSettingsState {
        let requestBody = SyncSettingsUploadRequest(
            baseVersion: baseVersion,
            updatedBy: Host.current().localizedName ?? "Trace Mac",
            settings: exportSettings()
        )

        var request = try makeSyncRequest(path: "/v1/settings", method: "PUT")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try syncJSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = try httpStatusCode(from: response)

        switch statusCode {
        case 200:
            let state = try decodeSyncState(from: data)
            syncLastVersion = state.version
            return state
        case 401:
            throw SyncServerError.unauthorized
        case 409:
            let conflict = try? JSONDecoder().decode(SyncConflictResponse.self, from: data)
            let currentVersion = conflict?.currentVersion ?? 0
            if retryEmptyRemoteConflict && currentVersion == 0 {
                syncLastVersion = 0
                return try await uploadSettingsToSyncServer(baseVersion: 0, retryEmptyRemoteConflict: false)
            }
            throw SyncServerError.conflict(currentVersion: currentVersion)
        default:
            throw SyncServerError.unexpectedStatus(statusCode)
        }
    }

    @MainActor
    func downloadSettingsFromSyncServer(overwriteExisting: Bool = true) async throws -> SyncSettingsState {
        let state = try await fetchSyncSettings()
        guard state.settings.version == "1.0" else {
            throw SettingsError.incompatibleVersion(state.settings.version)
        }

        try importSettings(state.settings, overwriteExisting: overwriteExisting)
        syncLastVersion = state.version
        return state
    }

    private func fetchSyncSettings() async throws -> SyncSettingsState {
        let request = try makeSyncRequest(path: "/v1/settings", method: "GET")
        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = try httpStatusCode(from: response)

        switch statusCode {
        case 200:
            return try decodeSyncState(from: data)
        case 401:
            throw SyncServerError.unauthorized
        case 404:
            syncLastVersion = 0
            throw SyncServerError.notFound
        default:
            throw SyncServerError.unexpectedStatus(statusCode)
        }
    }

    private func makeSyncRequest(path: String, method: String) throws -> URLRequest {
        let urlString = syncServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let token = syncServerToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !urlString.isEmpty, var components = URLComponents(string: urlString) else {
            throw SyncServerError.missingServerURL
        }
        guard !token.isEmpty else {
            throw SyncServerError.missingToken
        }

        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let basePath = components.path.isEmpty ? "" : "/\(components.path)"
        components.path = basePath + path

        guard let url = components.url, let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) else {
            throw SyncServerError.invalidServerURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func httpStatusCode(from response: URLResponse) throws -> Int {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncServerError.invalidResponse
        }
        return httpResponse.statusCode
    }

    private func decodeSyncState(from data: Data) throws -> SyncSettingsState {
        try syncJSONDecoder().decode(SyncSettingsState.self, from: data)
    }

    private func syncJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func syncJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
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
        settings.enabledSearchResultSources[SearchResultSource.calendar.rawValue] = enabled
        saveSettings()
    }

    func isSearchResultSourceEnabled(_ source: SearchResultSource) -> Bool {
        if source == .calendar {
            // Keep calendar in sync with the legacy flag used elsewhere.
            return settings.enabledSearchResultSources[source.rawValue]
                ?? settings.calendarSearchEnabled
        }
        return settings.enabledSearchResultSources[source.rawValue] ?? true
    }

    func updateSearchResultSource(_ source: SearchResultSource, enabled: Bool) {
        let currentlyEnabled = isSearchResultSourceEnabled(source)
        guard currentlyEnabled != enabled else { return }

        settings.enabledSearchResultSources[source.rawValue] = enabled
        if source == .calendar {
            settings.calendarSearchEnabled = enabled
        }
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

    func updateMirrorCameraDeviceID(_ deviceID: String) {
        guard settings.mirrorCameraDeviceID != deviceID else { return }

        settings.mirrorCameraDeviceID = deviceID
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

            if settings.mirrorCameraDeviceID.isEmpty {
                settings.mirrorCameraDeviceID = importedSettings.mirrorCameraDeviceID
            }

            // Main hotkey - only update if current is default
            if settings.mainHotkeyKeyCode == 49 && settings.mainHotkeyModifiers == 2048 {
                settings.mainHotkeyKeyCode = importedSettings.mainHotkeyKeyCode
                settings.mainHotkeyModifiers = importedSettings.mainHotkeyModifiers
            }

            if !settings.dictationEnabled {
                settings.dictationEnabled = importedSettings.dictationEnabled
            }

            if settings.dictationHotkey.isEmpty && !importedSettings.dictationHotkey.isEmpty {
                settings.dictationHotkey = importedSettings.dictationHotkey
                settings.dictationHotkeyKeyCode = importedSettings.dictationHotkeyKeyCode
                settings.dictationHotkeyModifiers = importedSettings.dictationHotkeyModifiers
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

enum SyncServerError: LocalizedError {
    case missingServerURL
    case invalidServerURL
    case missingToken
    case unauthorized
    case notFound
    case conflict(currentVersion: Int)
    case invalidResponse
    case unexpectedStatus(Int)

    var errorDescription: String? {
        switch self {
        case .missingServerURL:
            return "Enter a sync server URL."
        case .invalidServerURL:
            return "Enter a valid http or https sync server URL."
        case .missingToken:
            return "Enter the sync server token."
        case .unauthorized:
            return "The sync server rejected the token."
        case .notFound:
            return "No settings have been uploaded to this sync server yet."
        case .conflict(let currentVersion):
            return "Remote settings changed first. Download the remote settings before uploading. Current remote version: \(currentVersion)."
        case .invalidResponse:
            return "The sync server returned an invalid response."
        case .unexpectedStatus(let status):
            return "The sync server returned HTTP \(status)."
        }
    }
}
