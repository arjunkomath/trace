import Foundation
import Carbon
import AppKit
import os.log

// MARK: - Hotkey Types

enum HotkeyType: Hashable {
    case appLauncher
    case windowManagement(WindowPosition)
    case applicationLauncher(String) // for future use
    case quickLink(String) // QuickLink ID
    
    var description: String {
        switch self {
        case .appLauncher:
            return "App Launcher"
        case .windowManagement(let position):
            return "Window: \(position.rawValue)"
        case .applicationLauncher(let bundleId):
            return "App: \(bundleId)"
        case .quickLink(let id):
            return "QuickLink: \(id)"
        }
    }
}

// MARK: - Hotkey Registration

struct HotkeyRegistration {
    let id: UInt32
    let keyCode: UInt32
    let modifiers: UInt32
    let type: HotkeyType
    let action: () -> Void
    let eventHotkey: EventHotKeyRef
    
    var signature: String {
        return "\(keyCode):\(modifiers)"
    }
}

// MARK: - Hotkey Registry

class HotkeyRegistry {
    static let shared = HotkeyRegistry()
    private let logger = AppLogger.hotkeyRegistry
    
    private var registrations: [UInt32: HotkeyRegistration] = [:]
    private var signatureToId: [String: UInt32] = [:] // For conflict detection
    private var eventHandler: EventHandlerUPP?
    private var eventHandlerRef: EventHandlerRef?
    private var nextHotkeyID: UInt32 = 1
    
    private init() {
        logger.notice("🏗️ HotkeyRegistry initializing...")
        installGlobalEventHandler()
    }
    
    deinit {
        logger.notice("🧹 HotkeyRegistry deinitializing...")
        cleanup()
    }
    
    // MARK: - Public API
    
    /// Register a new hotkey
    /// - Returns: Hotkey ID if successful, nil if failed or conflict exists
    func registerHotkey(
        keyCode: UInt32,
        modifiers: UInt32,
        type: HotkeyType,
        action: @escaping () -> Void
    ) -> UInt32? {
        let signature = "\(keyCode):\(modifiers)"
        
        // Check for conflicts
        if let existingId = signatureToId[signature] {
            if let existing = registrations[existingId] {
                logger.warning("⚠️ Hotkey conflict: \(signature) already registered for \(existing.type.description)")
                return nil
            }
        }
        
        let hotkeyID = nextHotkeyID
        nextHotkeyID += 1
        
        let eventHotkeyID = EventHotKeyID(signature: OSType(0x54524345), id: hotkeyID) // 'TRCE'
        
        var eventHotkey: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            eventHotkeyID,
            GetApplicationEventTarget(),
            0,
            &eventHotkey
        )
        
        guard status == noErr, let hotkey = eventHotkey else {
            logger.error("❌ Failed to register hotkey \(signature) for \(type.description): status=\(status)")
            return nil
        }
        
        let registration = HotkeyRegistration(
            id: hotkeyID,
            keyCode: keyCode,
            modifiers: modifiers,
            type: type,
            action: action,
            eventHotkey: hotkey
        )
        
        registrations[hotkeyID] = registration
        signatureToId[signature] = hotkeyID
        
        logger.notice("✅ Registered hotkey \(signature) with ID \(hotkeyID) for \(type.description)")
        
        return hotkeyID
    }
    
    /// Unregister a hotkey by ID
    func unregisterHotkey(id: UInt32) {
        guard let registration = registrations[id] else {
            logger.warning("⚠️ Attempted to unregister non-existent hotkey ID \(id)")
            return
        }
        
        UnregisterEventHotKey(registration.eventHotkey)
        signatureToId.removeValue(forKey: registration.signature)
        registrations.removeValue(forKey: id)
        
        logger.notice("🗑️ Unregistered hotkey ID \(id) for \(registration.type.description)")
    }
    
    /// Update an existing hotkey with new key combination
    func updateHotkey(id: UInt32, keyCode: UInt32, modifiers: UInt32) -> Bool {
        guard let oldRegistration = registrations[id] else {
            logger.warning("⚠️ Attempted to update non-existent hotkey ID \(id)")
            return false
        }
        
        // Unregister the old hotkey
        unregisterHotkey(id: id)
        
        // Register with the same type and action but new key combination
        let newId = registerHotkey(
            keyCode: keyCode,
            modifiers: modifiers,
            type: oldRegistration.type,
            action: oldRegistration.action
        )
        
        return newId != nil
    }
    
    /// Get all registered hotkeys
    func getAllRegistrations() -> [HotkeyRegistration] {
        return Array(registrations.values)
    }
    
    /// Check if a key combination is already registered
    func isHotkeyRegistered(keyCode: UInt32, modifiers: UInt32) -> Bool {
        let signature = "\(keyCode):\(modifiers)"
        return signatureToId[signature] != nil
    }
    
    
    // MARK: - Private Implementation
    
    private func installGlobalEventHandler() {
        logger.notice("🔧 Installing global event handler...")
        
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        eventHandler = { (nextHandler, event, userData) -> OSStatus in
            let registry = HotkeyRegistry.shared
            
            var hotkeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotkeyID
            )
            
            guard status == noErr else {
                registry.logger.error("❌ Failed to get hotkey ID from event: status=\(status)")
                return noErr
            }
            
            // Find and execute the action
            if let registration = registry.registrations[hotkeyID.id] {
                DispatchQueue.main.async {
                    registration.action()
                }
            }
            
            return noErr
        }
        
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            eventHandler,
            1,
            &eventSpec,
            nil,
            &eventHandlerRef
        )
        
        if installStatus == noErr {
            logger.notice("✅ Global event handler installed successfully")
        } else {
            logger.error("❌ Failed to install global event handler: status=\(installStatus)")
        }
    }
    
    private func cleanup() {
        // Unregister all hotkeys
        for registration in registrations.values {
            UnregisterEventHotKey(registration.eventHotkey)
        }
        registrations.removeAll()
        signatureToId.removeAll()
        
        // Remove event handler
        if let handlerRef = eventHandlerRef {
            RemoveEventHandler(handlerRef)
            eventHandlerRef = nil
        }
        
        logger.notice("✅ HotkeyRegistry cleanup completed")
    }
}

