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
                    title: "Camera Access",
                    subtitle: "Enables the local Mirror preview",
                    icon: "video",
                    status: requestingCameraPermission ? .checking : cameraPermissionStatus,
                    action: handleCameraPermissionAction,
                    buttonTitle: cameraPermissionButtonTitle
                )
            } footer: {
                Text("Camera access is only used for the local Mirror preview. You can change access any time in System Settings.")
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
                Text("System Default follows the camera recommended by macOS. Continuity Camera appears when your iPhone or iPad is nearby, unlocked, and camera access is granted.")
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

    private func handleCameraPermissionAction() {
        if cameraAuthorizationStatus == .notDetermined {
            requestCameraPermission()
        } else {
            openCameraPrivacySettings()
        }
    }

    private func refreshCameraState() {
        cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        refreshAvailableCameras()
    }

    private func refreshAvailableCameras() {
        availableCameras = MirrorManager.availableCameras()
    }

    private func requestCameraPermission() {
        guard !requestingCameraPermission else { return }

        Task {
            requestingCameraPermission = true
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                cameraAuthorizationStatus = granted
                    ? .authorized
                    : AVCaptureDevice.authorizationStatus(for: .video)
                requestingCameraPermission = false
                refreshAvailableCameras()
            }
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
