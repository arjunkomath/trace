//
//  SettingsView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI
import ServiceManagement
import Carbon

struct SettingsView: View {
    @State private var launchAtLogin: Bool = false
    @State private var currentKeyCombo: String = "⌥Space"
    @State private var isRecording: Bool = false
    
    private let logger = AppLogger.settingsView
    
    var body: some View {
        TabView {
            GeneralSettingsView(
                launchAtLogin: $launchAtLogin,
                currentKeyCombo: $currentKeyCombo,
                isRecording: $isRecording,
                onLaunchAtLoginChange: handleLaunchAtLoginChange,
                onHotkeyRecord: handleHotkeyRecord,
                onHotkeyReset: handleHotkeyReset
            )
            .tabItem {
                Image(systemName: "gear")
                Text("General")
            }
            .tag(0)
            
            WindowManagementSettingsView()
                .tabItem {
                    Image(systemName: "macwindow")
                    Text("Window Hotkeys")
                }
                .tag(1)
            
            PermissionsSettingsView()
                .tabItem {
                    Image(systemName: "lock.shield")
                    Text("Permissions")
                }
                .tag(2)
            
            AppHotkeysSettingsView()
                .tabItem {
                    Image(systemName: "app.badge")
                    Text("App Hotkeys")
                }
                .tag(3)
            
            AboutSettingsView()
                .tabItem {
                    Image(systemName: "info.circle")
                    Text("About")
                }
                .tag(4)
        }
        .frame(width: AppConstants.Window.settingsWidth, height: AppConstants.Window.settingsHeight)
        .onAppear {
            logger.debug("Settings view appeared")
            loadSettings()
            
            // Force the settings window to the front
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                if let settingsWindow = NSApp.windows.first(where: { $0.title.contains("Settings") || $0.title.contains("Preferences") }) {
                    settingsWindow.makeKeyAndOrderFront(nil)
                    settingsWindow.orderFrontRegardless()
                }
            }
        }
    }
    
    private func loadSettings() {
        // Load launch at login status
        launchAtLogin = SMAppService.mainApp.status == .enabled
        
        // Load current hotkey combo
        let keyCode = UserDefaults.standard.integer(forKey: "hotkey_keyCode")
        let modifiers = UserDefaults.standard.integer(forKey: "hotkey_modifiers")
        
        if keyCode != 0 {
            let keyBinding = KeyBindingView(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers))
            currentKeyCombo = keyBinding.keys.joined(separator: "")
        } else {
            currentKeyCombo = "⌥Space"
        }
    }
    
    private func handleLaunchAtLoginChange(_ enabled: Bool) {
        logger.info("Launch at login changed to: \(enabled)")
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Failed to update launch at login: \(error)")
        }
    }
    
    private func handleHotkeyRecord(_ keyCode: UInt32, _ modifiers: UInt32) {
        logger.info("Recording hotkey: keyCode=\(keyCode), modifiers=\(modifiers)")
        
        // Save to UserDefaults
        UserDefaults.standard.set(Int(keyCode), forKey: "hotkey_keyCode")
        UserDefaults.standard.set(Int(modifiers), forKey: "hotkey_modifiers")
        
        // Update the hotkey manager
        if let appDelegate = NSApp.delegate as? AppDelegate {
            do {
                try appDelegate.updateHotkey(keyCode: keyCode, modifiers: modifiers)
            } catch {
                logger.error("Failed to update hotkey: \(error)")
            }
        }
        
        isRecording = false
    }
    
    private func handleHotkeyReset() {
        logger.info("Resetting hotkey to default")
        
        // Reset to default (Option+Space)
        let defaultKeyCode: UInt32 = 49 // Space key
        let defaultModifiers: UInt32 = UInt32(optionKey)
        
        UserDefaults.standard.set(Int(defaultKeyCode), forKey: "hotkey_keyCode")
        UserDefaults.standard.set(Int(defaultModifiers), forKey: "hotkey_modifiers")
        
        currentKeyCombo = "⌥Space"
        
        // Update the hotkey manager
        if let appDelegate = NSApp.delegate as? AppDelegate {
            do {
                try appDelegate.updateHotkey(keyCode: defaultKeyCode, modifiers: defaultModifiers)
            } catch {
                logger.error("Failed to reset hotkey: \(error)")
            }
        }
    }
    
    func formatKeyCombo(keyCode: UInt32, modifiers: UInt32) -> String {
        let keyView = KeyBindingView(keyCode: keyCode, modifiers: modifiers)
        return keyView.keys.joined(separator: "")
    }
    
    func restartApp() {
        let bundlePath = Bundle.main.bundlePath
        
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [bundlePath]
        
        do {
            try task.run()
            logger.info("Restarting Trace from: \(bundlePath)")
            
            // Give the new instance a moment to start before terminating
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.terminateWithoutConfirmation()
                } else {
                    NSApp.terminate(nil)
                }
            }
        } catch {
            logger.error("Failed to restart Trace: \(error.localizedDescription)")
        }
    }
}