//
//  BackupSyncSettingsView.swift
//  trace
//

import SwiftUI
import UniformTypeIdentifiers

struct BackupSyncSettingsView: View {
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var showingExportSuccessAlert = false
    @State private var showingImportAlert = false
    @State private var showingImportFileImporter = false
    @State private var exportedFileURL: URL?
    @State private var importOverwriteExisting = false

    var body: some View {
        NativeSettingsPane {
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
            allowsMultipleSelection: false,
            onCompletion: handleImportFileSelection
        )
    }

    private func exportSettings() {
        do {
            exportedFileURL = try settingsManager.exportToFile()
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
            reloadManagersAfterImport()
            showAlert(
                title: "Import Successful",
                message: "Settings have been imported and all managers have been reloaded. All imported hotkeys should now work immediately."
            )
        } catch {
            showAlert(title: "Import Failed", message: error.localizedDescription)
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
