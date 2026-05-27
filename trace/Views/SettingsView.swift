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
    case caffeinate
    case windowHotkeys
    case appHotkeys
    case quickLinks
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .caffeinate:
            return "Caffeinate"
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

    var tabTitle: String {
        switch self {
        case .general:
            return "General"
        case .caffeinate:
            return "Caffeinate"
        case .windowHotkeys:
            return "Windows"
        case .appHotkeys:
            return "Apps"
        case .quickLinks:
            return "Links"
        case .about:
            return "About"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "Permissions, startup, appearance, and backups"
        case .caffeinate:
            return "Keep your Mac awake"
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
        case .caffeinate:
            return "cup.and.saucer"
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
        case .caffeinate:
            return Color(nsColor: .systemBrown)
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
    static let contentMaxWidth: CGFloat = 620
    static let detailTopInset: CGFloat = 18
    static let detailHorizontalInset: CGFloat = 18
}

struct SettingsView: View {
    @State private var launchAtLogin: Bool = false
    @State private var currentKeyCombo: String = "⌥Space"
    @State private var isRecording: Bool = false
    @State private var selectedSection: TraceSettingsSection = .general
    @ObservedObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var appearanceManager = AppearanceManager.shared

    private let logger = AppLogger.settingsView
    private var effectiveColorScheme: ColorScheme {
        appearanceManager.colorScheme
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsTopTabBar(selection: $selectedSection)

            selectedSectionView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        case .caffeinate:
            CaffeinateSettingsView()
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

private struct SettingsTopTabBar: View {
    @Binding var selection: TraceSettingsSection
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(TraceSettingsSection.allCases) { section in
                            SettingsTopTabButton(
                                section: section,
                                isSelected: selection == section
                            ) {
                                selection = section
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                    .frame(minWidth: proxy.size.width, alignment: .center)
                }
            }
            .frame(height: 80)

            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.10))
                .frame(height: 1)
        }
        .background(
            Rectangle()
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }
}

private struct SettingsTopTabButton: View {
    let section: TraceSettingsSection
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.traceTheme) private var traceTheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? traceTheme.accentForegroundSecondary : section.iconColor)
                    .frame(width: 30, height: 28)

                Text(section.tabTitle)
                    .font(.system(size: 10.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .frame(width: 86, height: 58)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? traceTheme.accentBorder : Color.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(section.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .onHover { isHovering = $0 }
    }

    private var textColor: Color {
        if isSelected {
            return colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.84)
        }
        return colorScheme == .dark ? Color.white.opacity(0.76) : Color.black.opacity(0.66)
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
            .frame(maxWidth: .infinity, alignment: .top)
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
