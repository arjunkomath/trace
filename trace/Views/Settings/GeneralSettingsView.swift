//
//  GeneralSettingsView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI
import Carbon

struct GeneralSettingsView: View {
    @Binding var launchAtLogin: Bool
    @Binding var currentKeyCombo: String
    @Binding var isRecording: Bool
    @AppStorage("resultsLayout") private var resultsLayout: ResultsLayout = .compact
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon: Bool = true
    @State private var eventMonitor: Any?
    @State private var showingRestartAlert = false
    let onLaunchAtLoginChange: (Bool) -> Void
    let onHotkeyRecord: (UInt32, UInt32) -> Void
    let onHotkeyReset: () -> Void
    
    var body: some View {
        Form {
            // Startup section
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
            } header: {
                Text("Startup")
            }
            
            // Hotkey section
            Section {
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Quick Launch")
                                .font(.system(size: 13))
                            Text("Keyboard shortcut to open Trace")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            if !isRecording {
                                isRecording = true
                                startRecording()
                            }
                        }) {
                            HStack(spacing: 8) {
                                if isRecording {
                                    Text("Press keys...")
                                        .font(.system(size: 11))
                                        .foregroundColor(.blue)
                                } else {
                                    KeyBindingView(keyCombo: currentKeyCombo, size: .small)
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
                    
                    if currentKeyCombo != "⌥Space" {
                        HStack {
                            Spacer()
                            Button("Reset to Default") {
                                onHotkeyReset()
                                showingRestartAlert = true
                            }
                            .buttonStyle(.link)
                            .font(.system(size: 11))
                        }
                    }
                }
            } header: {
                Text("Hotkey")
            }
            
            // Interface section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Results Layout")
                            .font(.system(size: 13))
                        Text("Choose how search results are displayed")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Picker("", selection: $resultsLayout) {
                        ForEach(ResultsLayout.allCases, id: \.self) { layout in
                            Text(layout.displayName).tag(layout)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                }
                .padding(.vertical, 4)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show Menu Bar Icon")
                            .font(.system(size: 13))
                        Text("Display Trace icon in the menu bar")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $showMenuBarIcon)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                .padding(.vertical, 4)
            } header: {
                Text("Interface")
            }
        }
        .formStyle(.grouped)
        .onDisappear {
            stopRecording()
        }
        .alert("Restart Required", isPresented: $showingRestartAlert) {
            Button("Restart Now") {
                restartApp()
            }
            Button("Later", role: .cancel) { }
        } message: {
            Text("The global hotkey change requires restarting Trace to take effect.")
        }
    }
    
    private func startRecording() {
        stopRecording()
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if isRecording {
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                var modifierValue: UInt32 = 0
                
                if modifiers.contains(.command) { modifierValue |= UInt32(cmdKey) }
                if modifiers.contains(.option) { modifierValue |= UInt32(optionKey) }
                if modifiers.contains(.control) { modifierValue |= UInt32(controlKey) }
                if modifiers.contains(.shift) { modifierValue |= UInt32(shiftKey) }
                
                // Only accept if at least one modifier is pressed (except for Escape)
                if modifierValue != 0 && event.keyCode != 53 {
                    // Format the key combination and update binding
                    let keyBinding = KeyBindingView(keyCode: UInt32(event.keyCode), modifiers: modifierValue)
                    currentKeyCombo = keyBinding.keys.joined(separator: "")
                    onHotkeyRecord(UInt32(event.keyCode), modifierValue)
                    isRecording = false
                    stopRecording()
                    
                    // Show restart alert after hotkey change
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingRestartAlert = true
                    }
                    
                    return nil
                }
                
                // Cancel on Escape
                if event.keyCode == 53 {
                    isRecording = false
                    stopRecording()
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
    
    private func restartApp() {
        let bundlePath = Bundle.main.bundlePath
        
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [bundlePath]
        
        do {
            try task.run()
            
            // Give the new instance a moment to start before terminating
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.terminateWithoutConfirmation()
                } else {
                    NSApp.terminate(nil)
                }
            }
        } catch {
            // If restart fails, just continue running
            print("Failed to restart app: \(error)")
        }
    }
}
