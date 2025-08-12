//
//  GeneralSettingsView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI
import Carbon
import UniformTypeIdentifiers
import os.log

struct GeneralSettingsView: View {
    @Binding var launchAtLogin: Bool
    @Binding var currentKeyCombo: String
    @Binding var isRecording: Bool
    @State private var resultsLayout: ResultsLayout = .compact
    @State private var showMenuBarIcon: Bool = true
    @State private var eventMonitor: Any?
    @State private var showingRestartAlert = false
    @State private var showingExportSuccessAlert = false
    @State private var showingImportAlert = false
    @State private var showingImportFileImporter = false
    @State private var showingExportFileExporter = false
    @State private var exportedFileURL: URL?
    @State private var importOverwriteExisting = false
    @State private var importError: String?
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    // Permissions states
    @ObservedObject private var permissionManager = PermissionManager.shared
    @State private var accessibilityEnabled = false
    @State private var checkingPermissions = false
    let onLaunchAtLoginChange: (Bool) -> Void
    let onHotkeyRecord: (UInt32, UInt32) -> Void
    let onHotkeyReset: () -> Void
    
    var body: some View {
        Form {
            // Permissions section
            Section {
                PermissionRow(
                    title: "Accessibility Access",
                    subtitle: "Required for window management and global hotkeys",
                    icon: "accessibility",
                    status: accessibilityEnabled ? .granted : .denied,
                    action: {
                        openAccessibilitySettings()
                    }
                )
                
                HStack {
                    Text("Permission status is checked automatically when this tab opens.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: checkPermissions) {
                        HStack(spacing: 4) {
                            Image(systemName: checkingPermissions ? "arrow.clockwise" : "arrow.clockwise")
                                .font(.system(size: 11))
                            Text("Refresh")
                                .font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(checkingPermissions)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Permissions")
            } footer: {
                Text("These permissions help Trace work seamlessly with macOS. Click 'Open Settings' to grant missing permissions.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
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
                    .onChange(of: resultsLayout) { _, newValue in
                        settingsManager.updateResultsLayout(newValue.rawValue)
                    }
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
                        .onChange(of: showMenuBarIcon) { _, newValue in
                            settingsManager.updateShowMenuBarIcon(newValue)
                        }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Interface")
            }
            
            // Settings Import/Export section
            Section {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Export Settings")
                                .font(.system(size: 13))
                            Text("Save all your Trace settings to a file")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Export...") {
                            exportSettings()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Import Settings")
                                .font(.system(size: 13))
                            Text("Restore settings from a previously exported file")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Import...") {
                            showingImportAlert = true
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Settings Backup")
            } footer: {
                Text("Export includes hotkeys, custom folders, app preferences, and usage statistics.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            // Load settings from SettingsManager
            resultsLayout = ResultsLayout(rawValue: settingsManager.settings.resultsLayout) ?? .compact
            showMenuBarIcon = settingsManager.settings.showMenuBarIcon
            
            // Check permissions
            checkPermissions()
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
        .alert("Export Successful", isPresented: $showingExportSuccessAlert) {
            Button("Open in Finder") {
                if let url = exportedFileURL {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                }
            }
            Button("OK") { }
        } message: {
            if let url = exportedFileURL {
                Text("Settings exported to:\n\(url.lastPathComponent)")
            }
        }
        .alert("Import Settings", isPresented: $showingImportAlert) {
            Button("Replace All Settings") {
                importOverwriteExisting = true
                showingImportFileImporter = true
            }
            Button("Keep Existing (Add Missing)") {
                importOverwriteExisting = false
                showingImportFileImporter = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose how to handle existing settings when importing.")
        }
        .fileImporter(
            isPresented: $showingImportFileImporter,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportFileSelection(result)
        }
    }
    
    // MARK: - Settings Import/Export
    
    private func exportSettings() {
        do {
            let fileURL = try settingsManager.exportToFile()
            exportedFileURL = fileURL
            showingExportSuccessAlert = true
        } catch {
            showAlert(title: "Export Failed", message: error.localizedDescription)
        }
    }
    
    private func handleImportFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importSettings(from: url)
        case .failure(let error):
            showAlert(title: "File Selection Failed", message: error.localizedDescription)
        }
    }
    
    private func importSettings(from url: URL) {
        do {
            try settingsManager.importFromFile(url, overwriteExisting: importOverwriteExisting)
            
            // Reload all managers after import
            reloadManagersAfterImport()
            
            showAlert(title: "Import Successful", 
                     message: "Settings have been imported and all managers have been reloaded. All imported hotkeys should now work immediately.")
        } catch {
            showAlert(title: "Import Failed", message: error.localizedDescription)
        }
    }
    
    private func reloadManagersAfterImport() {
        // Reload app hotkeys
        AppHotkeyManager.shared.setupHotkeys()
        
        // Reload window hotkeys
        let windowHotkeyManager = WindowHotkeyManager.shared
        for (position, hotkeyData) in settingsManager.settings.windowHotkeys {
            if let windowPosition = WindowPosition(rawValue: position) {
                windowHotkeyManager.updateHotkey(
                    for: windowPosition,
                    keyCombo: hotkeyData.hotkey,
                    keyCode: UInt32(hotkeyData.keyCode),
                    modifiers: UInt32(hotkeyData.modifiers)
                )
            }
        }
        
        // Reload folder manager
        DispatchQueue.main.async {
            let serviceContainer = ServiceContainer.shared
            serviceContainer.folderManager.loadFolders()
        }
    }
    
    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
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
    
    // MARK: - Permissions Methods
    
    private func checkPermissions() {
        guard !checkingPermissions else { return } // Prevent concurrent checks
        checkingPermissions = true
        
        // Check accessibility permissions with retry mechanism for release builds
        checkAccessibilityPermissions()
    }
    
    private func checkAccessibilityPermissions() {
        DispatchQueue.global(qos: .userInitiated).async {
            let capability = self.permissionManager.testWindowManagementCapability()
            
            DispatchQueue.main.async {
                switch capability {
                case .available:
                    self.accessibilityEnabled = true
                    
                case .permissionDenied:
                    self.accessibilityEnabled = false
                    
                case .noTargetApp, .noWindows:
                    // These states don't indicate permission problems - use system API as fallback
                    self.accessibilityEnabled = AXIsProcessTrusted()
                }
                
                self.checkingPermissions = false // Reset the concurrent check guard
            }
        }
    }
    
    private func openAccessibilitySettings() {
        // Open System Settings to Accessibility
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Permission Types

enum PermissionStatus {
    case granted
    case denied
    case checking
    
    var color: Color {
        switch self {
        case .granted: return .green
        case .denied: return .orange
        case .checking: return .secondary
        }
    }
    
    var icon: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "exclamationmark.triangle.fill"
        case .checking: return "clock"
        }
    }
    
    var statusText: String {
        switch self {
        case .granted: return "Granted"
        case .denied: return "Not Granted"
        case .checking: return "Checking..."
        }
    }
}

struct PermissionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let status: PermissionStatus
    let action: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: status.icon)
                        .font(.system(size: 12))
                        .foregroundColor(status.color)
                    
                    Text(status.statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(status.color)
                }
                
                if status != .granted {
                    Button("Open Settings") {
                        action()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.link)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
