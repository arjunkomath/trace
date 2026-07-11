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
    @State private var resultsLayout: ResultsLayout = .compact
    @State private var showMenuBarIcon: Bool = true
    @State private var accentColor: TraceAccent = .system
    @State private var hoveredAccent: TraceAccent?
    @State private var eventMonitor: Any?
    @State private var showingRestartAlert = false
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.traceTheme) private var traceTheme
    
    @ObservedObject private var permissionManager = PermissionManager.shared
    @State private var calendarEnabled = false
    @State private var requestingCalendarPermission = false
    let onLaunchAtLoginChange: (Bool) -> Void
    let onHotkeyRecord: (UInt32, UInt32) -> Void
    let onHotkeyReset: () -> Void
    
    var body: some View {
        NativeSettingsPane {
            NativeSettingsSection("Hotkey") {
                VStack(spacing: 8) {
                    NativeSettingsRow(
                        title: "Quick Launch",
                        subtitle: "Keyboard shortcut to open Trace"
                    ) {
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
                                        .foregroundColor(traceTheme.accentForeground)
                                } else {
                                    KeyBindingView(keyCombo: currentKeyCombo, size: .small)
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if currentKeyCombo != "⌥Space" {
                        NativeSettingsDivider()

                        HStack {
                            Spacer()
                            Button("Reset to Default") {
                                onHotkeyReset()
                                showingRestartAlert = true
                            }
                            .buttonStyle(.link)
                            .font(.system(size: 11))
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 2)
                        .padding(.bottom, 7)
                        .frame(minHeight: 32)
                    }
                }
            }

            NativeSettingsSection("Startup") {
                NativeSettingsRow(
                    title: "Launch at Login",
                    subtitle: "Start Trace when you log in to your Mac"
                ) {
                    Toggle("", isOn: $launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: launchAtLogin) { _, newValue in
                            onLaunchAtLoginChange(newValue)
                        }
                }
            }

            NativeSettingsSection("Interface") {
                NativeSettingsRow(
                    title: "Accent Color",
                    subtitle: "Tint Trace foregrounds and Liquid Glass surfaces",
                    minHeight: 66
                ) {
                    HStack(spacing: 6) {
                        ForEach(TraceAccent.allCases) { accent in
                            let isActive = (hoveredAccent ?? accentColor) == accent
                            
                            Button {
                                accentColor = accent
                                settingsManager.updateAccentColor(accent)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(accent.color(for: colorScheme))
                                        .frame(width: 16, height: 16)
                                    
                                    if accentColor == accent {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(TraceTheme(accent: accent, colorScheme: colorScheme).onRawAccent)
                                    }
                                }
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(accentColor == accent ? traceTheme.accentFillMuted : Color.clear)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(accentColor == accent ? traceTheme.accentBorder : Color.secondary.opacity(0.18), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(accent.displayName))
                            .frame(width: 26, height: 26)
                            .overlay(alignment: .bottom) {
                                Text(accent.displayName)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .frame(width: 64)
                                    .opacity(isActive ? 1 : 0)
                                    .offset(y: 19)
                            }
                            .onHover { isHovered in
                                hoveredAccent = isHovered ? accent : (hoveredAccent == accent ? nil : hoveredAccent)
                            }
                            .animation(.easeOut(duration: 0.12), value: hoveredAccent?.rawValue)
                            .animation(.easeOut(duration: 0.12), value: accentColor.rawValue)
                        }
                    }
                    .frame(width: 292, height: 44, alignment: .topTrailing)
                }
                
                NativeSettingsDivider()
                
                NativeSettingsRow(
                    title: "Show Menu Bar Icon",
                    subtitle: "Display Trace icon in the menu bar"
                ) {
                    Toggle("", isOn: $showMenuBarIcon)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: showMenuBarIcon) { _, newValue in
                            settingsManager.updateShowMenuBarIcon(newValue)
                        }
                }
            }

            NativeSettingsSection("Search Results") {
                NativeSettingsRow(
                    title: "Results Layout",
                    subtitle: "Choose how search results are displayed"
                ) {
                    Picker("", selection: $resultsLayout) {
                        ForEach(ResultsLayout.allCases, id: \.self) { layout in
                            Text(layout.displayName).tag(layout)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                    .onChange(of: resultsLayout) { _, newValue in
                        settingsManager.updateResultsLayout(newValue.rawValue)
                    }
                }

                ForEach(SearchResultSource.allCases) { source in
                    NativeSettingsDivider()

                    NativeSettingsRow(
                        title: source.displayName,
                        subtitle: source.subtitle
                    ) {
                        Toggle("", isOn: Binding(
                            get: { settingsManager.isSearchResultSourceEnabled(source) },
                            set: { newValue in
                                settingsManager.updateSearchResultSource(source, enabled: newValue)
                                if source == .calendar, newValue, !calendarEnabled {
                                    requestCalendarPermission()
                                }
                            }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }
                }
            } footer: {
                Text("Choose which result types appear in Trace search. Calendar search is opt-in and requires permission.")
            }
            
        }
        .onAppear {
            // Load settings from SettingsManager
            resultsLayout = ResultsLayout(rawValue: settingsManager.settings.resultsLayout) ?? .compact
            showMenuBarIcon = settingsManager.settings.showMenuBarIcon
            accentColor = settingsManager.selectedAccent
            
            calendarEnabled = permissionManager.testCalendarCapability()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            calendarEnabled = permissionManager.testCalendarCapability()
        }
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
            // If restart fails, just continue running
        }
    }
    
    /// Requests calendar permissions from the user and enables calendar search if granted
    private func requestCalendarPermission() {
        guard !requestingCalendarPermission else { return }

        Task {
            requestingCalendarPermission = true
            let granted = await permissionManager.requestCalendarPermissions()
            await MainActor.run {
                self.calendarEnabled = granted
                self.requestingCalendarPermission = false

                if granted {
                    // Automatically enable calendar search when permission is granted
                    settingsManager.updateCalendarSearchEnabled(true)
                } else {
                    // Do not show Calendar as enabled when EventKit access was denied.
                    settingsManager.updateSearchResultSource(.calendar, enabled: false)
                }
            }
        }
    }
    
}
