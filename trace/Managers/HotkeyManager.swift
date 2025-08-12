//
//  HotkeyManager.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import Foundation

/// Simplified HotkeyManager that uses the unified HotkeyRegistry
class HotkeyManager {
    private let logger = AppLogger.hotkeyManager
    private var registeredHotkeyId: UInt32?
    
    var onHotkeyPressed: (() -> Void)?
    
    init() {
        logger.notice("🚀 HotkeyManager initializing with unified registry...")
    }
    
    deinit {
        unregisterHotkey()
        logger.notice("🧹 HotkeyManager deinitialized")
    }
    
    func registerHotkey(keyCode: UInt32, modifiers: UInt32) throws {
        logger.notice("📝 Registering main app hotkey: keyCode=\(keyCode), modifiers=\(modifiers)")
        
        // Unregister existing hotkey if any
        unregisterHotkey()
        
        guard keyCode > 0 else {
            logger.error("❌ Invalid keyCode: \(keyCode)")
            throw HotkeyError.invalidParameters
        }
        
        // Register through the unified registry
        guard let hotkeyId = HotkeyRegistry.shared.registerHotkey(
            keyCode: keyCode,
            modifiers: modifiers,
            type: .appLauncher,
            action: { [weak self] in
                self?.onHotkeyPressed?()
            }
        ) else {
            logger.error("❌ Failed to register hotkey through registry")
            throw HotkeyError.registrationFailed(-1)
        }
        
        registeredHotkeyId = hotkeyId
        logger.notice("✅ Main app hotkey registered with ID: \(hotkeyId)")
    }
    
    func unregisterHotkey() {
        if let hotkeyId = registeredHotkeyId {
            logger.notice("🗑️ Unregistering main app hotkey ID: \(hotkeyId)")
            HotkeyRegistry.shared.unregisterHotkey(id: hotkeyId)
            registeredHotkeyId = nil
        }
    }
}

// Keep the existing error types for compatibility
enum HotkeyError: Error {
    case registrationFailed(OSStatus)
    case eventHandlerInstallFailed(OSStatus)
    case invalidParameters
}
