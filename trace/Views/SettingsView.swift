//
//  SettingsView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI
import ServiceManagement
import Carbon

private enum TraceSettingsSection: String, CaseIterable, Identifiable {
    case general
    case windowHotkeys
    case appHotkeys
    case quickLinks
    case about
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .general:
            return "General"
        case .windowHotkeys:
            return "Window Management"
        case .appHotkeys:
            return "Application Hotkeys"
        case .quickLinks:
            return "Quick Links"
        case .about:
            return "About"
        }
    }
    
    var subtitle: String {
        switch self {
        case .general:
            return "Permissions, startup, appearance, and backups"
        case .windowHotkeys:
            return "Shortcuts for arranging windows"
        case .appHotkeys:
            return "Global shortcuts for launching apps"
        case .quickLinks:
            return "Folders, files, and web links in search"
        case .about:
            return "Version, data, and maintenance"
        }
    }
    
    var systemImage: String {
        switch self {
        case .general:
            return "gearshape"
        case .windowHotkeys:
            return "macwindow"
        case .appHotkeys:
            return "app.badge"
        case .quickLinks:
            return "link"
        case .about:
            return "info.circle"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .general:
            return Color(nsColor: .systemGray)
        case .windowHotkeys:
            return Color(nsColor: .systemBlue)
        case .appHotkeys:
            return Color(nsColor: .systemOrange)
        case .quickLinks:
            return Color(nsColor: .systemGreen)
        case .about:
            return Color(nsColor: .systemPurple)
        }
    }
}

private enum SettingsLayout {
    static let sidebarWidth: CGFloat = 240
    static let contentMaxWidth: CGFloat = 540
    static let detailTopInset: CGFloat = 8
    static let detailHorizontalInset: CGFloat = 8
}

struct SettingsView: View {
    @State private var launchAtLogin: Bool = false
    @State private var currentKeyCombo: String = "⌥Space"
    @State private var isRecording: Bool = false
    @State private var selectedSection: TraceSettingsSection = .general
    @State private var sectionSearchText: String = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    
    private let logger = AppLogger.settingsView
    private var effectiveColorScheme: ColorScheme {
        appearanceManager.colorScheme
    }
    
    private var filteredSections: [TraceSettingsSection] {
        let query = sectionSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return TraceSettingsSection.allCases }
        
        return TraceSettingsSection.allCases.filter { section in
            section.title.localizedCaseInsensitiveContains(query) ||
            section.subtitle.localizedCaseInsensitiveContains(query)
        }
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: sectionSelection) {
                ForEach(filteredSections) { section in
                    SettingsSidebarRowContent(
                        section: section,
                        isSelected: selectedSection == section
                    )
                    .tag(section)
                }
            }
            .listStyle(.sidebar)
            .searchable(text: $sectionSearchText, placement: .sidebar)
            .navigationSplitViewColumnWidth(
                min: SettingsLayout.sidebarWidth,
                ideal: SettingsLayout.sidebarWidth,
                max: SettingsLayout.sidebarWidth
            )
        } detail: {
            SettingsContentArea {
                selectedSectionView
            }
        }
        .frame(
            minWidth: AppConstants.Window.settingsWidth,
            minHeight: AppConstants.Window.settingsHeight
        )
        .traceThemed(accent: settingsManager.selectedAccent, colorScheme: effectiveColorScheme)
        .preferredColorScheme(effectiveColorScheme)
        .onAppear {
            logger.debug("Settings view appeared")
            loadSettings()
        }
    }
    
    private var sectionSelection: Binding<TraceSettingsSection?> {
        Binding(
            get: { selectedSection },
            set: { newValue in
                if let newValue {
                    selectedSection = newValue
                }
            }
        )
    }
    
    @ViewBuilder
    private var selectedSectionView: some View {
        switch selectedSection {
        case .general:
            GeneralSettingsView(
                launchAtLogin: $launchAtLogin,
                currentKeyCombo: $currentKeyCombo,
                isRecording: $isRecording,
                onLaunchAtLoginChange: handleLaunchAtLoginChange,
                onHotkeyRecord: handleHotkeyRecord,
                onHotkeyReset: handleHotkeyReset
            )
        case .windowHotkeys:
            WindowManagementSettingsView()
        case .appHotkeys:
            AppHotkeysSettingsView()
        case .quickLinks:
            QuickLinksSettingsView()
        case .about:
            AboutSettingsView()
        }
    }
    
    private func loadSettings() {
        // Load launch at login status
        launchAtLogin = SMAppService.mainApp.status == .enabled
        
        // Load current hotkey combo from SettingsManager
        let settingsManager = SettingsManager.shared
        let keyCode = settingsManager.settings.mainHotkeyKeyCode
        let modifiers = settingsManager.settings.mainHotkeyModifiers
        
        if keyCode != 0 {
            let keyBinding = KeyBindingView(keyCode: UInt32(keyCode), modifiers: UInt32(modifiers))
            currentKeyCombo = keyBinding.keys.joined(separator: "")
        } else {
            currentKeyCombo = "⌥Space"
        }
    }
    
    private func handleLaunchAtLoginChange(_ enabled: Bool) {
        logger.info("Launch at login changed to: \(enabled)")
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Failed to update launch at login: \(error)")
        }
    }
    
    private func handleHotkeyRecord(_ keyCode: UInt32, _ modifiers: UInt32) {
        logger.info("Recording hotkey: keyCode=\(keyCode), modifiers=\(modifiers)")
        
        // Save to SettingsManager
        let settingsManager = SettingsManager.shared
        settingsManager.updateMainHotkey(keyCode: Int(keyCode), modifiers: Int(modifiers))
        
        // Update the hotkey manager
        if let appDelegate = NSApp.delegate as? AppDelegate {
            do {
                try appDelegate.updateHotkey(keyCode: keyCode, modifiers: modifiers)
            } catch {
                logger.error("Failed to update hotkey: \(error)")
            }
        }
        
        isRecording = false
    }
    
    private func handleHotkeyReset() {
        logger.info("Resetting hotkey to default")
        
        // Reset to default (Option+Space)
        let defaultKeyCode: UInt32 = 49 // Space key
        let defaultModifiers: UInt32 = UInt32(optionKey)
        
        // Save to SettingsManager
        let settingsManager = SettingsManager.shared
        settingsManager.updateMainHotkey(keyCode: Int(defaultKeyCode), modifiers: Int(defaultModifiers))
        
        currentKeyCombo = "⌥Space"
        
        // Update the hotkey manager
        if let appDelegate = NSApp.delegate as? AppDelegate {
            do {
                try appDelegate.updateHotkey(keyCode: defaultKeyCode, modifiers: defaultModifiers)
            } catch {
                logger.error("Failed to reset hotkey: \(error)")
            }
        }
    }
    
    func formatKeyCombo(keyCode: UInt32, modifiers: UInt32) -> String {
        let keyView = KeyBindingView(keyCode: keyCode, modifiers: modifiers)
        return keyView.keys.joined(separator: "")
    }
    
    func restartApp() {
        let bundlePath = Bundle.main.bundlePath
        
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [bundlePath]
        
        do {
            try task.run()
            logger.info("Restarting Trace from: \(bundlePath)")
            
            // Give the new instance a moment to start before terminating
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.terminateWithoutConfirmation()
                } else {
                    NSApp.terminate(nil)
                }
            }
        } catch {
            logger.error("Failed to restart Trace: \(error.localizedDescription)")
        }
    }
}

private struct SettingsContentArea<Content: View>: View {
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SettingsSidebarIcon: View {
    let section: TraceSettingsSection
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(section.iconColor)
            
            Image(systemName: section.systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 20, height: 20)
    }
}

private struct SettingsSidebarRowContent: View {
    let section: TraceSettingsSection
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 9) {
            SettingsSidebarIcon(section: section)
            
            Text(section.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .lineLimit(1)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
    }
}

extension View {
    func systemSettingsPane() -> some View {
        NativeSettingsPane {
            self
        }
    }
}

struct NativeSettingsPane<Content: View>: View {
    @ViewBuilder var content: Content
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                content
            }
            .padding(.horizontal, SettingsLayout.detailHorizontalInset)
            .padding(.top, SettingsLayout.detailTopInset)
            .padding(.bottom, 16)
            .frame(maxWidth: SettingsLayout.contentMaxWidth, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct NativeSettingsSection<Content: View, Footer: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer
    
    init(
        _ title: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.title = title
        self.content = content()
        self.footer = footer()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.leading, 10)
            }
            
            NativeSettingsCard {
                content
            }
            
            footer
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
        }
    }
}

struct NativeSettingsCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder var content: Content
    
    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(0.052) : Color.black.opacity(0.045))
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct NativeSettingsDivider: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Rectangle()
            .fill(colorScheme == .dark ? Color.white.opacity(0.075) : Color.black.opacity(0.09))
            .frame(height: 1)
            .padding(.leading, 10)
    }
}

struct NativeSettingsRow<Accessory: View>: View {
    let title: String
    let subtitle: String?
    let minHeight: CGFloat
    @ViewBuilder var accessory: Accessory
    
    init(
        title: String,
        subtitle: String? = nil,
        minHeight: CGFloat = 54,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.minHeight = minHeight
        self.accessory = accessory()
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer(minLength: 16)
            
            accessory
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: minHeight)
    }
}

struct NativeIconSettingsRow<Accessory: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let iconColor: Color
    @ViewBuilder var accessory: Accessory
    
    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        iconColor: Color,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.iconColor = iconColor
        self.accessory = accessory()
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary)
                
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer(minLength: 16)
            
            accessory
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: 54)
    }
}
