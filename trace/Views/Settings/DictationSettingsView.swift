import AppKit
import AVFoundation
import Carbon
import SwiftUI

struct DictationSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var assetManager = DictationAssetManager.shared
    @ObservedObject private var permissionManager = PermissionManager.shared
    @Environment(\.traceTheme) private var traceTheme

    @State private var isRecordingHotkey = false
    @State private var eventMonitor: Any?
    @State private var requestingMicrophone = false
    @State private var microphoneAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var accessibilityTrusted = AXIsProcessTrusted()

    var body: some View {
        NativeSettingsPane {
            NativeSettingsSection("Dictation") {
                NativeSettingsRow(
                    title: "Enable Dictation",
                    subtitle: "Use push-to-talk dictation processed on this Mac"
                ) {
                    Toggle("", isOn: Binding(
                        get: { settingsManager.settings.dictationEnabled },
                        set: { enabled in
                            settingsManager.updateDictationEnabled(enabled)
                            DictationHotkeyManager.shared.reload()
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }

                NativeSettingsDivider()

                NativeSettingsRow(
                    title: "Push-to-Talk Hotkey",
                    subtitle: "Hold this shortcut, speak, then release to paste"
                ) {
                    HStack(spacing: 8) {
                        Button(action: startRecordingHotkey) {
                            if isRecordingHotkey {
                                Text("Press keys…")
                                    .font(.system(size: 11))
                                    .foregroundColor(traceTheme.accentForeground)
                            } else if settingsManager.settings.dictationHotkey.isEmpty {
                                Text("Set Hotkey")
                                    .font(.system(size: 11))
                            } else {
                                KeyBindingView(keyCombo: settingsManager.settings.dictationHotkey, size: .small)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if !settingsManager.settings.dictationHotkey.isEmpty {
                            Button("Clear") {
                                settingsManager.clearDictationHotkey()
                                DictationHotkeyManager.shared.reload()
                            }
                            .font(.system(size: 11))
                            .buttonStyle(.link)
                        }
                    }
                }
            } footer: {
                Text("Dictation is opt-in. Trace does not save audio or transcripts.")
            }

            NativeSettingsSection("Speech Asset") {
                NativeSettingsRow(
                    title: "System Language",
                    subtitle: localeDescription
                ) {
                    assetStatusView
                }

                if shouldShowAssetAction {
                    NativeSettingsDivider()

                    HStack {
                        Text(assetHelpText)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Button(assetButtonTitle) {
                            Task { await assetManager.download() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(!canDownloadAsset)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(minHeight: 54)
                }
            } footer: {
                Text("Speech assets are downloaded only when you click Download. Assets are managed by macOS and shared with system dictation.")
            }

            NativeSettingsSection("Permissions") {
                PermissionRow(
                    title: "Microphone Access",
                    subtitle: "Required to capture your speech while the hotkey is held",
                    icon: "mic",
                    status: microphonePermissionStatus,
                    action: handleMicrophonePermission,
                    buttonTitle: microphoneButtonTitle
                )

                NativeSettingsDivider()

                PermissionRow(
                    title: "Accessibility Access",
                    subtitle: "Required to paste dictated text into the active app",
                    icon: "accessibility",
                    status: accessibilityTrusted ? .granted : .denied,
                    action: openAccessibilitySettings
                )
            }
        }
        .onAppear {
            refreshPermissions()
            Task { await assetManager.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissions()
        }
        .onDisappear {
            stopRecordingHotkey()
        }
    }

    private var localeDescription: String {
        if let locale = assetManager.resolvedLocale {
            return Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier
        }
        return Locale.current.localizedString(forIdentifier: Locale.current.identifier) ?? Locale.current.identifier
    }

    @ViewBuilder
    private var assetStatusView: some View {
        switch assetManager.state {
        case .checking:
            ProgressView().controlSize(.small)
        case .unsupported:
            StatusPill(text: "Unsupported", color: .orange)
        case .supportedNeedsDownload:
            StatusPill(text: "Not Installed", color: .orange)
        case .downloading(_, let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: 80)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        case .installed:
            StatusPill(text: "Installed", color: .green)
        case .failed:
            StatusPill(text: "Error", color: .red)
        }
    }

    private var assetHelpText: String {
        switch assetManager.state {
        case .checking:
            return "Checking dictation support for your system language…"
        case .unsupported:
            return "Dictation is not available for your current system language."
        case .supportedNeedsDownload:
            return "Download the on-device dictation asset before enabling push-to-talk."
        case .downloading:
            return "Downloading on-device dictation support…"
        case .installed:
            return "On-device dictation support is ready."
        case .failed(let message):
            return message
        }
    }

    private var shouldShowAssetAction: Bool {
        switch assetManager.state {
        case .checking, .supportedNeedsDownload, .downloading, .failed:
            return true
        case .installed, .unsupported:
            return false
        }
    }

    private var canDownloadAsset: Bool {
        if case .supportedNeedsDownload = assetManager.state { return true }
        if case .failed = assetManager.state { return true }
        return false
    }

    private var assetButtonTitle: String {
        if case .failed = assetManager.state { return "Retry" }
        return "Download"
    }

    private var microphonePermissionStatus: PermissionStatus {
        if requestingMicrophone { return .checking }
        switch microphoneAuthorizationStatus {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    private var microphoneButtonTitle: String {
        microphoneAuthorizationStatus == .notDetermined ? "Request Permission" : "Open Settings"
    }

    private func handleMicrophonePermission() {
        refreshPermissions()

        if microphoneAuthorizationStatus == .notDetermined {
            Task {
                requestingMicrophone = true
                _ = await permissionManager.requestMicrophonePermission()
                refreshPermissions()
                requestingMicrophone = false
            }
        } else {
            permissionManager.openMicrophonePrivacySettings()
        }
    }

    private func openAccessibilitySettings() {
        refreshPermissions()

        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func refreshPermissions() {
        permissionManager.refreshMicrophoneCapability()
        microphoneAuthorizationStatus = permissionManager.microphoneAuthorizationStatus
        accessibilityTrusted = AXIsProcessTrusted()
    }

    private func startRecordingHotkey() {
        guard !isRecordingHotkey else { return }
        isRecordingHotkey = true

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isRecordingHotkey else { return event }

            if event.keyCode == 53 {
                isRecordingHotkey = false
                stopRecordingHotkey()
                return nil
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var modifierValue: UInt32 = 0
            if modifiers.contains(.command) { modifierValue |= UInt32(cmdKey) }
            if modifiers.contains(.option) { modifierValue |= UInt32(optionKey) }
            if modifiers.contains(.control) { modifierValue |= UInt32(controlKey) }
            if modifiers.contains(.shift) { modifierValue |= UInt32(shiftKey) }

            guard modifierValue != 0 else { return event }

            let keyBinding = KeyBindingView(keyCode: UInt32(event.keyCode), modifiers: modifierValue)
            let hotkey = keyBinding.keys.joined(separator: "")
            settingsManager.updateDictationHotkey(hotkey: hotkey, keyCode: Int(event.keyCode), modifiers: Int(modifierValue))
            DictationHotkeyManager.shared.reload()
            isRecordingHotkey = false
            stopRecordingHotkey()
            return nil
        }
    }

    private func stopRecordingHotkey() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}

private struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}
