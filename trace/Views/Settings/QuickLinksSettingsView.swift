//
//  QuickLinksSettingsView.swift
//  trace
//
//  Created by Claude on 13/8/2025.
//

import SwiftUI
import AppKit
import Carbon
import SymbolPicker

struct QuickLinksSettingsView: View {
    @ObservedObject private var quickLinksManager = ServiceContainer.shared.quickLinksManager
    @State private var editingQuickLink: QuickLink?
    @State private var showingAddSheet = false
    @State private var showingAddWebLinkSheet = false
    
    var body: some View {
        Form {
            // System Folders Section
            Section {
                ForEach(quickLinksManager.quickLinks.filter { $0.isSystemDefault }) { quickLink in
                    QuickLinkRowView(
                        quickLink: quickLink,
                        onEdit: { editingQuickLink = quickLink },
                        onDelete: nil // System defaults cannot be deleted
                    )
                }
            } header: {
                Text("System Folders")
            } footer: {
                Text("Default macOS folders that are always available. You can customize their hotkeys but cannot delete them.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            // Custom Quick Links Section
            Section {
                ForEach(quickLinksManager.quickLinks.filter { !$0.isSystemDefault }) { quickLink in
                    QuickLinkRowView(
                        quickLink: quickLink,
                        onEdit: { editingQuickLink = quickLink },
                        onDelete: { deleteQuickLink(quickLink) }
                    )
                }
                
                // Add buttons
                VStack(spacing: 8) {
                    HStack {
                        Button(action: { showingAddWebLinkSheet = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("Add Web Link")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Button(action: addFileLink) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("Add File / Folder Link")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Custom Quick Links")
            } footer: {
                Text("Create shortcuts to websites and files you access frequently. They'll appear in search results when you type relevant keywords.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editingQuickLink) { quickLink in
            EditQuickLinkView(quickLink: quickLink, quickLinksManager: quickLinksManager)
        }
        .sheet(isPresented: $showingAddWebLinkSheet) {
            AddWebLinkView(quickLinksManager: quickLinksManager)
        }
    }
    
    private func addFileLink() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a file or folder to add as a quick link"
        
        if panel.runModal() == .OK, let url = panel.url {
            let name = url.lastPathComponent
            let quickLink = QuickLink(
                name: name,
                urlString: url.path,
                keywords: [name.lowercased()]
            )
            quickLinksManager.addQuickLink(quickLink)
        }
    }
    
    private func deleteQuickLink(_ quickLink: QuickLink) {
        quickLinksManager.removeQuickLink(quickLink)
    }
}

struct QuickLinkRowView: View {
    let quickLink: QuickLink
    let onEdit: () -> Void
    let onDelete: (() -> Void)?
    
    var body: some View {
        HStack {
            // Icon and info
            HStack(spacing: 12) {
                Image(systemName: quickLink.systemIconName)
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(quickLink.name)
                        .font(.system(size: 13, weight: .medium))
                    
                    Text(quickLink.urlString)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Hotkey display
            if let hotkey = quickLink.hotkey, !hotkey.isEmpty {
                KeyBindingView(keyCombo: hotkey, size: .small)
            }
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                if let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct AddWebLinkView: View {
    @ObservedObject var quickLinksManager: QuickLinksManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var url = ""
    @State private var keywords = ""
    @State private var iconName = "globe"
    @State private var showingIconPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Web Link")
                    .font(.headline)
                    .padding(.leading)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    
                    Button("Add") {
                        addWebLink()
                    }
                    .disabled(name.isEmpty || url.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.trailing)
            }
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            Form {
                Section {
                    LabeledContent("Name") {
                        TextField("", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    LabeledContent("URL") {
                        TextField("", text: $url)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    LabeledContent("Keywords") {
                        TextField("", text: $keywords)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    LabeledContent("Icon") {
                        Button(action: {
                            showingIconPicker = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: iconName)
                                    .font(.system(size: 16))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 20)
                                
                                Text(iconName)
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("Select...")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.2))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• URL: Enter a web URL (https://example.com) or just the domain (example.com)")
                        Text("• Keywords: Comma-separated keywords to help find this link")
                        Text("• Icon: Click to browse and select SF Symbols")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
        .frame(width: 500, height: 340)
        .sheet(isPresented: $showingIconPicker) {
            SymbolPicker(symbol: $iconName)
        }
    }
    
    private func addWebLink() {
        let keywordArray = keywords.isEmpty ? [] : keywords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        let quickLink = QuickLink(
            name: name,
            urlString: url,
            iconName: iconName == "globe" ? nil : iconName,
            keywords: keywordArray
        )
        
        quickLinksManager.addQuickLink(quickLink)
        dismiss()
    }
}

struct EditQuickLinkView: View {
    @ObservedObject var quickLinksManager: QuickLinksManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var quickLink: QuickLink
    @State private var keywordsText: String
    @State private var isRecordingHotkey = false
    @State private var eventMonitor: Any?
    @State private var showingIconPicker = false
    
    init(quickLink: QuickLink, quickLinksManager: QuickLinksManager) {
        self.quickLinksManager = quickLinksManager
        self._quickLink = State(initialValue: quickLink)
        self._keywordsText = State(initialValue: quickLink.keywords.joined(separator: ", "))
    }
    
    var body: some View {
        VStack {
            // Header
            HStack {
                Text("Edit Quick Link")
                    .font(.headline)
                    .padding(.leading)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    
                    Button("Save") {
                        saveQuickLink()
                    }
                    .disabled(quickLink.name.isEmpty || quickLink.urlString.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.trailing)
            }
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Content
            Form {
                Section {
                    LabeledContent("Name") {
                        TextField("", text: $quickLink.name)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    LabeledContent("URL") {
                        if quickLink.isSystemDefault {
                            Text(quickLink.urlString)
                                .foregroundColor(.secondary)
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.secondary.opacity(0.2))
                                )
                        } else {
                            TextField("", text: $quickLink.urlString)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    LabeledContent("Keywords") {
                        TextField("", text: $keywordsText)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    LabeledContent("Icon") {
                        Button(action: {
                            showingIconPicker = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: quickLink.iconName ?? quickLink.systemIconName)
                                    .font(.system(size: 16))
                                    .foregroundColor(.accentColor)
                                    .frame(width: 20)
                                
                                Text(quickLink.iconName ?? quickLink.systemIconName)
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("Select...")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.secondary.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.secondary.opacity(0.2))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if !quickLink.isSystemDefault {
                        LabeledContent("Hotkey") {
                            Button(action: {
                                let hasHotkey = quickLink.hotkey != nil && !quickLink.hotkey!.isEmpty
                                if !hasHotkey || !isRecordingHotkey {
                                    if !hasHotkey {
                                        isRecordingHotkey = true
                                        startRecording()
                                    } else {
                                        quickLink.hotkey = nil
                                    }
                                }
                            }) {
                                HStack(spacing: 8) {
                                    if isRecordingHotkey {
                                        Text("Press keys...")
                                            .font(.system(size: 11))
                                            .foregroundColor(.blue)
                                    } else if quickLink.hotkey?.isEmpty != false {
                                        Text("Set Hotkey")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    } else {
                                        KeyBindingView(keyCombo: quickLink.hotkey!, size: .small)
                                        
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
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Keywords: Comma-separated terms for searching")
                        Text("• Icon: Click to browse and select SF Symbols")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: quickLink.isSystemDefault ? 380 : 440)
        .onDisappear {
            stopRecording()
        }
        .sheet(isPresented: $showingIconPicker) {
            SymbolPicker(symbol: Binding(
                get: { quickLink.iconName ?? quickLink.systemIconName },
                set: { newSymbol in
                    quickLink.iconName = newSymbol == quickLink.systemIconName ? nil : newSymbol
                }
            ))
        }
    }
    
    private func saveQuickLink() {
        // Update keywords from text
        let keywordArray = keywordsText.isEmpty ? [] : keywordsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        quickLink.keywords = keywordArray
        
        quickLinksManager.updateQuickLink(quickLink)
        dismiss()
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
                    // Format the key combination and update binding
                    let keyBinding = KeyBindingView(keyCode: UInt32(event.keyCode), modifiers: modifierValue)
                    self.quickLink.hotkey = keyBinding.keys.joined(separator: "")
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
}
