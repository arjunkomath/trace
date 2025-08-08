//
//  HotkeyManager.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import Carbon
import Cocoa

enum HotkeyError: Error {
    case registrationFailed(OSStatus)
    case eventHandlerInstallFailed(OSStatus)
    case invalidParameters
}

class HotkeyManager {
    private let logger = AppLogger.hotkeyManager
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let signature = OSType("TRAC".fourCharCodeValue)
    private let hotKeyID = EventHotKeyID(signature: OSType("TRAC".fourCharCodeValue), id: 1)
    
    var onHotkeyPressed: (() -> Void)?
    
    init() {
        setupEventHandler()
    }
    
    deinit {
        unregisterHotkey()
        if let handler = eventHandler {
            let status = RemoveEventHandler(handler)
            if status != noErr {
                logger.error("Failed to remove event handler: \(status)")
            }
            eventHandler = nil
        }
    }
    
    private func setupEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event = event,
                  let userData = userData else { 
                return OSStatus(eventNotHandledErr) 
            }
            
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if status == noErr {
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.onHotkeyPressed?()
                }
            }
            
            return noErr
        }
        
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        
        if status != noErr {
            logger.error("Failed to install event handler: \(status)")
        }
    }
    
    func registerHotkey(keyCode: UInt32, modifiers: UInt32) throws {
        unregisterHotkey()
        
        guard keyCode > 0 else {
            throw HotkeyError.invalidParameters
        }
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status != noErr {
            logger.error("Failed to register hotkey (keyCode: \(keyCode), modifiers: \(modifiers)): \(status)")
            throw HotkeyError.registrationFailed(status)
        }
    }
    
    func unregisterHotkey() {
        if let ref = hotKeyRef {
            let status = UnregisterEventHotKey(ref)
            if status != noErr {
                logger.error("Failed to unregister hotkey: \(status)")
            }
            hotKeyRef = nil
        }
    }
}

extension String {
    var fourCharCodeValue: UInt32 {
        var result: UInt32 = 0
        for char in self.utf8 {
            result = (result << 8) + UInt32(char)
        }
        return result
    }
}
