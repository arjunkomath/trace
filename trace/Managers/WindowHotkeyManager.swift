import Foundation
import os.log

/// Clean window hotkey service using the unified HotkeyRegistry
class WindowHotkeyManager {
    static let shared = WindowHotkeyManager()
    private let logger = Logger(subsystem: "com.trace.app", category: "WindowHotkeyManager")
    
    // Track registered hotkey IDs for each position
    private var positionToHotkeyId: [WindowPosition: UInt32] = [:]
    
    private init() {
        logger.info("🚀 WindowHotkeyManager initializing with unified registry...")
        setupHotkeys()
    }
    
    deinit {
        logger.info("🧹 WindowHotkeyManager deinitializing...")
        // Cleanup is handled by HotkeyRegistry
    }
    
    func setupHotkeys() {
        logger.info("📋 Loading saved window management hotkeys...")
        
        // Load and register all saved window management hotkeys
        for position in WindowPosition.allCases {
            if let savedHotkey = UserDefaults.standard.string(forKey: "window_\(position.rawValue)_hotkey"),
               !savedHotkey.isEmpty {
                let keyCode = UInt32(UserDefaults.standard.integer(forKey: "window_\(position.rawValue)_keycode"))
                let modifiers = UInt32(UserDefaults.standard.integer(forKey: "window_\(position.rawValue)_modifiers"))
                logger.info("📖 Found saved hotkey for \(position.rawValue): '\(savedHotkey)' (keyCode: \(keyCode), modifiers: \(modifiers))")
                
                if keyCode != 0 {
                    registerHotkey(for: position, keyCode: keyCode, modifiers: modifiers)
                } else {
                    logger.warning("⚠️ Invalid keyCode (0) for \(position.rawValue), skipping")
                }
            } else {
                logger.debug("📝 No saved hotkey found for \(position.rawValue)")
            }
        }
        
        logger.info("✅ Finished loading window management hotkeys. Total registered: \(self.positionToHotkeyId.count)")
    }
    
    func updateHotkey(for position: WindowPosition, keyCombo: String?, keyCode: UInt32, modifiers: UInt32) {
        logger.info("🔄 Updating hotkey for \(position.rawValue): '\(keyCombo ?? "nil")'")
        
        // Unregister existing hotkey if any
        unregisterHotkey(for: position)
        
        // Register new hotkey if provided
        if let keyCombo = keyCombo, !keyCombo.isEmpty && keyCode != 0 {
            registerHotkey(for: position, keyCode: keyCode, modifiers: modifiers)
        }
    }
    
    private func registerHotkey(for position: WindowPosition, keyCode: UInt32, modifiers: UInt32) {
        // Register through the unified registry
        guard let hotkeyId = HotkeyRegistry.shared.registerHotkey(
            keyCode: keyCode,
            modifiers: modifiers,
            type: .windowManagement(position),
            action: { [weak self] in
                self?.logger.info("🎯 Window management hotkey pressed for \(position.rawValue)")
                WindowManager.shared.applyWindowPosition(position)
            }
        ) else {
            logger.error("❌ Failed to register hotkey for \(position.rawValue) through registry")
            return
        }
        
        positionToHotkeyId[position] = hotkeyId
        logger.info("✅ Registered hotkey for \(position.rawValue) with ID \(hotkeyId)")
    }
    
    private func unregisterHotkey(for position: WindowPosition) {
        if let hotkeyId = positionToHotkeyId[position] {
            logger.info("🗑️ Unregistering hotkey ID \(hotkeyId) for \(position.rawValue)")
            HotkeyRegistry.shared.unregisterHotkey(id: hotkeyId)
            positionToHotkeyId.removeValue(forKey: position)
        }
    }
}