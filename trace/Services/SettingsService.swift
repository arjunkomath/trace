//
//  SettingsService.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import Foundation
import Carbon

protocol SettingsServiceProtocol {
    var hotkeyKeyCode: UInt32 { get set }
    var hotkeyModifiers: UInt32 { get set }
    var launchAtLogin: Bool { get set }
    var hasCompletedOnboarding: Bool { get set }
}

final class SettingsService: SettingsServiceProtocol {
    private let logger = AppLogger.settingsService
    private let userDefaults: UserDefaults
    
    // MARK: - Keys
    private enum Keys {
        static let hotkeyKeyCode = "hotkey_keyCode"
        static let hotkeyModifiers = "hotkey_modifiers"
        static let launchAtLogin = "launchAtLogin"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }
    
    // MARK: - Defaults
    private enum Defaults {
        static let hotkeyKeyCode: UInt32 = 49 // Space key
        static let hotkeyModifiers: UInt32 = UInt32(optionKey)
        static let launchAtLogin: Bool = false
        static let hasCompletedOnboarding: Bool = false
    }
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        registerDefaults()
    }
    
    private func registerDefaults() {
        userDefaults.register(defaults: [
            Keys.hotkeyKeyCode: Int(Defaults.hotkeyKeyCode),
            Keys.hotkeyModifiers: Int(Defaults.hotkeyModifiers),
            Keys.launchAtLogin: Defaults.launchAtLogin,
            Keys.hasCompletedOnboarding: Defaults.hasCompletedOnboarding
        ])
    }
    
    // MARK: - Properties
    
    var hotkeyKeyCode: UInt32 {
        get {
            let value = userDefaults.integer(forKey: Keys.hotkeyKeyCode)
            return value > 0 ? UInt32(value) : Defaults.hotkeyKeyCode
        }
        set {
            userDefaults.set(Int(newValue), forKey: Keys.hotkeyKeyCode)
            logger.debug("Updated hotkey key code to \(newValue)")
        }
    }
    
    var hotkeyModifiers: UInt32 {
        get {
            let value = userDefaults.integer(forKey: Keys.hotkeyModifiers)
            return value > 0 ? UInt32(value) : Defaults.hotkeyModifiers
        }
        set {
            userDefaults.set(Int(newValue), forKey: Keys.hotkeyModifiers)
            logger.debug("Updated hotkey modifiers to \(newValue)")
        }
    }
    
    var launchAtLogin: Bool {
        get {
            userDefaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.launchAtLogin)
            logger.debug("Updated launch at login to \(newValue)")
        }
    }
    
    var hasCompletedOnboarding: Bool {
        get {
            userDefaults.bool(forKey: Keys.hasCompletedOnboarding)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.hasCompletedOnboarding)
            logger.debug("Updated onboarding completion to \(newValue)")
        }
    }
}