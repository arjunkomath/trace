//
//  FolderManager.swift
//  trace
//
//  Created by Assistant on 8/10/2025.
//

import Foundation
import AppKit
import os

class FolderManager: ObservableObject {
    private let logger = Logger(subsystem: "com.trace.app", category: "FolderManager")
    private let settingsManager = SettingsManager.shared
    
    @Published var customFolders: [FolderShortcut] = []
    @Published var allFolders: [FolderShortcut] = []
    
    init() {
        loadFolders()
    }
    
    // MARK: - Public Methods
    
    func loadFolders() {
        // Load custom folders from settings
        customFolders = settingsManager.settings.customFolders.map { folderData in
            FolderShortcut(
                id: folderData.id,
                name: folderData.name,
                path: folderData.path,
                isDefault: folderData.isDefault,
                hotkey: settingsManager.getFolderHotkey(for: folderData.id)
            )
        }
        
        // Load default folders with hotkeys from settings
        var defaultFoldersWithHotkeys = FolderShortcut.defaultFolders
        for i in 0..<defaultFoldersWithHotkeys.count {
            if let hotkey = settingsManager.getFolderHotkey(for: defaultFoldersWithHotkeys[i].id) {
                defaultFoldersWithHotkeys[i].hotkey = hotkey
            }
        }
        
        // Combine default and custom folders
        allFolders = defaultFoldersWithHotkeys + customFolders
    }
    
    func saveFolders() {
        // Save custom folders to settings
        let customFolderData = customFolders.map { folder in
            TraceSettings.CustomFolderData(
                id: folder.id,
                name: folder.name,
                path: folder.path,
                isDefault: folder.isDefault
            )
        }
        
        // Clear existing custom folders and add new ones
        settingsManager.settings.customFolders = customFolderData
        
        // Save folder hotkeys to settings
        for folder in allFolders where folder.hotkey != nil {
            settingsManager.updateFolderHotkey(for: folder.id, hotkey: folder.hotkey)
        }
        
        // Reload to update allFolders
        loadFolders()
    }
    
    func addCustomFolder(_ folder: FolderShortcut) {
        customFolders.append(folder)
        let folderData = TraceSettings.CustomFolderData(
            id: folder.id,
            name: folder.name,
            path: folder.path,
            isDefault: folder.isDefault
        )
        settingsManager.addCustomFolder(folderData)
        
        if let hotkey = folder.hotkey {
            settingsManager.updateFolderHotkey(for: folder.id, hotkey: hotkey)
        }
        
        loadFolders() // Reload instead of saveFolders to avoid double-save
    }
    
    func updateFolder(_ folder: FolderShortcut) {
        if folder.isDefault {
            // Update hotkey for default folder
            if let index = allFolders.firstIndex(where: { $0.id == folder.id }) {
                allFolders[index].hotkey = folder.hotkey
            }
            settingsManager.updateFolderHotkey(for: folder.id, hotkey: folder.hotkey)
        } else {
            // Update custom folder
            if let index = customFolders.firstIndex(where: { $0.id == folder.id }) {
                customFolders[index] = folder
            }
            let folderData = TraceSettings.CustomFolderData(
                id: folder.id,
                name: folder.name,
                path: folder.path,
                isDefault: folder.isDefault
            )
            settingsManager.updateCustomFolder(folderData)
            
            if let hotkey = folder.hotkey {
                settingsManager.updateFolderHotkey(for: folder.id, hotkey: hotkey)
            }
        }
        loadFolders()
    }
    
    func removeCustomFolder(_ folder: FolderShortcut) {
        guard !folder.isDefault else { return }
        customFolders.removeAll { $0.id == folder.id }
        settingsManager.removeCustomFolder(withId: folder.id)
        settingsManager.updateFolderHotkey(for: folder.id, hotkey: nil) // Remove hotkey
        loadFolders()
    }
    
    func openFolder(_ folder: FolderShortcut) {
        guard let url = folder.url else {
            logger.error("Failed to get URL for folder: \(folder.name)")
            return
        }
        
        guard folder.exists else {
            logger.error("Folder does not exist: \(folder.path)")
            showFolderNotFoundAlert(for: folder)
            return
        }
        
        NSWorkspace.shared.open(url)
        logger.info("Opened folder: \(folder.name) at \(url.path)")
    }
    
    func searchFolders(query: String) -> [FolderShortcut] {
        let lowercasedQuery = query.lowercased()
        
        return allFolders.filter { folder in
            folder.exists && (
                folder.name.lowercased().contains(lowercasedQuery) ||
                folder.path.lowercased().contains(lowercasedQuery)
            )
        }.sorted { folder1, folder2 in
            // Prioritize exact name matches
            let name1Match = folder1.name.lowercased() == lowercasedQuery
            let name2Match = folder2.name.lowercased() == lowercasedQuery
            
            if name1Match != name2Match {
                return name1Match
            }
            
            // Then prioritize starts with
            let name1Starts = folder1.name.lowercased().hasPrefix(lowercasedQuery)
            let name2Starts = folder2.name.lowercased().hasPrefix(lowercasedQuery)
            
            if name1Starts != name2Starts {
                return name1Starts
            }
            
            // Default folders come first
            if folder1.isDefault != folder2.isDefault {
                return folder1.isDefault
            }
            
            return folder1.name < folder2.name
        }
    }
    
    func getHotkey(for folderId: String) -> String? {
        return settingsManager.getFolderHotkey(for: folderId)
    }
    
    func setHotkey(_ hotkey: String?, for folderId: String) {
        settingsManager.updateFolderHotkey(for: folderId, hotkey: hotkey)
        
        // Update local state
        if let index = allFolders.firstIndex(where: { $0.id == folderId }) {
            allFolders[index].hotkey = hotkey
        }
        
        if let customIndex = customFolders.firstIndex(where: { $0.id == folderId }) {
            customFolders[customIndex].hotkey = hotkey
        }
    }
    
    // MARK: - Private Methods
    
    private func showFolderNotFoundAlert(for folder: FolderShortcut) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Folder Not Found"
            alert.informativeText = "The folder '\(folder.name)' at path '\(folder.path)' could not be found."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            
            if !folder.isDefault {
                alert.addButton(withTitle: "Remove from List")
            }
            
            let response = alert.runModal()
            if response == .alertSecondButtonReturn && !folder.isDefault {
                self.removeCustomFolder(folder)
            }
        }
    }
    
    // Check for special folders that might be available
    func checkSpecialFolders() -> [FolderShortcut] {
        var specialFolders: [FolderShortcut] = []
        
        // Check for Developer folder
        let developerPath = NSString(string: "~/Developer").expandingTildeInPath
        if FileManager.default.fileExists(atPath: developerPath) {
            specialFolders.append(FolderShortcut(
                id: "developer",
                name: "Developer",
                path: "~/Developer",
                isDefault: true
            ))
        }
        
        // Check for iCloud Drive
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            let iCloudDrivePath = iCloudURL.deletingLastPathComponent().appendingPathComponent("Documents").path
            if FileManager.default.fileExists(atPath: iCloudDrivePath) {
                specialFolders.append(FolderShortcut(
                    id: "icloud",
                    name: "iCloud Drive",
                    path: iCloudDrivePath,
                    isDefault: true
                ))
            }
        }
        
        return specialFolders
    }
}