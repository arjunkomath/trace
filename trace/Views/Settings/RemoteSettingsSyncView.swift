//
//  RemoteSettingsSyncView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI

struct RemoteSettingsSyncView: View {
    @State private var syncServerURL = ""
    @State private var syncServerToken = ""
    @State private var syncStatus = "Not configured"
    @State private var isSyncingSettings = false
    @ObservedObject private var settingsManager = SettingsManager.shared

    var body: some View {
        NativeSettingsSection("Remote Settings Sync") {
            NativeSettingsRow(
                title: "Setup Guide",
                subtitle: "Configure a self-hosted Trace sync server"
            ) {
                Button("Open Guide") {
                    openSyncSetupGuide()
                }
                .buttonStyle(.bordered)
            }

            NativeSettingsDivider()

            NativeSettingsRow(
                title: "Sync Server URL",
                subtitle: "Self-hosted Trace sync server"
            ) {
                TextField("http://localhost:8787", text: $syncServerURL)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .onChange(of: syncServerURL) { _, newValue in
                        settingsManager.syncServerURL = newValue
                    }
            }

            NativeSettingsDivider()

            NativeSettingsRow(
                title: "Sync Server Token",
                subtitle: "Shared bearer token from your server"
            ) {
                SecureField("Token", text: $syncServerToken)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .onChange(of: syncServerToken) { _, newValue in
                        settingsManager.syncServerToken = newValue
                    }
            }

            NativeSettingsDivider()

            NativeSettingsRow(
                title: "Sync Now",
                subtitle: syncStatus
            ) {
                HStack(spacing: 8) {
                    Button("Test") {
                        testSyncServer()
                    }
                    .buttonStyle(.bordered)

                    Button("Download") {
                        downloadSettingsFromSyncServer()
                    }
                    .buttonStyle(.bordered)

                    Button("Upload") {
                        uploadSettingsToSyncServer()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .disabled(isSyncingSettings)
            }
        } footer: {
            Text("Sync uses a self-hosted server and stores settings as plaintext JSON on that server.")
        }
        .onAppear {
            syncServerURL = settingsManager.syncServerURL
            syncServerToken = settingsManager.syncServerToken
            syncStatus = settingsManager.syncLastVersion > 0 ? "Last synced remote version: \(settingsManager.syncLastVersion)" : "Not synced yet"
        }
    }

    private func testSyncServer() {
        guard !isSyncingSettings else { return }
        isSyncingSettings = true
        syncStatus = "Testing..."

        Task {
            do {
                if let state = try await settingsManager.testSyncServerConnection() {
                    updateSyncStatus("Connected. Remote version: \(state.version)")
                } else {
                    updateSyncStatus("Connected. No remote settings yet.")
                }
            } catch {
                finishSyncWithError(prefix: "Test failed", error: error)
            }
        }
    }

    private func uploadSettingsToSyncServer() {
        guard !isSyncingSettings else { return }
        isSyncingSettings = true
        syncStatus = "Uploading..."

        Task {
            do {
                let state = try await settingsManager.uploadSettingsToSyncServer()
                updateSyncStatus("Uploaded remote version \(state.version)")
            } catch {
                finishSyncWithError(prefix: "Upload failed", error: error)
            }
        }
    }

    private func downloadSettingsFromSyncServer() {
        guard !isSyncingSettings else { return }
        isSyncingSettings = true
        syncStatus = "Downloading..."

        Task {
            do {
                let state = try await settingsManager.downloadSettingsFromSyncServer(overwriteExisting: true)
                await MainActor.run {
                    reloadManagersAfterImport()
                    syncStatus = "Downloaded remote version \(state.version)"
                    isSyncingSettings = false
                }
            } catch {
                finishSyncWithError(prefix: "Download failed", error: error)
            }
        }
    }

    @MainActor
    private func updateSyncStatus(_ status: String) {
        syncStatus = status
        isSyncingSettings = false
    }

    @MainActor
    private func finishSyncWithError(prefix: String, error: Error) {
        let message = error.localizedDescription
        syncStatus = "\(prefix): \(message)"
        isSyncingSettings = false
        showAlert(title: prefix, message: message)
    }

    private func openSyncSetupGuide() {
        if let url = URL(string: "https://github.com/arjunkomath/trace-sync-server#readme") {
            NSWorkspace.shared.open(url)
        }
    }

    private func reloadManagersAfterImport() {
        AppHotkeyManager.shared.setupHotkeys()

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

        DispatchQueue.main.async {
            ServiceContainer.shared.quickLinksManager.loadQuickLinks()
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
}
