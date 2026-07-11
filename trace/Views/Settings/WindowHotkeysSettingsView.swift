//
//  WindowHotkeysSettingsView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI
import Carbon
import ApplicationServices

struct WindowManagementSettingsView: View {
    var body: some View {
        NativeSettingsPane {
            NativeSettingsSection("Window Hotkeys") {
                ForEach(Array(WindowPosition.allCases.enumerated()), id: \.offset) { index, position in
                    WindowCommandRow(position: position)
                    
                    if index < WindowPosition.allCases.count - 1 {
                        NativeSettingsDivider()
                    }
                }
            } footer: {
                Text("Assign keyboard shortcuts to window management commands. Permissions will be requested when first used.")
            }
        }
    }
}

struct WindowCommandRow: View {
    let position: WindowPosition
    @State private var isRecordingHotkey = false
    @State private var assignedHotkey: String = ""
    @State private var eventMonitor: Any?
    @Environment(\.traceTheme) private var traceTheme
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: position.icon)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(position.displayName)
                        .font(.system(size: 13, weight: .medium))
                    
                    Text(position.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Hotkey assignment
            Button(action: {
                if assignedHotkey.isEmpty || !isRecordingHotkey {
                    if assignedHotkey.isEmpty {
                        // Start recording hotkey
                        isRecordingHotkey = true
                        startRecording()
                    } else {
                        // Clear hotkey
                        assignedHotkey = ""
                        saveHotkey("", keyCode: 0, modifiers: 0)
                    }
                }
            }) {
                HStack(spacing: 8) {
                    if isRecordingHotkey {
                        Text("Press keys...")
                            .font(.system(size: 11))
                            .foregroundColor(traceTheme.accentForeground)
                    } else if assignedHotkey.isEmpty {
                        Text("Set Hotkey")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        KeyBindingView(keyCombo: assignedHotkey, size: .small)
                        
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: 54)
        .onAppear {
            loadHotkey()
        }
        .onDisappear {
            stopRecording()
        }
    }
    
    private func loadHotkey() {
        assignedHotkey = WindowHotkeyManager.shared.getHotkey(for: position) ?? ""
    }
    
    private func saveHotkey(_ hotkey: String, keyCode: UInt32, modifiers: UInt32) {
        // Use WindowHotkeyManager which now saves to SettingsManager
        WindowHotkeyManager.shared.updateHotkey(for: position, keyCombo: hotkey.isEmpty ? nil : hotkey, keyCode: keyCode, modifiers: modifiers)
    }
    
    private func startRecording() {
        stopRecording()
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if self.isRecordingHotkey {
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                var modifierValue: UInt32 = 0
                
                if modifiers.contains(.command) { modifierValue |= UInt32(cmdKey) }
                if modifiers.contains(.option) { modifierValue |= UInt32(optionKey) }
                if modifiers.contains(.control) { modifierValue |= UInt32(controlKey) }
                if modifiers.contains(.shift) { modifierValue |= UInt32(shiftKey) }
                
                // Only accept if at least one modifier is pressed (except for Escape)
                if modifierValue != 0 && event.keyCode != 53 {
                    // Format the key combination
                    let keyBinding = KeyBindingView(keyCode: UInt32(event.keyCode), modifiers: modifierValue)
                    self.assignedHotkey = keyBinding.keys.joined(separator: "")
                    self.saveHotkey(self.assignedHotkey, keyCode: UInt32(event.keyCode), modifiers: modifierValue)
                    self.isRecordingHotkey = false
                    self.stopRecording()
                    return nil
                }
                
                // Cancel on Escape
                if event.keyCode == 53 {
                    self.isRecordingHotkey = false
                    self.stopRecording()
                    return nil
                }
            }
            return event
        }
    }
    
    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
