//
//  FolderSettingsView.swift
//  trace
//
//  Created by Assistant on 8/10/2025.
//

import SwiftUI
import AppKit

struct FolderSettingsView: View {
    @ObservedObject private var folderManager = ServiceContainer.shared.folderManager
    @State private var editingFolder: FolderShortcut?
    
    var body: some View {
        Form {
            // System folders section
            Section {
                ForEach(folderManager.allFolders.filter { $0.isDefault }) { folder in
                    FolderRowView(
                        folder: folder,
                        onEdit: { editingFolder = folder }
                    )
                }
            } header: {
                Text("System Folders")
            } footer: {
                Text("Default macOS folders that are always available")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            // Custom folders section
            Section {
                ForEach(folderManager.customFolders) { folder in
                    FolderRowView(
                        folder: folder,
                        onEdit: { editingFolder = folder },
                        onDelete: { deleteFolder(folder) }
                    )
                }
                
                // Add folder button
                HStack {
                    Button(action: addFolder) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                            Text("Add Custom Folder")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            } header: {
                Text("Custom Folders")
            } footer: {
                Text("Add your own folders to quickly access them through search")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editingFolder) { folder in
            EditFolderView(folder: folder, folderManager: folderManager)
        }
    }
    
    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to add as a shortcut"
        
        if panel.runModal() == .OK, let url = panel.url {
            let name = url.lastPathComponent
            let folder = FolderShortcut(
                name: name,
                path: url.path,
                isDefault: false
            )
            folderManager.addCustomFolder(folder)
        }
    }
    
    private func deleteFolder(_ folder: FolderShortcut) {
        folderManager.removeCustomFolder(folder)
    }
}

struct FolderRowView: View {
    let folder: FolderShortcut
    let onEdit: () -> Void
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: folder.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Text(folder.name)
                        .font(.system(size: 13))
                }
                
                Text(folder.path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Hotkey display or edit button
            if let hotkey = folder.hotkey {
                VStack(alignment: .trailing, spacing: 2) {
                    KeyBindingView(keyCombo: hotkey, size: .small)
                    Button("Edit") {
                        onEdit()
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.link)
                }
            } else {
                Button(folder.isDefault ? "Assign Hotkey" : "Edit") {
                    onEdit()
                }
                .font(.system(size: 11))
                .buttonStyle(.link)
            }
            
            // Delete button for custom folders
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete Folder")
            }
        }
        .padding(.vertical, 4)
    }
}

struct EditFolderView: View {
    let folder: FolderShortcut
    let folderManager: FolderManager
    
    @State private var name: String
    @State private var path: String
    @State private var hotkey: String = ""
    @State private var isRecordingHotkey = false
    @State private var eventMonitor: Any?
    @Environment(\.dismiss) private var dismiss
    
    init(folder: FolderShortcut, folderManager: FolderManager) {
        self.folder = folder
        self.folderManager = folderManager
        _name = State(initialValue: folder.name)
        _path = State(initialValue: folder.path)
        _hotkey = State(initialValue: folder.hotkey ?? "")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(folder.isDefault ? "Assign Hotkey" : "Edit Folder")
                .font(.system(size: 16, weight: .semibold))
            
            Form {
                if !folder.isDefault {
                    TextField("Name:", text: $name)
                    TextField("Path:", text: $path)
                } else {
                    HStack {
                        Text("Name:")
                        Text(folder.name)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Path:")
                        Text(folder.path)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                HStack {
                    Text("Hotkey:")
                    
                    Button(action: startRecordingHotkey) {
                        if isRecordingHotkey {
                            Text("Press keys...")
                                .foregroundColor(.blue)
                        } else if !hotkey.isEmpty {
                            KeyBindingView(keyCombo: hotkey, size: .small)
                        } else {
                            Text("Click to set")
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    if !hotkey.isEmpty && !isRecordingHotkey {
                        Button("Clear") {
                            hotkey = ""
                        }
                        .buttonStyle(.link)
                    }
                }
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Save") {
                    saveChanges()
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
        .onDisappear {
            stopRecordingHotkey()
        }
    }
    
    private func startRecordingHotkey() {
        isRecordingHotkey = true
        stopRecordingHotkey()
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if self.isRecordingHotkey {
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                var modifierSymbols: [String] = []
                
                if modifiers.contains(.command) { modifierSymbols.append("⌘") }
                if modifiers.contains(.option) { modifierSymbols.append("⌥") }
                if modifiers.contains(.control) { modifierSymbols.append("⌃") }
                if modifiers.contains(.shift) { modifierSymbols.append("⇧") }
                
                // Only accept if at least one modifier is pressed
                if !modifierSymbols.isEmpty && event.keyCode != 53 { // 53 is Escape
                    let keyBinding = KeyBindingView(keyCode: UInt32(event.keyCode), modifiers: 0)
                    if let key = keyBinding.keys.last {
                        self.hotkey = modifierSymbols.joined() + key
                        self.isRecordingHotkey = false
                        self.stopRecordingHotkey()
                    }
                    return nil
                }
                
                // Cancel on Escape
                if event.keyCode == 53 {
                    self.isRecordingHotkey = false
                    self.stopRecordingHotkey()
                    return nil
                }
            }
            return event
        }
    }
    
    private func stopRecordingHotkey() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func saveChanges() {
        var updatedFolder = folder
        if !folder.isDefault {
            updatedFolder.name = name
            updatedFolder.path = path
        }
        updatedFolder.hotkey = hotkey.isEmpty ? nil : hotkey
        folderManager.updateFolder(updatedFolder)
    }
}
