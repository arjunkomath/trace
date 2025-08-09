//
//  PermissionsSettingsView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI
import UserNotifications

struct PermissionsSettingsView: View {
    @State private var accessibilityEnabled = false
    @State private var notificationEnabled = false
    @State private var checkingPermissions = false
    @State private var refreshingAccessibility = false
    
    var body: some View {
        Form {
            Section {
                // Accessibility Permission
                VStack(spacing: 8) {
                    PermissionRow(
                        title: "Accessibility Access",
                        subtitle: "Required for window management and global hotkeys",
                        icon: "accessibility",
                        status: accessibilityEnabled ? .granted : .denied,
                        action: {
                            openAccessibilitySettings()
                        }
                    )
                    
                    // Add refresh button for accessibility issues in release builds
                    if !accessibilityEnabled && !checkingPermissions {
                        HStack {
                            Button(action: {
                                refreshingAccessibility = true
                                checkAccessibilityPermissions()
                            }) {
                                HStack(spacing: 4) {
                                    if refreshingAccessibility {
                                        ProgressView()
                                            .scaleEffect(0.6)
                                    } else {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 10))
                                    }
                                    Text("Refresh Permissions")
                                }
                            }
                            .font(.system(size: 11))
                            .buttonStyle(.link)
                            .disabled(refreshingAccessibility)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                
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
        
        // Check accessibility permissions with retry mechanism for release builds
        checkAccessibilityPermissions()
        
        // Check notification permissions
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationEnabled = settings.authorizationStatus == .authorized
                self.checkingPermissions = false
            }
        }
    }
    
    private func checkAccessibilityPermissions() {
        accessibilityEnabled = WindowManager.shared.hasAccessibilityPermissions()
        refreshingAccessibility = false
    }
    
    
    private func openAccessibilitySettings() {
        // Open System Settings to Accessibility
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func openNotificationSettings() {
        // Open System Settings to Notifications for this app
        let _ = Bundle.main.bundleIdentifier ?? "com.trace.app"
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