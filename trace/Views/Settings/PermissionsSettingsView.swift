//
//  PermissionsSettingsView.swift
//  trace
//

import AppKit
import AVFoundation
import EventKit
import Speech
import SwiftUI

private enum TracePermission {
    case calendar
    case camera
    case microphone
    case speechRecognition
}

struct PermissionsSettingsView: View {
    @ObservedObject private var permissionManager = PermissionManager.shared
    @ObservedObject private var settingsManager = SettingsManager.shared

    @State private var accessibilityTrusted = AXIsProcessTrusted()
    @State private var calendarAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @State private var cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var microphoneAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var speechRecognitionAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()
    @State private var requestingPermission: TracePermission?

    var body: some View {
        NativeSettingsPane {
            NativeSettingsSection("System Control") {
                PermissionRow(
                    title: "Accessibility",
                    subtitle: "Lets Trace inspect and arrange other apps’ windows, search their menu items, and paste dictated text into the active app.",
                    icon: "accessibility",
                    status: accessibilityTrusted ? .granted : .denied,
                    action: openAccessibilitySettings,
                    buttonTitle: "Open Settings"
                )

                NativeSettingsDivider()

                PermissionRow(
                    title: "Automation",
                    subtitle: "Lets Trace send Apple events to System Events for appearance commands and to Calendar when opening an event. macOS manages each target separately.",
                    icon: "gearshape.2",
                    status: .managedInSettings,
                    action: { openPrivacySettings("Privacy_Automation") },
                    buttonTitle: "Open Settings"
                )
            } footer: {
                Text("Accessibility is required for window management and inserting dictation. Automation is requested only when you use a feature that controls another macOS app or service.")
            }

            NativeSettingsSection("Search & Events") {
                PermissionRow(
                    title: "Calendar",
                    subtitle: "Lets Trace read event titles, times, and calendar names so upcoming events can appear in launcher search. Calendar data stays on your Mac.",
                    icon: "calendar",
                    status: calendarPermissionStatus,
                    action: handleCalendarPermission,
                    buttonTitle: buttonTitle(for: calendarPermissionStatus)
                )
            }

            NativeSettingsSection("Mirror") {
                PermissionRow(
                    title: "Camera",
                    subtitle: "Used only for the live local Mirror preview. Trace does not record, save, or send camera video.",
                    icon: "video",
                    status: cameraPermissionStatus,
                    action: handleCameraPermission,
                    buttonTitle: buttonTitle(for: cameraPermissionStatus)
                )
            }

            NativeSettingsSection("Dictation") {
                PermissionRow(
                    title: "Microphone",
                    subtitle: "Captures audio only while you hold the push-to-talk hotkey. Trace does not save the audio.",
                    icon: "mic",
                    status: microphonePermissionStatus,
                    action: handleMicrophonePermission,
                    buttonTitle: buttonTitle(for: microphonePermissionStatus)
                )

                NativeSettingsDivider()

                PermissionRow(
                    title: "Speech Recognition",
                    subtitle: "Uses Apple’s on-device speech recognition and downloaded language assets to turn dictation into text. Trace does not store transcripts.",
                    icon: "waveform",
                    status: speechRecognitionPermissionStatus,
                    action: handleSpeechRecognitionPermission,
                    buttonTitle: buttonTitle(for: speechRecognitionPermissionStatus)
                )
            } footer: {
                Text("All permissions are optional. Features that rely on a permission remain unavailable until access is granted.")
            }
        }
        .onAppear(perform: refreshPermissions)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissions()
        }
    }

    private var calendarPermissionStatus: PermissionStatus {
        if requestingPermission == .calendar { return .checking }
        if calendarAuthorizationStatus == .fullAccess { return .granted }
        if calendarAuthorizationStatus == .notDetermined { return .notDetermined }
        return .denied
    }

    private var cameraPermissionStatus: PermissionStatus {
        permissionStatus(
            for: cameraAuthorizationStatus,
            isRequesting: requestingPermission == .camera
        )
    }

    private var microphonePermissionStatus: PermissionStatus {
        permissionStatus(
            for: microphoneAuthorizationStatus,
            isRequesting: requestingPermission == .microphone
        )
    }

    private var speechRecognitionPermissionStatus: PermissionStatus {
        if requestingPermission == .speechRecognition { return .checking }
        switch speechRecognitionAuthorizationStatus {
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

    private func permissionStatus(
        for status: AVAuthorizationStatus,
        isRequesting: Bool
    ) -> PermissionStatus {
        if isRequesting { return .checking }
        switch status {
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

    private func buttonTitle(for status: PermissionStatus) -> String {
        status == .notDetermined ? "Request Permission" : "Open Settings"
    }

    private func handleCalendarPermission() {
        refreshPermissions()
        guard calendarAuthorizationStatus == .notDetermined else {
            openPrivacySettings("Privacy_Calendars")
            return
        }

        Task {
            requestingPermission = .calendar
            let granted = await permissionManager.requestCalendarPermissions()
            if granted {
                settingsManager.updateCalendarSearchEnabled(true)
            }
            requestingPermission = nil
            refreshPermissions()
        }
    }

    private func handleCameraPermission() {
        refreshPermissions()
        guard cameraAuthorizationStatus == .notDetermined else {
            openPrivacySettings("Privacy_Camera")
            return
        }

        Task {
            requestingPermission = .camera
            _ = await AVCaptureDevice.requestAccess(for: .video)
            requestingPermission = nil
            refreshPermissions()
        }
    }

    private func handleMicrophonePermission() {
        refreshPermissions()
        guard microphoneAuthorizationStatus == .notDetermined else {
            permissionManager.openMicrophonePrivacySettings()
            return
        }

        Task {
            requestingPermission = .microphone
            _ = await permissionManager.requestMicrophonePermission()
            requestingPermission = nil
            refreshPermissions()
        }
    }

    private func handleSpeechRecognitionPermission() {
        refreshPermissions()
        guard speechRecognitionAuthorizationStatus == .notDetermined else {
            permissionManager.openSpeechRecognitionPrivacySettings()
            return
        }

        Task {
            requestingPermission = .speechRecognition
            _ = await permissionManager.requestSpeechRecognitionPermission()
            requestingPermission = nil
            refreshPermissions()
        }
    }

    private func refreshPermissions() {
        accessibilityTrusted = AXIsProcessTrusted()
        calendarAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
        cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        microphoneAuthorizationStatus = permissionManager.microphoneAuthorizationStatus
        speechRecognitionAuthorizationStatus = permissionManager.speechRecognitionAuthorizationStatus
    }

    private func openAccessibilitySettings() {
        openPrivacySettings("Privacy_Accessibility")
    }

    private func openPrivacySettings(_ pane: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

enum PermissionStatus {
    case granted
    case denied
    case notDetermined
    case checking
    case managedInSettings

    var color: Color {
        switch self {
        case .granted:
            return .green
        case .denied:
            return .orange
        case .notDetermined, .checking, .managedInSettings:
            return .secondary
        }
    }

    var icon: String {
        switch self {
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "exclamationmark.triangle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        case .checking:
            return "clock"
        case .managedInSettings:
            return "gearshape.fill"
        }
    }

    var statusText: String {
        switch self {
        case .granted:
            return "Granted"
        case .denied:
            return "Not Granted"
        case .notDetermined:
            return "Not Requested"
        case .checking:
            return "Checking..."
        case .managedInSettings:
            return "Managed in Settings"
        }
    }
}

struct PermissionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let status: PermissionStatus
    let action: () -> Void
    let buttonTitle: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13))

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: status.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(status.color)

                    Text(status.statusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(status.color)
                }

                if status != .checking {
                    Button(buttonTitle, action: action)
                        .font(.system(size: 11))
                        .buttonStyle(.link)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(minHeight: 66)
    }
}
