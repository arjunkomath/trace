//
//  MirrorSettingsView.swift
//  trace
//

import AVFoundation
import SwiftUI

struct MirrorSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var requestingCameraPermission = false
    @State private var availableCameras: [AVCaptureDevice] = []

    var body: some View {
        NativeSettingsPane {
            NativeSettingsSection("Permission") {
                PermissionRow(
                    title: "Camera",
                    subtitle: "Used only for the live local Mirror preview. Trace does not record, save, or send camera video.",
                    icon: "video",
                    status: cameraPermissionStatus,
                    action: handleCameraPermission,
                    buttonTitle: cameraPermissionButtonTitle
                )
            } footer: {
                Text("Camera access is optional and can be changed at any time in System Settings.")
            }

            NativeSettingsSection("Camera") {
                NativeSettingsRow(
                    title: "Camera",
                    subtitle: cameraSubtitle
                ) {
                    Picker("", selection: selectedCameraID) {
                        Text("System Default").tag("")

                        ForEach(availableCameras, id: \.uniqueID) { device in
                            Text(MirrorManager.displayName(for: device)).tag(device.uniqueID)
                        }

                        if !settingsManager.settings.mirrorCameraDeviceID.isEmpty,
                           !availableCameras.contains(where: {
                               $0.uniqueID == settingsManager.settings.mirrorCameraDeviceID
                           }) {
                            Text("Unavailable camera").tag(settingsManager.settings.mirrorCameraDeviceID)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(minWidth: 200, maxWidth: 260)
                    .disabled(cameraAuthorizationStatus != .authorized)
                }
            } footer: {
                Text("System Default follows the camera recommended by macOS. Continuity Camera appears when your iPhone or iPad is nearby and unlocked.")
            }
        }
        .onAppear(perform: refreshCameraState)
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasConnectedNotification)) { _ in
            refreshAvailableCameras()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasDisconnectedNotification)) { _ in
            refreshAvailableCameras()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshCameraState()
        }
        .onChange(of: settingsManager.settings.mirrorCameraDeviceID) { _, _ in
            Task { @MainActor in
                ServiceContainer.shared.mirrorManager.applyCameraSelectionChange()
            }
        }
    }

    private var selectedCameraID: Binding<String> {
        Binding(
            get: { settingsManager.settings.mirrorCameraDeviceID },
            set: { settingsManager.updateMirrorCameraDeviceID($0) }
        )
    }

    private var cameraPermissionStatus: PermissionStatus {
        if requestingCameraPermission { return .checking }
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

    private var cameraSubtitle: String {
        guard cameraAuthorizationStatus == .authorized else {
            return "Grant camera access to choose a Mirror camera"
        }
        guard !availableCameras.isEmpty else {
            return "No cameras detected"
        }

        let cameraCount = availableCameras.count
        let cameraLabel = cameraCount == 1 ? "camera" : "cameras"
        let continuityCount = availableCameras.filter {
            $0.isContinuityCamera || $0.deviceType == .continuityCamera
        }.count

        if continuityCount > 0 {
            return "\(cameraCount) \(cameraLabel) · includes Continuity Camera"
        }
        return "\(cameraCount) \(cameraLabel) available"
    }

    private func refreshCameraState() {
        cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        refreshAvailableCameras()
    }

    private func refreshAvailableCameras() {
        availableCameras = MirrorManager.availableCameras()
    }

    private func handleCameraPermission() {
        refreshCameraState()
        guard cameraAuthorizationStatus == .notDetermined else {
            openCameraPrivacySettings()
            return
        }

        Task {
            requestingCameraPermission = true
            _ = await AVCaptureDevice.requestAccess(for: .video)
            requestingCameraPermission = false
            refreshCameraState()
        }
    }

    private func openCameraPrivacySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }

}
