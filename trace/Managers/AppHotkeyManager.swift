//
//  AppHotkeyManager.swift
//  trace
//
//  Created by Arjun on 8/9/2025.
//

import Foundation
import os.log

class AppHotkeyManager {
    static let shared = AppHotkeyManager()
    private let logger = Logger(subsystem: "com.trace.app", category: "AppHotkeyManager")
    private let settingsManager = SettingsManager.shared
    
    private var bundleIdToHotkeyId: [String: UInt32] = [:]
    
    private init() {
        logger.info("🚀 AppHotkeyManager initializing...")
        setupHotkeys()
    }
    
    deinit {
        logger.info("🧹 AppHotkeyManager deinitializing...")
    }
    
    func setupHotkeys() {
        logger.info("📋 Loading saved app hotkeys...")
        
        let savedHotkeys = settingsManager.settings.appHotkeys
        for (bundleId, hotkeyData) in savedHotkeys {
            if hotkeyData.keyCode != 0 {
                registerHotkey(for: bundleId, keyCode: UInt32(hotkeyData.keyCode), modifiers: UInt32(hotkeyData.modifiers))
            }
        }
        
        logger.info("✅ Finished loading app hotkeys. Total registered: \(self.bundleIdToHotkeyId.count)")
    }
    
    func updateHotkey(for bundleId: String, keyCombo: String?, keyCode: UInt32, modifiers: UInt32) {
        logger.info("🔄 Updating app hotkey for \(bundleId): '\(keyCombo ?? "nil")'")
        
        unregisterHotkey(for: bundleId)
        
        if let keyCombo = keyCombo, !keyCombo.isEmpty && keyCode != 0 {
            registerHotkey(for: bundleId, keyCode: keyCode, modifiers: modifiers)
            // Save to settings
            settingsManager.updateAppHotkey(for: bundleId, hotkey: keyCombo, keyCode: Int(keyCode), modifiers: Int(modifiers))
        } else {
            // Remove from settings
            settingsManager.removeAppHotkey(for: bundleId)
        }
    }
    
    private func registerHotkey(for bundleId: String, keyCode: UInt32, modifiers: UInt32) {
        guard let hotkeyId = HotkeyRegistry.shared.registerHotkey(
            keyCode: keyCode,
            modifiers: modifiers,
            type: .applicationLauncher(bundleId),
            action: { [weak self] in
                self?.logger.info("🎯 App hotkey pressed for \(bundleId)")
                Task { @MainActor in
                    self?.launchApp(bundleId: bundleId)
                }
            }
        ) else {
            logger.error("❌ Failed to register app hotkey for \(bundleId) through registry")
            return
        }
        
        bundleIdToHotkeyId[bundleId] = hotkeyId
        logger.info("✅ Registered app hotkey for \(bundleId) with ID \(hotkeyId)")
    }
    
    private func unregisterHotkey(for bundleId: String) {
        if let hotkeyId = bundleIdToHotkeyId[bundleId] {
            logger.info("🗑️ Unregistering app hotkey ID \(hotkeyId) for \(bundleId)")
            HotkeyRegistry.shared.unregisterHotkey(id: hotkeyId)
            bundleIdToHotkeyId.removeValue(forKey: bundleId)
        }
    }
    
    @MainActor
    private func launchApp(bundleId: String) {
        let services = ServiceContainer.shared
        if let app = services.appSearchManager.getApp(by: bundleId) {
            logger.info("🚀 Launching app: \(app.displayName) (\(bundleId))")
            services.appSearchManager.launchApp(app)
            
            // Track usage
            services.usageTracker.recordUsage(for: bundleId)
        } else {
            logger.warning("⚠️ App not found for bundle ID: \(bundleId)")
        }
    }
    
    // MARK: - Settings Management
    
    func getHotkey(for bundleId: String) -> String? {
        return settingsManager.getAppHotkey(for: bundleId)?.hotkey
    }
    
    func saveHotkey(for bundleId: String, hotkey: String?, keyCode: UInt32, modifiers: UInt32) {
        if let hotkey = hotkey, !hotkey.isEmpty {
            settingsManager.updateAppHotkey(for: bundleId, hotkey: hotkey, keyCode: Int(keyCode), modifiers: Int(modifiers))
            logger.info("💾 Saved app hotkey for \(bundleId): \(hotkey)")
        } else {
            settingsManager.removeAppHotkey(for: bundleId)
            logger.info("🗑️ Cleared app hotkey for \(bundleId)")
        }
    }
    
    func getAllConfiguredAppHotkeys() -> [String: String] {
        return settingsManager.getAllAppHotkeys()
    }
}