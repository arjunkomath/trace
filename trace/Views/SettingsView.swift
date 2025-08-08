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
    private let logger = AppLogger.settingsView
    
    @AppStorage("hotkey_keyCode") private var savedKeyCode: Int = 49
    @AppStorage("hotkey_modifiers") private var savedModifiers: Int = Int(optionKey)
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    
    @State private var isRecording = false
    @State private var currentKeyCombo = "⌥Space"
    @State private var selectedTab = 0
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(
                launchAtLogin: $launchAtLogin,
                currentKeyCombo: $currentKeyCombo,
                isRecording: $isRecording,
                onLaunchAtLoginChange: toggleLaunchAtLogin,
                onHotkeyRecord: { keyCode, modifiers in
                    savedKeyCode = Int(keyCode)
                    savedModifiers = Int(modifiers)
                    updateHotkey()
                    currentKeyCombo = formatKeyCombo(keyCode: keyCode, modifiers: modifiers)
                },
                onHotkeyReset: {
                    savedKeyCode = 49
                    savedModifiers = Int(optionKey)
                    currentKeyCombo = "⌥Space"
                    updateHotkey()
                }
            )
            .tabItem {
                Image(systemName: "gearshape")
                Text("General")
            }
            .tag(0)
            
            WindowManagementSettingsView()
                .tabItem {
                    Image(systemName: "macwindow")
                    Text("Window Management")
                }
                .tag(1)
            
            AboutSettingsView()
                .tabItem {
                    Image(systemName: "info.circle")
                    Text("About")
                }
                .tag(2)
        }
        .frame(width: AppConstants.Window.settingsWidth, height: AppConstants.Window.settingsHeight)
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
            logger.error("Failed to \(enable ? "enable" : "disable") launch at login: \(error.localizedDescription)")
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
                try appDelegate.updateHotkey(keyCode: UInt32(savedKeyCode), modifiers: UInt32(savedModifiers))
            } catch {
                logger.error("Failed to update hotkey: \(error.localizedDescription)")
            }
        }
    }
    
    func formatKeyCombo(keyCode: UInt32, modifiers: UInt32) -> String {
        let keyView = KeyBindingView(keyCode: keyCode, modifiers: modifiers)
        return keyView.keys.joined(separator: "")
    }
}

// MARK: - Tab Views

struct GeneralSettingsView: View {
    @Binding var launchAtLogin: Bool
    @Binding var currentKeyCombo: String
    @Binding var isRecording: Bool
    let onLaunchAtLoginChange: (Bool) -> Void
    let onHotkeyRecord: (UInt32, UInt32) -> Void
    let onHotkeyReset: () -> Void
    
    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Launch at Login")
                            .font(.system(size: 13))
                        Text("Start Trace when you log in to your Mac")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: launchAtLogin) { _, newValue in
                            onLaunchAtLoginChange(newValue)
                        }
                }
                .padding(.vertical, 4)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quick Launch")
                            .font(.system(size: 13))
                        Text("Keyboard shortcut to open Trace")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HotkeyRecorderView(
                        keyCombo: $currentKeyCombo,
                        isRecording: $isRecording,
                        onRecord: onHotkeyRecord
                    )
                }
                .padding(.vertical, 4)
                
                if currentKeyCombo != "⌥Space" {
                    HStack {
                        Spacer()
                        Button("Reset to Default") {
                            onHotkeyReset()
                        }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // App Icon and Info
            VStack(spacing: 16) {
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 64, height: 64)
                } else {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue.gradient)
                }
                
                VStack(spacing: 8) {
                    Text("Trace")
                        .font(.system(size: 24, weight: .semibold))
                    
                    Text("Version 1.0.0")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Text("System-wide search and app launcher for macOS")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            Spacer()
            
            // Developer Info and Links
            VStack(spacing: 16) {
                Text("Created by Arjun Komath")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                HStack(spacing: 20) {
                    Link("GitHub", destination: URL(string: "https://github.com/arjunkomath/trace")!)
                        .font(.system(size: 12))
                    
                    Link("Twitter", destination: URL(string: "https://twitter.com/arjunz")!)
                        .font(.system(size: 12))
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct WindowManagementSettingsView: View {
    @State private var accessibilityEnabled = false
    @State private var showingAccessibilityAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            if !accessibilityEnabled {
                // Accessibility Permission Warning
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    
                    Text("Accessibility Permissions Required")
                        .font(.system(size: 16, weight: .semibold))
                    
                    Text("Window management requires accessibility permissions to control other applications' windows.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    
                    Button("Grant Permissions") {
                        WindowManager.shared.requestAccessibilityPermissions()
                        showingAccessibilityAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
                .padding()
                
                Spacer()
            } else {
                // Window Management Commands List
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(WindowPosition.allCases.enumerated()), id: \.offset) { index, position in
                            WindowCommandRow(position: position)
                        }
                    }
                    .padding()
                }
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            checkAccessibilityPermissions()
        }
        .alert("Accessibility Permissions", isPresented: $showingAccessibilityAlert) {
            Button("OK") {
                checkAccessibilityPermissions()
            }
        } message: {
            Text("Please enable accessibility permissions for Trace in System Preferences > Security & Privacy > Accessibility, then restart the app.")
        }
    }
    
    private func checkAccessibilityPermissions() {
        accessibilityEnabled = WindowManager.shared.hasAccessibilityPermissions()
    }
}

struct WindowCommandRow: View {
    let position: WindowPosition
    @State private var isRecordingHotkey = false
    @State private var assignedHotkey: String = ""
    
    var body: some View {
        HStack {
            // Window position icon and info
            HStack(spacing: 12) {
                Image(systemName: getWindowIcon(for: position))
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
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
                if assignedHotkey.isEmpty {
                    // Start recording hotkey
                    isRecordingHotkey = true
                } else {
                    // Clear hotkey
                    assignedHotkey = ""
                    // TODO: Save to UserDefaults
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .onAppear {
            loadHotkey()
        }
    }
    
    private func loadHotkey() {
        // TODO: Load from UserDefaults
        assignedHotkey = UserDefaults.standard.string(forKey: "window_\(position.rawValue)_hotkey") ?? ""
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
        case .almostMaximize: return "macwindow"
        case .maximizeHeight: return "arrow.up.and.down"
        case .smaller: return "minus.rectangle"
        case .larger: return "plus.rectangle"
        case .center: return "target"
        case .centerProminently: return "viewfinder"
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
                if isRecording {
                    Text("Press keys...")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.blue)
                } else {
                    KeyBindingView(keyCombo: keyCombo)
                }
                
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
        .onDisappear {
            stopRecording()
        }
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

