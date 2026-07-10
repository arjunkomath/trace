//
//  GeneralSettingsView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI
import AVFoundation
import Carbon
import UniformTypeIdentifiers
import os.log

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
    @State private var showingExportSuccessAlert = false
    @State private var showingImportAlert = false
    @State private var showingImportFileImporter = false
    @State private var showingExportFileExporter = false
    @State private var exportedFileURL: URL?
    @State private var importOverwriteExisting = false
    @State private var importError: String?
    @ObservedObject private var settingsManager = SettingsManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.traceTheme) private var traceTheme
    
    // Permissions states
    @ObservedObject private var permissionManager = PermissionManager.shared
    @State private var accessibilityEnabled = false
    @State private var calendarEnabled = false
    @State private var cameraAuthorizationStatus: AVAuthorizationStatus = .notDetermined
    @State private var checkingPermissions = false
    @State private var requestingCalendarPermission = false
    @State private var requestingCameraPermission = false
    @State private var availableMirrorCameras: [AVCaptureDevice] = []
    @State private var selectedMirrorCameraID: String = ""
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

            NativeSettingsSection("Permissions") {
                PermissionRow(
                    title: "Accessibility Access",
                    subtitle: "Enables window management and global hotkeys",
                    icon: "accessibility",
                    status: accessibilityEnabled ? .granted : .denied,
                    action: {
                        openAccessibilitySettings()
                    }
                )
                
                PermissionRow(
                    title: "Calendar Access",
                    subtitle: "Enables calendar event search",
                    icon: "calendar",
                    status: requestingCalendarPermission || checkingPermissions ? .checking : (calendarEnabled ? .granted : .denied),
                    action: {
                        if calendarEnabled {
                            openCalendarPrivacySettings()
                        } else {
                            requestCalendarPermission()
                        }
                    },
                    buttonTitle: calendarEnabled ? "Open Settings" : "Request Permission"
                )

                NativeSettingsDivider()

                PermissionRow(
                    title: "Camera Access",
                    subtitle: "Enables the local Mirror preview",
                    icon: "video",
                    status: requestingCameraPermission || checkingPermissions ? .checking : cameraPermissionStatus,
                    action: {
                        if cameraAuthorizationStatus == .notDetermined {
                            requestCameraPermission()
                        } else {
                            openCameraPrivacySettings()
                        }
                    },
                    buttonTitle: cameraPermissionButtonTitle
                )
                
                NativeSettingsDivider()
                
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
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(minHeight: 44)
            } footer: {
                Text("All permissions are optional. Features that need a permission may be unavailable until you grant it, and you can change access any time in System Settings.")
            }

            NativeSettingsSection("Mirror") {
                NativeSettingsRow(
                    title: "Camera",
                    subtitle: mirrorCameraSubtitle
                ) {
                    Picker("", selection: $selectedMirrorCameraID) {
                        Text("Automatic (Built-in)").tag("")

                        ForEach(availableMirrorCameras, id: \.uniqueID) { device in
                            Text(MirrorManager.displayName(for: device)).tag(device.uniqueID)
                        }

                        // Keep a previously saved camera visible if it is currently disconnected.
                        if !selectedMirrorCameraID.isEmpty,
                           !availableMirrorCameras.contains(where: { $0.uniqueID == selectedMirrorCameraID }) {
                            Text("Unavailable camera").tag(selectedMirrorCameraID)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minWidth: 200, maxWidth: 260)
                    .disabled(cameraAuthorizationStatus != .authorized && availableMirrorCameras.isEmpty)
                    .onChange(of: selectedMirrorCameraID) { _, newValue in
                        settingsManager.updateMirrorCameraDeviceID(newValue)
                        Task { @MainActor in
                            ServiceContainer.shared.mirrorManager.applyCameraSelectionChange()
                        }
                    }
                }
            } footer: {
                Text("Choose which camera Mirror uses. Automatic prefers the built-in FaceTime camera. Continuity Camera (iPhone/iPad) appears when the device is nearby, unlocked, and camera access is granted.")
            }

            NativeSettingsSection("Interface") {
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
                
                NativeSettingsDivider()
                
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
                
                NativeSettingsDivider()
                
                NativeSettingsRow(
                    title: "Calendar Search",
                    subtitle: "Search and open calendar events"
                ) {
                    Toggle("", isOn: Binding(
                        get: { settingsManager.settings.calendarSearchEnabled },
                        set: { newValue in
                            settingsManager.updateCalendarSearchEnabled(newValue)
                            if newValue && !calendarEnabled {
                                requestCalendarPermission()
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .disabled(!calendarEnabled)
                }
            }
            
            NativeSettingsSection("Settings Backup") {
                NativeSettingsRow(
                    title: "Export Settings",
                    subtitle: "Save all your Trace settings to a file"
                ) {
                    Button("Export...") {
                        exportSettings()
                    }
                    .buttonStyle(.bordered)
                }
                
                NativeSettingsDivider()
                
                NativeSettingsRow(
                    title: "Import Settings",
                    subtitle: "Restore settings from a previously exported file"
                ) {
                    Button("Import...") {
                        showingImportAlert = true
                    }
                    .buttonStyle(.bordered)
                }
            } footer: {
                Text("Export includes hotkeys, custom folders, app preferences, and usage statistics.")
            }

            RemoteSettingsSyncView()
        }
        .onAppear {
            // Load settings from SettingsManager
            resultsLayout = ResultsLayout(rawValue: settingsManager.settings.resultsLayout) ?? .compact
            showMenuBarIcon = settingsManager.settings.showMenuBarIcon
            accentColor = settingsManager.selectedAccent
            selectedMirrorCameraID = settingsManager.settings.mirrorCameraDeviceID
            refreshAvailableMirrorCameras()
            
            // Check permissions
            checkPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasConnectedNotification)) { _ in
            refreshAvailableMirrorCameras()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasDisconnectedNotification)) { _ in
            refreshAvailableMirrorCameras()
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
        
        // Reload quick links manager
        DispatchQueue.main.async {
            let serviceContainer = ServiceContainer.shared
            serviceContainer.quickLinksManager.loadQuickLinks()
        }

        DictationHotkeyManager.shared.reload()
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
        
        // Check calendar permissions
        checkCalendarPermissions()

        // Check camera permissions
        checkCameraPermissions()
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
    
    /// Checks calendar permissions in the background and updates UI state
    private func checkCalendarPermissions() {
        DispatchQueue.global(qos: .userInitiated).async {
            let hasCalendarAccess = self.permissionManager.testCalendarCapability()
            
            DispatchQueue.main.async {
                self.calendarEnabled = hasCalendarAccess
                self.checkingPermissions = false
            }
        }
    }

    private var cameraPermissionStatus: PermissionStatus {
        switch cameraAuthorizationStatus {
        case .authorized:
            return .granted
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }

    private var cameraPermissionButtonTitle: String {
        cameraAuthorizationStatus == .notDetermined ? "Request Permission" : "Open Settings"
    }

    private var mirrorCameraSubtitle: String {
        if cameraAuthorizationStatus != .authorized {
            return "Grant camera access to choose a Mirror camera"
        }
        if availableMirrorCameras.isEmpty {
            return "No cameras detected"
        }
        let continuityCount = availableMirrorCameras.filter {
            if #available(macOS 14.0, *) {
                return $0.isContinuityCamera || $0.deviceType == .continuityCamera
            }
            return false
        }.count
        if continuityCount > 0 {
            return "\(availableMirrorCameras.count) cameras · includes Continuity Camera"
        }
        return "\(availableMirrorCameras.count) cameras available for Mirror"
    }

    private func checkCameraPermissions() {
        cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        refreshAvailableMirrorCameras()
    }

    private func refreshAvailableMirrorCameras() {
        availableMirrorCameras = MirrorManager.availableCameras()
    }

    private func requestCameraPermission() {
        guard !requestingCameraPermission else { return }

        Task {
            requestingCameraPermission = true
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                cameraAuthorizationStatus = granted ? .authorized : AVCaptureDevice.authorizationStatus(for: .video)
                requestingCameraPermission = false
                refreshAvailableMirrorCameras()
            }
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
                }
            }
        }
    }
    
    private func openAccessibilitySettings() {
        // Open System Settings to Accessibility
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Opens System Settings to the Calendar privacy section
    private func openCalendarPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openCameraPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Permission Types

enum PermissionStatus {
    case granted
    case denied
    case notDetermined
    case checking
    
    var color: Color {
        switch self {
        case .granted: return .green
        case .denied: return .orange
        case .notDetermined: return .secondary
        case .checking: return .secondary
        }
    }
    
    var icon: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "exclamationmark.triangle.fill"
        case .notDetermined: return "questionmark.circle.fill"
        case .checking: return "clock"
        }
    }
    
    var statusText: String {
        switch self {
        case .granted: return "Granted"
        case .denied: return "Not Granted"
        case .notDetermined: return "Not Requested"
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
    let buttonTitle: String?
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
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
                    Button(buttonTitle ?? "Open Settings") {
                        action()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.link)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: 54)
    }
    
    init(title: String, subtitle: String, icon: String, status: PermissionStatus, action: @escaping () -> Void, buttonTitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.status = status
        self.action = action
        self.buttonTitle = buttonTitle
    }
}
