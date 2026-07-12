//
//  SettingsView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI
import ServiceManagement
import Carbon

enum TraceSettingsSection: String, CaseIterable, Identifiable {
    case general
    case permissions
    case windowHotkeys
    case mirror
    case dictation
    case caffeinate
    case appHotkeys
    case quickLinks
    case backupSync
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .permissions:
            return "Permissions"
        case .mirror:
            return "Mirror"
        case .dictation:
            return "Dictation"
        case .caffeinate:
            return "Keep Awake"
        case .windowHotkeys:
            return "Window Management"
        case .appHotkeys:
            return "Application Hotkeys"
        case .quickLinks:
            return "Quick Links"
        case .backupSync:
            return "Backup & Sync"
        case .about:
            return "About"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "Startup, appearance, and search"
        case .permissions:
            return "Privacy access used by Trace features"
        case .mirror:
            return "Camera access and preview preferences"
        case .dictation:
            return "Push-to-talk offline dictation"
        case .caffeinate:
            return "Keep your Mac awake"
        case .windowHotkeys:
            return "Shortcuts for arranging windows"
        case .appHotkeys:
            return "Global shortcuts for launching apps"
        case .quickLinks:
            return "Folders, files, and web links in search"
        case .backupSync:
            return "Import, export, and remote synchronization"
        case .about:
            return "Version, data, and maintenance"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "gearshape"
        case .permissions:
            return "hand.raised"
        case .mirror:
            return "video"
        case .dictation:
            return "waveform.and.mic"
        case .caffeinate:
            return "cup.and.saucer"
        case .windowHotkeys:
            return "macwindow"
        case .appHotkeys:
            return "app.badge"
        case .quickLinks:
            return "link"
        case .backupSync:
            return "arrow.triangle.2.circlepath"
        case .about:
            return "info.circle"
        }
    }

    var iconColor: Color {
        switch self {
        case .general:
            return Color(nsColor: .systemGray)
        case .permissions:
            return Color(nsColor: .systemYellow)
        case .mirror:
            return Color(nsColor: .systemTeal)
        case .dictation:
            return Color(nsColor: .systemRed)
        case .caffeinate:
            return Color(nsColor: .systemBrown)
        case .windowHotkeys:
            return Color(nsColor: .systemBlue)
        case .appHotkeys:
            return Color(nsColor: .systemOrange)
        case .quickLinks:
            return Color(nsColor: .systemGreen)
        case .backupSync:
            return Color(nsColor: .systemIndigo)
        case .about:
            return Color(nsColor: .systemPurple)
        }
    }
}

private enum SettingsLayout {
    static let contentMaxWidth: CGFloat = 620
    static let headerTopInset: CGFloat = 2
    static let contentTopInset: CGFloat = 12
    static let detailHorizontalInset: CGFloat = 18
    static let sidebarWidth: CGFloat = 215
}

struct SettingsView: View {
    @State private var launchAtLogin: Bool = false
    @State private var currentKeyCombo: String = "⌥Space"
    @State private var isRecording: Bool = false
    @State private var selectedSection: TraceSettingsSection
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    private let logger = AppLogger.settingsView
    private var effectiveColorScheme: ColorScheme {
        appearanceManager.colorScheme
    }

    init(initialSection: TraceSettingsSection = .general) {
        _selectedSection = State(initialValue: initialSection)
    }

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $selectedSection)

            VStack(spacing: 0) {
                SettingsDetailHeader(section: selectedSection)

                selectedSectionView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
        case .mirror:
            MirrorSettingsView()
        case .dictation:
            DictationSettingsView()
        case .caffeinate:
            CaffeinateSettingsView()
        case .windowHotkeys:
            WindowManagementSettingsView()
        case .permissions:
            PermissionsSettingsView()
        case .appHotkeys:
            AppHotkeysSettingsView()
        case .quickLinks:
            QuickLinksSettingsView()
        case .backupSync:
            BackupSyncSettingsView()
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

private struct SettingsSidebar: View {
    @Binding var selection: TraceSettingsSection
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 2) {
                ForEach(TraceSettingsSection.allCases) { section in
                    SettingsSidebarRow(
                        section: section,
                        isSelected: selection == section
                    ) {
                        selection = section
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 12)
        }
        .frame(width: SettingsLayout.sidebarWidth)
        .frame(maxHeight: .infinity)
        .background(sidebarBackground)
    }

    private var sidebarBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.035) : Color.black.opacity(0.03)
    }
}

private struct SettingsSidebarRow: View {
    let section: TraceSettingsSection
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.traceTheme) private var traceTheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(iconBackgroundFill)
                    .frame(width: 22, height: 22)
                    .overlay {
                        Image(systemName: section.systemImage)
                            .font(.system(size: 13, weight: .medium))
                            .symbolRenderingMode(.monochrome)
                            .foregroundStyle(section.iconColor)
                    }

                Text(section.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(backgroundFill)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(section.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { isHovering = $0 }
    }

    private var textColor: Color {
        if isSelected {
            return colorScheme == .dark ? Color.white.opacity(0.94) : Color.black.opacity(0.86)
        }
        return colorScheme == .dark ? Color.white.opacity(0.78) : Color.black.opacity(0.7)
    }

    private var iconBackgroundFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
    }

    private var backgroundFill: Color {
        if isSelected {
            return traceTheme.accentFillMuted
        }
        if isHovering {
            return hoverFill
        }
        return .clear
    }

    private var hoverFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.055) : Color.black.opacity(0.045)
    }
}

private struct SettingsDetailHeader: View {
    let section: TraceSettingsSection
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(section.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(section.subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SettingsLayout.detailHorizontalInset)
            .padding(.top, SettingsLayout.headerTopInset)
            .padding(.bottom, 12)

            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.10))
                .frame(height: 1)
        }
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
            .padding(.top, SettingsLayout.contentTopInset)
            .padding(.bottom, 16)
            .frame(maxWidth: SettingsLayout.contentMaxWidth, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .contentMargins(.top, 0, for: .scrollContent)
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
