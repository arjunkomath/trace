//
//  QuickLinksManager.swift
//  trace
//
//  Created by Claude on 13/8/2025.
//

import Foundation
import AppKit
import os

class QuickLinksManager: ObservableObject {
    private let logger = AppLogger.quickLinksManager
    private let settingsManager = SettingsManager.shared
    
    @Published var quickLinks: [QuickLink] = []
    
    init() {
        loadQuickLinks()
    }
    
    // MARK: - Public Methods
    
    func loadQuickLinks() {
        let loadedQuickLinks = settingsManager.settings.quickLinks.map { quickLinkData in
            QuickLink(
                id: quickLinkData.id,
                name: quickLinkData.name,
                urlString: quickLinkData.urlString,
                iconName: quickLinkData.iconName,
                keywords: quickLinkData.keywords,
                hotkey: settingsManager.getQuickLinkHotkey(for: quickLinkData.id),
                isSystemDefault: quickLinkData.isSystemDefault
            )
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.quickLinks = loadedQuickLinks
            
            // Always ensure we have system default folders
            if !self.hasSystemDefaultQuickLinks {
                self.addDefaultQuickLinks()
                self.hasLoadedBefore = true
            }
        }
    }
    
    func saveQuickLinks() {
        // Convert to data format for settings
        let quickLinkData = quickLinks.map { quickLink in
            TraceSettings.QuickLinkData(
                id: quickLink.id,
                name: quickLink.name,
                urlString: quickLink.urlString,
                iconName: quickLink.iconName,
                keywords: quickLink.keywords,
                isSystemDefault: quickLink.isSystemDefault
            )
        }
        
        // Clear existing quick links and add new ones
        settingsManager.settings.quickLinks = quickLinkData
        
        // Save hotkeys to settings
        for quickLink in quickLinks where quickLink.hotkey != nil {
            settingsManager.updateQuickLinkHotkey(for: quickLink.id, hotkey: quickLink.hotkey)
        }
        
        logger.info("Saved \(self.quickLinks.count) quick links")
    }
    
    func addQuickLink(_ quickLink: QuickLink) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.quickLinks.append(quickLink)
        }
        
        let quickLinkData = TraceSettings.QuickLinkData(
            id: quickLink.id,
            name: quickLink.name,
            urlString: quickLink.urlString,
            iconName: quickLink.iconName,
            keywords: quickLink.keywords,
            isSystemDefault: quickLink.isSystemDefault
        )
        
        settingsManager.addQuickLink(quickLinkData)
        
        if let hotkey = quickLink.hotkey {
            settingsManager.updateQuickLinkHotkey(for: quickLink.id, hotkey: hotkey)
        }
        
        logger.info("Added quick link: \(quickLink.name)")
    }
    
    func updateQuickLink(_ quickLink: QuickLink) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let index = self.quickLinks.firstIndex(where: { $0.id == quickLink.id }) {
                self.quickLinks[index] = quickLink
            }
        }
        
        let quickLinkData = TraceSettings.QuickLinkData(
            id: quickLink.id,
            name: quickLink.name,
            urlString: quickLink.urlString,
            iconName: quickLink.iconName,
            keywords: quickLink.keywords,
            isSystemDefault: quickLink.isSystemDefault
        )
        
        settingsManager.updateQuickLink(quickLinkData)
        settingsManager.updateQuickLinkHotkey(for: quickLink.id, hotkey: quickLink.hotkey)
        
        logger.info("Updated quick link: \(quickLink.name)")
    }
    
    func removeQuickLink(_ quickLink: QuickLink) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.quickLinks.removeAll { $0.id == quickLink.id }
        }
        
        settingsManager.removeQuickLink(withId: quickLink.id)
        logger.info("Removed quick link: \(quickLink.name)")
    }
    
    func searchQuickLinks(query: String) -> [QuickLink] {
        guard !query.isEmpty else { return quickLinks }
        
        let queryLower = query.lowercased()
        
        return quickLinks.filter { quickLink in
            // Search in name, keywords, and URL
            let searchableTerms = quickLink.searchableTerms
            return searchableTerms.contains { term in
                term.contains(queryLower)
            }
        }.sorted { quickLink1, quickLink2 in
            // Prioritize exact name matches, then contains matches
            let name1Lower = quickLink1.name.lowercased()
            let name2Lower = quickLink2.name.lowercased()
            
            if name1Lower == queryLower && name2Lower != queryLower {
                return true
            } else if name1Lower != queryLower && name2Lower == queryLower {
                return false
            } else if name1Lower.hasPrefix(queryLower) && !name2Lower.hasPrefix(queryLower) {
                return true
            } else if !name1Lower.hasPrefix(queryLower) && name2Lower.hasPrefix(queryLower) {
                return false
            } else {
                return name1Lower < name2Lower
            }
        }
    }
    
    func openQuickLink(_ quickLink: QuickLink) {
        guard let url = quickLink.url else {
            logger.error("Invalid URL for quick link: \(quickLink.name)")
            return
        }
        
        logger.info("Opening quick link: \(quickLink.name) -> \(url.absoluteString)")
        
        if quickLink.isFileLink {
            // For file links, check if file exists first
            if FileManager.default.fileExists(atPath: url.path) {
                NSWorkspace.shared.open(url)
            } else {
                logger.error("File does not exist: \(url.path)")
                // Could show toast notification here
            }
        } else {
            // For web links, open directly
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Private Methods
    
    private var hasLoadedBefore: Bool {
        get {
            settingsManager.settings.quickLinksHasLoadedBefore
        }
        set {
            settingsManager.updateQuickLinksHasLoadedBefore(newValue)
        }
    }
    
    private var hasSystemDefaultQuickLinks: Bool {
        return quickLinks.contains { $0.isSystemDefault }
    }
    
    private func addDefaultQuickLinks() {
        logger.info("Adding default quick links")
        
        for defaultQuickLink in QuickLink.defaultQuickLinks {
            // Only add if it doesn't already exist
            if !quickLinks.contains(where: { $0.id == defaultQuickLink.id }) {
                addQuickLink(defaultQuickLink)
            }
        }
    }
}