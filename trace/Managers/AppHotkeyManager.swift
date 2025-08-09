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
        
        let savedHotkeys = getAllSavedAppHotkeys()
        for (bundleId, hotkeyData) in savedHotkeys {
            if hotkeyData.keyCode != 0 {
                registerHotkey(for: bundleId, keyCode: hotkeyData.keyCode, modifiers: hotkeyData.modifiers)
            }
        }
        
        logger.info("✅ Finished loading app hotkeys. Total registered: \(self.bundleIdToHotkeyId.count)")
    }
    
    func updateHotkey(for bundleId: String, keyCombo: String?, keyCode: UInt32, modifiers: UInt32) {
        logger.info("🔄 Updating app hotkey for \(bundleId): '\(keyCombo ?? "nil")'")
        
        unregisterHotkey(for: bundleId)
        
        if let keyCombo = keyCombo, !keyCombo.isEmpty && keyCode != 0 {
            registerHotkey(for: bundleId, keyCode: keyCode, modifiers: modifiers)
        }
    }
    
    private func registerHotkey(for bundleId: String, keyCode: UInt32, modifiers: UInt32) {
        guard let hotkeyId = HotkeyRegistry.shared.registerHotkey(
            keyCode: keyCode,
            modifiers: modifiers,
            type: .applicationLauncher(bundleId),
            action: { [weak self] in
                self?.logger.info("🎯 App hotkey pressed for \(bundleId)")
                self?.launchApp(bundleId: bundleId)
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
    
    private func launchApp(bundleId: String) {
        if let app = AppSearchManager.shared.getApp(by: bundleId) {
            logger.info("🚀 Launching app: \(app.displayName) (\(bundleId))")
            AppSearchManager.shared.launchApp(app)
            
            // Track usage
            UsageTracker.shared.recordUsage(for: bundleId)
        } else {
            logger.warning("⚠️ App not found for bundle ID: \(bundleId)")
        }
    }
    
    // MARK: - UserDefaults Management
    
    private func getAllSavedAppHotkeys() -> [String: (keyCode: UInt32, modifiers: UInt32, hotkey: String)] {
        var result: [String: (keyCode: UInt32, modifiers: UInt32, hotkey: String)] = [:]
        
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        for key in allKeys {
            if key.hasPrefix("app_") && key.hasSuffix("_hotkey") {
                let bundleId = String(key.dropFirst(4).dropLast(7)) // Remove "app_" and "_hotkey"
                
                if let hotkeyString = userDefaults.string(forKey: key), !hotkeyString.isEmpty {
                    let keyCode = UInt32(userDefaults.integer(forKey: "app_\(bundleId)_keycode"))
                    let modifiers = UInt32(userDefaults.integer(forKey: "app_\(bundleId)_modifiers"))
                    
                    result[bundleId] = (keyCode: keyCode, modifiers: modifiers, hotkey: hotkeyString)
                }
            }
        }
        
        return result
    }
    
    func getHotkey(for bundleId: String) -> String? {
        return UserDefaults.standard.string(forKey: "app_\(bundleId)_hotkey")
    }
    
    func saveHotkey(for bundleId: String, hotkey: String?, keyCode: UInt32, modifiers: UInt32) {
        let userDefaults = UserDefaults.standard
        
        if let hotkey = hotkey, !hotkey.isEmpty {
            userDefaults.set(hotkey, forKey: "app_\(bundleId)_hotkey")
            userDefaults.set(Int(keyCode), forKey: "app_\(bundleId)_keycode")
            userDefaults.set(Int(modifiers), forKey: "app_\(bundleId)_modifiers")
            logger.info("💾 Saved app hotkey for \(bundleId): \(hotkey)")
        } else {
            userDefaults.removeObject(forKey: "app_\(bundleId)_hotkey")
            userDefaults.removeObject(forKey: "app_\(bundleId)_keycode")
            userDefaults.removeObject(forKey: "app_\(bundleId)_modifiers")
            logger.info("🗑️ Cleared app hotkey for \(bundleId)")
        }
    }
    
    func getAllConfiguredAppHotkeys() -> [String: String] {
        var result: [String: String] = [:]
        let savedHotkeys = getAllSavedAppHotkeys()
        
        for (bundleId, hotkeyData) in savedHotkeys {
            result[bundleId] = hotkeyData.hotkey
        }
        
        return result
    }
}