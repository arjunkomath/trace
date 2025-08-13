//
//  QuickLinkHotkeyManager.swift
//  trace
//
//  Created by Claude on 13/8/2025.
//

import Foundation
import AppKit
import os.log

class QuickLinkHotkeyManager {
    static let shared = QuickLinkHotkeyManager()
    private let logger = AppLogger.quickLinkHotkeyManager
    private let settingsManager = SettingsManager.shared
    
    private var quickLinkIdToHotkeyId: [String: UInt32] = [:]
    
    private init() {
        logger.info("🚀 QuickLinkHotkeyManager initializing...")
        setupHotkeys()
    }
    
    deinit {
        logger.info("🧹 QuickLinkHotkeyManager deinitializing...")
        unregisterAllHotkeys()
    }
    
    func setupHotkeys() {
        logger.info("📋 Loading saved QuickLink hotkeys...")
        
        let quickLinks = settingsManager.settings.quickLinks
        for quickLink in quickLinks {
            if let hotkey = quickLink.hotkey, !hotkey.isEmpty && quickLink.keyCode != 0 {
                registerHotkey(for: quickLink.id, keyCode: UInt32(quickLink.keyCode), modifiers: UInt32(quickLink.modifiers))
            }
        }
        
        logger.info("✅ Finished loading QuickLink hotkeys. Total registered: \(self.quickLinkIdToHotkeyId.count)")
    }
    
    func updateHotkey(for quickLinkId: String, keyCombo: String?, keyCode: UInt32, modifiers: UInt32) {
        logger.info("🔄 Updating QuickLink hotkey for \(quickLinkId): '\(keyCombo ?? "nil")'")
        
        unregisterHotkey(for: quickLinkId)
        
        if let keyCombo = keyCombo, !keyCombo.isEmpty && keyCode != 0 {
            registerHotkey(for: quickLinkId, keyCode: keyCode, modifiers: modifiers)
        }
    }
    
    private func registerHotkey(for quickLinkId: String, keyCode: UInt32, modifiers: UInt32) {
        guard let hotkeyId = HotkeyRegistry.shared.registerHotkey(
            keyCode: keyCode,
            modifiers: modifiers,
            type: .quickLink(quickLinkId),
            action: { [weak self] in
                self?.logger.info("🎯 QuickLink hotkey pressed for \(quickLinkId)")
                Task { @MainActor in
                    self?.executeQuickLink(quickLinkId: quickLinkId)
                }
            }
        ) else {
            logger.error("❌ Failed to register QuickLink hotkey for \(quickLinkId) through registry")
            return
        }
        
        quickLinkIdToHotkeyId[quickLinkId] = hotkeyId
        logger.info("✅ Registered QuickLink hotkey for \(quickLinkId) with ID \(hotkeyId)")
    }
    
    private func unregisterHotkey(for quickLinkId: String) {
        if let hotkeyId = quickLinkIdToHotkeyId[quickLinkId] {
            logger.info("🗑️ Unregistering QuickLink hotkey ID \(hotkeyId) for \(quickLinkId)")
            HotkeyRegistry.shared.unregisterHotkey(id: hotkeyId)
            quickLinkIdToHotkeyId.removeValue(forKey: quickLinkId)
        }
    }
    
    private func unregisterAllHotkeys() {
        for (quickLinkId, hotkeyId) in quickLinkIdToHotkeyId {
            logger.info("🗑️ Unregistering QuickLink hotkey ID \(hotkeyId) for \(quickLinkId)")
            HotkeyRegistry.shared.unregisterHotkey(id: hotkeyId)
        }
        quickLinkIdToHotkeyId.removeAll()
    }
    
    private func executeQuickLink(quickLinkId: String) {
        // Find the QuickLink data from settings
        guard let quickLinkData = settingsManager.settings.quickLinks.first(where: { $0.id == quickLinkId }) else {
            logger.error("❌ QuickLink with ID \(quickLinkId) not found")
            return
        }
        
        logger.info("🚀 Executing QuickLink: \(quickLinkData.name)")
        
        // Create a temporary QuickLink object to use its URL parsing
        let quickLink = QuickLink(
            id: quickLinkData.id,
            name: quickLinkData.name,
            urlString: quickLinkData.urlString,
            iconName: quickLinkData.iconName,
            keywords: quickLinkData.keywords,
            hotkey: quickLinkData.hotkey,
            keyCode: quickLinkData.keyCode,
            modifiers: quickLinkData.modifiers,
            isSystemDefault: quickLinkData.isSystemDefault
        )
        
        guard let url = quickLink.url else {
            logger.error("❌ Invalid URL for QuickLink: \(quickLinkData.name)")
            return
        }
        
        // Open the URL
        NSWorkspace.shared.open(url)
    }
}
