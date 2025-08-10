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
    @ObservedObject private var permissionManager = PermissionManager.shared
    @State private var isTestingCapability = false
    
    var body: some View {
        Form {
            // Permission Status Section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Window Management")
                            .font(.system(size: 13))
                        Text("Control windows of other applications")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(permissionManager.windowManagementAvailable ? "Available" : "Test Access") {
                        testWindowManagementAccess()
                    }
                    .buttonStyle(.automatic)
                    .disabled(isTestingCapability)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Permissions")
            } footer: {
                Text("Window management will be tested when you first use it. No setup required for most operations.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            // Window Management Commands List
            Section {
                ForEach(Array(WindowPosition.allCases.enumerated()), id: \.offset) { index, position in
                    WindowCommandRow(position: position)
                        .padding(.vertical, 2)
                }
            } header: {
                Text("Window Hotkeys")
            } footer: {
                Text("Assign keyboard shortcuts to window management commands. Permissions will be requested when first used.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Refresh capability when app becomes active
            testWindowManagementAccessSilently()
        }
    }
    
    private func testWindowManagementAccess() {
        isTestingCapability = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.permissionManager.testWindowManagementCapability()
            
            DispatchQueue.main.async {
                self.isTestingCapability = false
                
                switch result {
                case .available:
                    self.permissionManager.windowManagementAvailable = true
                    
                case .permissionDenied:
                    self.permissionManager.windowManagementAvailable = false
                    self.permissionManager.requestWindowManagementPermissions()
                    
                case .noTargetApp, .noWindows:
                    // These states mean permissions are granted but no suitable target
                    self.permissionManager.windowManagementAvailable = true
                }
            }
        }
    }
    
    private func testWindowManagementAccessSilently() {
        DispatchQueue.global(qos: .background).async {
            let result = self.permissionManager.testWindowManagementCapability()
            
            DispatchQueue.main.async {
                switch result {
                case .available, .noTargetApp, .noWindows:
                    self.permissionManager.windowManagementAvailable = true
                case .permissionDenied:
                    self.permissionManager.windowManagementAvailable = false
                }
            }
        }
    }
}

struct WindowCommandRow: View {
    let position: WindowPosition
    @State private var isRecordingHotkey = false
    @State private var assignedHotkey: String = ""
    @State private var eventMonitor: Any?
    
    var body: some View {
        HStack {
            // Window position icon and info
            HStack(spacing: 12) {
                Image(systemName: getWindowIcon(for: position))
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
                            .foregroundColor(.blue)
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
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .onAppear {
            loadHotkey()
        }
        .onDisappear {
            stopRecording()
        }
    }
    
    private func loadHotkey() {
        assignedHotkey = UserDefaults.standard.string(forKey: "window_\(position.rawValue)_hotkey") ?? ""
    }
    
    private func saveHotkey(_ hotkey: String, keyCode: UInt32, modifiers: UInt32) {
        print("🔧 saveHotkey called for \(position.rawValue): '\(hotkey)', keyCode: \(keyCode), modifiers: \(modifiers)")
        
        if hotkey.isEmpty {
            UserDefaults.standard.removeObject(forKey: "window_\(position.rawValue)_hotkey")
            UserDefaults.standard.removeObject(forKey: "window_\(position.rawValue)_keycode")
            UserDefaults.standard.removeObject(forKey: "window_\(position.rawValue)_modifiers")
            print("🗑️ Cleared hotkey for \(position.rawValue)")
            // Update the hotkey manager
            WindowHotkeyManager.shared.updateHotkey(for: position, keyCombo: nil, keyCode: 0, modifiers: 0)
        } else {
            UserDefaults.standard.set(hotkey, forKey: "window_\(position.rawValue)_hotkey")
            UserDefaults.standard.set(Int(keyCode), forKey: "window_\(position.rawValue)_keycode")
            UserDefaults.standard.set(Int(modifiers), forKey: "window_\(position.rawValue)_modifiers")
            print("💾 Saved hotkey for \(position.rawValue): keyCode=\(keyCode), modifiers=\(modifiers)")
            // Update the hotkey manager
            WindowHotkeyManager.shared.updateHotkey(for: position, keyCombo: hotkey, keyCode: keyCode, modifiers: modifiers)
        }
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
    
    private func getWindowIcon(for position: WindowPosition) -> String {
        switch position {
        case .leftHalf: return "rectangle.split.2x1"
        case .rightHalf: return "rectangle.split.2x1"
        case .centerHalf: return "rectangle.center.inset.filled"
        case .topHalf: return "rectangle.split.1x2"
        case .bottomHalf: return "rectangle.split.1x2"
        case .topLeft, .topRight, .bottomLeft, .bottomRight: return "rectangle.split.2x2"
        case .firstThird, .centerThird, .lastThird: return "rectangle.split.3x1"
        case .firstTwoThirds, .lastTwoThirds: return "rectangle.split.3x1"
        case .maximize: return "arrow.up.left.and.arrow.down.right"
        case .fullScreen: return "rectangle.fill"
        case .almostMaximize: return "macwindow"
        case .maximizeHeight: return "arrow.up.and.down"
        case .smaller: return "minus.rectangle"
        case .larger: return "plus.rectangle"
        case .center: return "target"
        case .centerProminently: return "viewfinder"
        }
    }
}