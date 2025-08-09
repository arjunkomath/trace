//
//  SettingsView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI
import Carbon
import ServiceManagement
import UserNotifications

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
            
            PermissionsSettingsView()
                .tabItem {
                    Image(systemName: "lock.shield")
                    Text("Permissions")
                }
                .tag(1)
            
            WindowManagementSettingsView()
                .tabItem {
                    Image(systemName: "macwindow")
                    Text("Window Management")
                }
                .tag(2)
            
            AboutSettingsView()
                .tabItem {
                    Image(systemName: "info.circle")
                    Text("About")
                }
                .tag(3)
            
            DebugSettingsView()
                .tabItem {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Debug")
                }
                .tag(4)
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
        Form {
            Section {
                VStack(spacing: 20) {
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
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

struct WindowManagementSettingsView: View {
    @State private var accessibilityEnabled = false
    @State private var showingAccessibilityAlert = false
    
    var body: some View {
        Group {
            if !accessibilityEnabled {
                // Accessibility Permission Warning
                Form {
                    Section {
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
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
            } else {
                // Window Management Commands List
                Form {
                    Section {
                        ForEach(Array(WindowPosition.allCases.enumerated()), id: \.offset) { index, position in
                            WindowCommandRow(position: position)
                                .padding(.vertical, 2)
                        }
                    }
                }
                .formStyle(.grouped)
            }
        }
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

struct PermissionsSettingsView: View {
    @State private var accessibilityEnabled = false
    @State private var notificationEnabled = false
    @State private var checkingPermissions = false
    
    var body: some View {
        Form {
            Section {
                // Accessibility Permission
                PermissionRow(
                    title: "Accessibility Access",
                    subtitle: "Required for window management and global hotkeys",
                    icon: "accessibility",
                    status: accessibilityEnabled ? .granted : .denied,
                    action: {
                        openAccessibilitySettings()
                    }
                )
                
                // Notification Permission
                PermissionRow(
                    title: "Notifications",
                    subtitle: "Shows window management feedback notifications",
                    icon: "bell",
                    status: notificationEnabled ? .granted : .denied,
                    action: {
                        openNotificationSettings()
                    }
                )
            } header: {
                Text("System Permissions")
                    .font(.system(size: 11, weight: .medium))
                    .textCase(.uppercase)
            } footer: {
                Text("These permissions help Trace work seamlessly with macOS. Click 'Open Settings' to grant missing permissions.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Section {
                HStack {
                    Text("Permission status is checked automatically when this tab opens.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: checkPermissions) {
                        HStack(spacing: 4) {
                            Image(systemName: checkingPermissions ? "arrow.clockwise" : "arrow.clockwise")
                                .font(.system(size: 11))
                                .rotationEffect(checkingPermissions ? .degrees(360) : .degrees(0))
                                .animation(checkingPermissions ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: checkingPermissions)
                            Text("Refresh")
                                .font(.system(size: 11))
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(checkingPermissions)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .onAppear {
            checkPermissions()
        }
    }
    
    private func checkPermissions() {
        checkingPermissions = true
        
        // Check accessibility permissions
        accessibilityEnabled = AXIsProcessTrusted()
        
        // Check notification permissions
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationEnabled = settings.authorizationStatus == .authorized
                self.checkingPermissions = false
            }
        }
    }
    
    private func openAccessibilitySettings() {
        // Open System Settings to Accessibility
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openNotificationSettings() {
        // Open System Settings to Notifications for this app
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.trace.app"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
}

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
                        .font(.system(size: 11))
                        .foregroundColor(status.color)
                    
                    Text(status.statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(status.color)
                }
                
                if status == .denied {
                    Button("Open Settings") {
                        action()
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.link)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct DebugSettingsView: View {
    @State private var dataPath: String = ""
    @State private var fileSize: String = "Unknown"
    @State private var entryCount: Int = 0
    @State private var showingClearConfirmation = false
    @State private var showingClearedAlert = false
    
    var body: some View {
        Form {
                // Data Storage Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        // Storage Path
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Data Location")
                                    .font(.system(size: 13, weight: .medium))
                                Text(dataPath)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                            }
                            
                            Spacer()
                            
                            Button(action: openDataFolder) {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder")
                                    Text("Open")
                                }
                                .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Divider()
                        
                        // Usage Statistics
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Usage Data")
                                    .font(.system(size: 13, weight: .medium))
                                HStack(spacing: 16) {
                                    Label("\(entryCount) entries", systemImage: "list.bullet")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Label(fileSize, systemImage: "doc")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: { showingClearConfirmation = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                    Text("Clear")
                                }
                                .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Local Storage")
                        .font(.system(size: 11, weight: .medium))
                        .textCase(.uppercase)
                }
                
                // App Cache Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Application Cache")
                                .font(.system(size: 13, weight: .medium))
                            Text("Discovered apps and icons")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: refreshAppCache) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh")
                            }
                            .font(.system(size: 11))
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Cache")
                        .font(.system(size: 11, weight: .medium))
                        .textCase(.uppercase)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
        .onAppear {
            loadDebugInfo()
        }
        .confirmationDialog("Clear Usage Data", isPresented: $showingClearConfirmation) {
            Button("Clear All Data", role: .destructive) {
                clearUsageData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all usage history. Your frequently used apps will no longer be prioritized in search results.")
        }
        .alert("Data Cleared", isPresented: $showingClearedAlert) {
            Button("OK") {}
        } message: {
            Text("Usage data has been cleared successfully.")
        }
    }
    
    private func loadDebugInfo() {
        // Get data path
        let fileManager = FileManager.default
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let traceDirectory = appSupport.appendingPathComponent("Trace", isDirectory: true)
            dataPath = traceDirectory.path
            
            // Get file size and entry count
            let dataFileURL = traceDirectory.appendingPathComponent("usage_data.json")
            if fileManager.fileExists(atPath: dataFileURL.path) {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: dataFileURL.path)
                    if let fileSize = attributes[.size] as? Int64 {
                        self.fileSize = formatFileSize(fileSize)
                    }
                    
                    // Load entry count
                    if let data = try? Data(contentsOf: dataFileURL),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        entryCount = json.count
                    }
                } catch {
                    fileSize = "Error reading file"
                }
            } else {
                fileSize = "No data file"
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func openDataFolder() {
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let traceDirectory = appSupport.appendingPathComponent("Trace", isDirectory: true)
            NSWorkspace.shared.open(traceDirectory)
        }
    }
    
    private func clearUsageData() {
        UsageTracker.shared.clearUsageData()
        loadDebugInfo()
        showingClearedAlert = true
    }
    
    private func refreshAppCache() {
        // Trigger app cache refresh
        _ = AppSearchManager.shared
        // The singleton will automatically reload apps
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
                    KeyBindingView(keyCombo: keyCombo, size: .small)
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
            .frame(width: 120)
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

