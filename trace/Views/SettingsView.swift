//
//  SettingsView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI
import Carbon
import ServiceManagement

struct SettingsView: View {
    @AppStorage("hotkey_keyCode") private var savedKeyCode: Int = 49
    @AppStorage("hotkey_modifiers") private var savedModifiers: Int = Int(optionKey)
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    
    @State private var isRecording = false
    @State private var currentKeyCombo = "⌥Space"
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Bar
            VStack(spacing: 4) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue.gradient)
                    .padding(.top, 20)
                
                Text("Trace")
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.bottom, 4)
                
                Text("Version 1.0.0")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            }
            
            Divider()
            
            // Settings Content
            ScrollView {
                VStack(spacing: 24) {
                    // General Section
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "General", icon: "gearshape")
                        
                        SettingRow(
                            title: "Launch at Login",
                            subtitle: "Start Trace when you log in to your Mac",
                            icon: "power"
                        ) {
                            Toggle("", isOn: $launchAtLogin)
                                .toggleStyle(SwitchToggleStyle())
                                .labelsHidden()
                                .onChange(of: launchAtLogin) { _, newValue in
                                    toggleLaunchAtLogin(newValue)
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Hotkey Section
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Hotkey", icon: "keyboard")
                        
                        SettingRow(
                            title: "Quick Launch",
                            subtitle: "Keyboard shortcut to open Trace",
                            icon: "command"
                        ) {
                            HotkeyRecorderView(
                                keyCombo: $currentKeyCombo,
                                isRecording: $isRecording,
                                onRecord: { keyCode, modifiers in
                                    savedKeyCode = Int(keyCode)
                                    savedModifiers = Int(modifiers)
                                    updateHotkey()
                                    currentKeyCombo = formatKeyCombo(keyCode: keyCode, modifiers: modifiers)
                                }
                            )
                        }
                        
                        if currentKeyCombo != "⌥Space" {
                            Button(action: {
                                savedKeyCode = 49
                                savedModifiers = Int(optionKey)
                                currentKeyCombo = "⌥Space"
                                updateHotkey()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 10))
                                    Text("Reset to Default")
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 36)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // About Section
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "About", icon: "info.circle")
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Created by")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text("Arjun Komath")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .padding(.leading, 36)
                            
                            HStack(spacing: 16) {
                                Link(destination: URL(string: "https://github.com/arjunkomath/trace")!) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "link")
                                            .font(.system(size: 10))
                                        Text("GitHub")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(.blue)
                                }
                                
                                Link(destination: URL(string: "https://twitter.com/arjunz")!) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "link")
                                            .font(.system(size: 10))
                                        Text("Twitter")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(.blue)
                                }
                            }
                            .padding(.leading, 36)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .padding(.top, 20)
            }
        }
        .frame(width: 450, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            currentKeyCombo = formatKeyCombo(keyCode: UInt32(savedKeyCode), modifiers: UInt32(savedModifiers))
            checkLaunchAtLoginStatus()
        }
    }
    
    func toggleLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to \(enable ? "enable" : "disable") launch at login: \(error)")
            // Revert the toggle if it failed
            launchAtLogin = !enable
        }
    }
    
    func checkLaunchAtLoginStatus() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
    
    func updateHotkey() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            do {
                try appDelegate.hotkeyManager.registerHotkey(keyCode: UInt32(savedKeyCode), modifiers: UInt32(savedModifiers))
            } catch {
                NSLog("Failed to update hotkey: %@", error.localizedDescription)
            }
        }
    }
    
    func formatKeyCombo(keyCode: UInt32, modifiers: UInt32) -> String {
        var keys: [String] = []
        
        if modifiers & UInt32(controlKey) != 0 { keys.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { keys.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { keys.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { keys.append("⌘") }
        
        keys.append(keyCodeToString(keyCode))
        
        return keys.joined()
    }
    
    func keyCodeToString(_ keyCode: UInt32) -> String {
        switch keyCode {
        case 49: return "Space"
        case 36: return "Return"
        case 48: return "Tab"
        case 53: return "Escape"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 0: return "A"
        case 11: return "B"
        case 8: return "C"
        case 2: return "D"
        case 14: return "E"
        case 3: return "F"
        case 5: return "G"
        case 4: return "H"
        case 34: return "I"
        case 38: return "J"
        case 40: return "K"
        case 37: return "L"
        case 46: return "M"
        case 45: return "N"
        case 31: return "O"
        case 35: return "P"
        case 12: return "Q"
        case 15: return "R"
        case 1: return "S"
        case 17: return "T"
        case 32: return "U"
        case 9: return "V"
        case 13: return "W"
        case 7: return "X"
        case 16: return "Y"
        case 6: return "Z"
        case 18...29: return String(keyCode - 18 + 1)
        case 29: return "0"
        default: return "Key\(keyCode)"
        }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let content: () -> Content
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            content()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

struct HotkeyRecorderView: View {
    @Binding var keyCombo: String
    @Binding var isRecording: Bool
    let onRecord: (UInt32, UInt32) -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @State private var eventMonitor: Any?
    
    var body: some View {
        Button(action: {
            isRecording.toggle()
            if isRecording {
                startRecording()
            } else {
                stopRecording()
            }
        }) {
            HStack {
                Text(isRecording ? "Press keys..." : keyCombo)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(isRecording ? .blue : .primary)
                
                if !isRecording {
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(width: 140)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isRecording ? Color.blue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    func startRecording() {
        stopRecording()
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if self.isRecording {
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                var modifierValue: UInt32 = 0
                
                if modifiers.contains(.command) { modifierValue |= UInt32(cmdKey) }
                if modifiers.contains(.option) { modifierValue |= UInt32(optionKey) }
                if modifiers.contains(.control) { modifierValue |= UInt32(controlKey) }
                if modifiers.contains(.shift) { modifierValue |= UInt32(shiftKey) }
                
                if modifierValue != 0 && event.keyCode != 53 {
                    self.onRecord(UInt32(event.keyCode), modifierValue)
                    self.isRecording = false
                    self.stopRecording()
                    return nil
                }
                
                if event.keyCode == 53 {
                    self.isRecording = false
                    self.stopRecording()
                    return nil
                }
            }
            return event
        }
    }
    
    func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

