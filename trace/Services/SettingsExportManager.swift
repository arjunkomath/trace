//
//  SettingsExportManager.swift
//  trace
//
//  Created by Claude on 8/10/2025.
//
// DEPRECATED: This file is now legacy. Use SettingsManager.shared for all settings operations.

import Foundation
import os.log

// Legacy class for compatibility - all functionality moved to SettingsManager
class SettingsExportManager: ObservableObject {
    static let shared = SettingsExportManager()
    private let settingsManager = SettingsManager.shared
    
    private init() {}
    
    // MARK: - Export Settings (Delegates to SettingsManager)
    
    func exportToFile() throws -> URL {
        return try settingsManager.exportToFile()
    }
    
    func importFromFile(_ fileURL: URL, overwriteExisting: Bool = false) throws {
        return try settingsManager.importFromFile(fileURL, overwriteExisting: overwriteExisting)
    }
}