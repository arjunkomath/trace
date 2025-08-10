//
//  AppHotkeysSettingsView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI
import Carbon

struct AppHotkeysSettingsView: View {
    @State private var searchQuery = ""
    @State private var apps: [Application] = []
    @State private var configuredHotkeys: [String: String] = [:]
    @State private var isLoading = true
    @ObservedObject private var services = ServiceContainer.shared
    
    var filteredApps: [Application] {
        if searchQuery.isEmpty {
            return apps.sorted { app1, app2 in
                let hasHotkey1 = configuredHotkeys[app1.bundleIdentifier] != nil
                let hasHotkey2 = configuredHotkeys[app2.bundleIdentifier] != nil
                
                if hasHotkey1 != hasHotkey2 {
                    return hasHotkey1 && !hasHotkey2
                } else {
                    return app1.displayName.localizedCaseInsensitiveCompare(app2.displayName) == .orderedAscending
                }
            }
        } else {
            return services.appSearchManager.searchApps(query: searchQuery, limit: 50)
        }
    }
    
    var body: some View {
        Form {
            Section {
                // Search Field
                HStack {
                    Image(systemName: "filemenu.and.selection")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    TextField("Search applications...", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                    
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                
                // Apps List
                if isLoading {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading applications...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    ForEach(filteredApps, id: \.bundleIdentifier) { app in
                        AppHotkeyRow(
                            app: app,
                            assignedHotkey: configuredHotkeys[app.bundleIdentifier] ?? ""
                        ) { hotkey, keyCode, modifiers in
                            updateHotkey(for: app, hotkey: hotkey, keyCode: keyCode, modifiers: modifiers)
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text("Application Hotkeys")
            } footer: {
                Text("Assign global keyboard shortcuts to launch your favorite applications instantly.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadApps()
            loadConfiguredHotkeys()
        }
    }
    
    private func loadApps() {
        Task { @MainActor in
            var allApps: [Application] = []
            let letters = "abcdefghijklmnopqrstuvwxyz"
            
            for letter in letters {
                let apps = services.appSearchManager.searchApps(query: String(letter), limit: 200)
                allApps.append(contentsOf: apps)
            }
            
            let uniqueApps = Array(Set(allApps)).sorted { app1, app2 in
                app1.displayName.localizedCaseInsensitiveCompare(app2.displayName) == .orderedAscending
            }
            
            self.apps = uniqueApps
            self.isLoading = false
        }
    }
    
    private func loadConfiguredHotkeys() {
        configuredHotkeys = services.appHotkeyManager.getAllConfiguredAppHotkeys()
    }
    
    private func updateHotkey(for app: Application, hotkey: String?, keyCode: UInt32, modifiers: UInt32) {
        services.appHotkeyManager.saveHotkey(
            for: app.bundleIdentifier,
            hotkey: hotkey,
            keyCode: keyCode,
            modifiers: modifiers
        )
        
        services.appHotkeyManager.updateHotkey(
            for: app.bundleIdentifier,
            keyCombo: hotkey,
            keyCode: keyCode,
            modifiers: modifiers
        )
        
        loadConfiguredHotkeys()
    }
}

struct AppHotkeyRow: View {
    let app: Application
    @State var assignedHotkey: String
    let onHotkeyChange: (String?, UInt32, UInt32) -> Void
    
    @State private var isRecordingHotkey = false
    @State private var eventMonitor: Any?
    @State private var appIcon: NSImage?
    
    var body: some View {
        HStack {
            // App icon and info
            HStack(spacing: 12) {
                Group {
                    if let icon = appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Image(systemName: "app")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.displayName)
                        .font(.system(size: 13, weight: .medium))
                    
                    Text(app.bundleIdentifier)
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
                        isRecordingHotkey = true
                        startRecording()
                    } else {
                        assignedHotkey = ""
                        onHotkeyChange(nil, 0, 0)
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
        .onAppear {
            loadAppIcon()
        }
        .onDisappear {
            stopRecording()
        }
    }
    
    private func loadAppIcon() {
        Task { @MainActor in
            let services = ServiceContainer.shared
            appIcon = await services.appSearchManager.getAppIcon(for: app)
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
                
                if modifierValue != 0 && event.keyCode != 53 {
                    let keyBinding = KeyBindingView(keyCode: UInt32(event.keyCode), modifiers: modifierValue)
                    self.assignedHotkey = keyBinding.keys.joined(separator: "")
                    self.onHotkeyChange(self.assignedHotkey, UInt32(event.keyCode), modifierValue)
                    self.isRecordingHotkey = false
                    self.stopRecording()
                    return nil
                }
                
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
