//
//  TraceTheme.swift
//  trace
//
//  Created by Codex on 5/19/2026.
//

import SwiftUI
import AppKit

enum TraceAccent: String, CaseIterable, Codable, Identifiable {
    case system
    case clear
    case blue
    case teal
    case green
    case orange
    case rose
    case violet
    case graphite
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .clear: return "Clear"
        case .blue: return "Blue"
        case .teal: return "Teal"
        case .green: return "Green"
        case .orange: return "Orange"
        case .rose: return "Rose"
        case .violet: return "Violet"
        case .graphite: return "Graphite"
        }
    }
    
    func nsColor(for colorScheme: ColorScheme) -> NSColor {
        switch self {
        case .system:
            return .controlAccentColor
        case .clear:
            return .secondaryLabelColor
        case .blue:
            return .systemBlue
        case .teal:
            return .systemTeal
        case .green:
            return .systemGreen
        case .orange:
            return .systemOrange
        case .rose:
            return .systemPink
        case .violet:
            return .systemPurple
        case .graphite:
            return colorScheme == .dark ? .systemGray : .darkGray
        }
    }

    func color(for colorScheme: ColorScheme) -> Color {
        Color(nsColor: nsColor(for: colorScheme))
    }
    
    var appliesAccent: Bool {
        self != .clear
    }
}

struct TraceTheme {
    let accent: TraceAccent
    let colorScheme: ColorScheme
    
    var accentForeground: Color {
        if accent == .clear {
            return .secondary
        }
        return Color(nsColor: TraceThemeContrast.readableAccentForeground(
            accent.nsColor(for: colorScheme),
            colorScheme: colorScheme
        ))
    }

    var accentForegroundSecondary: Color {
        if accent == .clear {
            return .secondary
        }
        return Color(nsColor: TraceThemeContrast.secondaryAccentForeground(
            accent.nsColor(for: colorScheme),
            colorScheme: colorScheme
        ))
    }
    
    var accentFill: Color {
        if accent == .clear {
            return Color.primary.opacity(colorScheme == .dark ? 0.20 : 0.16)
        }
        return accent.color(for: colorScheme).opacity(colorScheme == .dark ? 0.34 : 0.78)
    }
    
    var accentFillMuted: Color {
        if accent == .clear {
            return Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.07)
        }
        return accent.color(for: colorScheme).opacity(colorScheme == .dark ? 0.16 : 0.12)
    }
    
    var accentGlassTint: Color {
        if accent == .clear {
            return .clear
        }
        return accent.color(for: colorScheme).opacity(colorScheme == .dark ? 0.10 : 0.055)
    }
    
    var accentBorder: Color {
        if accent == .clear {
            return Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.12)
        }
        return accent.color(for: colorScheme).opacity(colorScheme == .dark ? 0.34 : 0.22)
    }
    
    var onAccent: Color {
        Color(nsColor: TraceThemeContrast.primaryText(
            on: selectedAccentFillSurface
        ))
    }

    var onAccentSecondary: Color {
        Color(nsColor: TraceThemeContrast.secondaryText(
            on: selectedAccentFillSurface
        ))
    }

    var onRawAccent: Color {
        Color(nsColor: TraceThemeContrast.primaryText(
            on: TraceThemeContrast.resolvedColor(
                accent.nsColor(for: colorScheme),
                colorScheme: colorScheme
            )
        ))
    }

    private var selectedAccentFillSurface: TraceThemeResolvedColor {
        TraceThemeContrast.selectedFillSurface(for: accent, colorScheme: colorScheme)
    }

    #if DEBUG
    static func runContrastSelfCheck() {
        TraceThemeContrastSelfCheck.runOnce()
    }
    #endif
}

private struct TraceThemeResolvedColor {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.red = red.clampedToUnit
        self.green = green.clampedToUnit
        self.blue = blue.clampedToUnit
        self.alpha = alpha.clampedToUnit
    }

    init(nsColor: NSColor, colorScheme: ColorScheme) {
        var rgbColor = nsColor
        colorScheme.traceNSAppearance.performAsCurrentDrawingAppearance {
            rgbColor = nsColor.usingColorSpace(NSColorSpace.sRGB)
                ?? nsColor.usingColorSpace(NSColorSpace.deviceRGB)
                ?? nsColor
        }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if rgbColor.colorSpace.colorSpaceModel == .rgb {
            rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            self.init(red: red, green: green, blue: blue, alpha: alpha)
            return
        }

        var white: CGFloat = 0
        if rgbColor.colorSpace.colorSpaceModel == .gray {
            rgbColor.getWhite(&white, alpha: &alpha)
            self.init(red: white, green: white, blue: white, alpha: alpha)
            return
        }

        self.init(red: 0, green: 0, blue: 0, alpha: 1)
    }

    static let black = TraceThemeResolvedColor(red: 0, green: 0, blue: 0)
    static let white = TraceThemeResolvedColor(red: 1, green: 1, blue: 1)

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    var opaque: TraceThemeResolvedColor {
        TraceThemeResolvedColor(red: red, green: green, blue: blue, alpha: 1)
    }

    func withAlpha(_ alpha: CGFloat) -> TraceThemeResolvedColor {
        TraceThemeResolvedColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    func blended(over background: TraceThemeResolvedColor) -> TraceThemeResolvedColor {
        let foregroundAlpha = alpha
        let backgroundAlpha = background.alpha * (1 - foregroundAlpha)
        let outputAlpha = foregroundAlpha + backgroundAlpha

        guard outputAlpha > 0 else {
            return TraceThemeResolvedColor(red: 0, green: 0, blue: 0, alpha: 0)
        }

        return TraceThemeResolvedColor(
            red: ((red * foregroundAlpha) + (background.red * backgroundAlpha)) / outputAlpha,
            green: ((green * foregroundAlpha) + (background.green * backgroundAlpha)) / outputAlpha,
            blue: ((blue * foregroundAlpha) + (background.blue * backgroundAlpha)) / outputAlpha,
            alpha: outputAlpha
        )
    }

    func mixed(with target: TraceThemeResolvedColor, amount: CGFloat) -> TraceThemeResolvedColor {
        let clampedAmount = amount.clampedToUnit
        let sourceAmount = 1 - clampedAmount
        return TraceThemeResolvedColor(
            red: (red * sourceAmount) + (target.red * clampedAmount),
            green: (green * sourceAmount) + (target.green * clampedAmount),
            blue: (blue * sourceAmount) + (target.blue * clampedAmount),
            alpha: (alpha * sourceAmount) + (target.alpha * clampedAmount)
        )
    }

    func contrastRatio(with other: TraceThemeResolvedColor) -> CGFloat {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    func hasMinimumContrast(on surfaces: [TraceThemeResolvedColor]) -> Bool {
        surfaces.allSatisfy { contrastRatio(with: $0) >= TraceThemeContrast.minimumContrastRatio }
    }

    private var relativeLuminance: CGFloat {
        (0.2126 * linearized(red)) + (0.7152 * linearized(green)) + (0.0722 * linearized(blue))
    }

    private func linearized(_ value: CGFloat) -> CGFloat {
        if value <= 0.03928 {
            return value / 12.92
        }
        return CGFloat(pow(Double((value + 0.055) / 1.055), 2.4))
    }
}

private enum TraceThemeContrast {
    static let minimumContrastRatio: CGFloat = 4.5

    static func resolvedColor(_ nsColor: NSColor, colorScheme: ColorScheme) -> TraceThemeResolvedColor {
        TraceThemeResolvedColor(nsColor: nsColor, colorScheme: colorScheme).opaque
    }

    static func readableAccentForeground(_ nsColor: NSColor, colorScheme: ColorScheme) -> NSColor {
        let accentColor = resolvedColor(nsColor, colorScheme: colorScheme)
        let surfaces = accentForegroundSurfaces(for: nsColor, colorScheme: colorScheme)

        if accentColor.hasMinimumContrast(on: surfaces) {
            return accentColor.nsColor
        }

        let target = colorScheme == .dark ? TraceThemeResolvedColor.white : .black
        let adjustedColor = accentColor.mixed(with: target, amount: 0.52).opaque

        if adjustedColor.hasMinimumContrast(on: surfaces) {
            return adjustedColor.nsColor
        }

        return target.nsColor
    }

    static func secondaryAccentForeground(_ nsColor: NSColor, colorScheme: ColorScheme) -> NSColor {
        let surfaces = accentForegroundSurfaces(for: nsColor, colorScheme: colorScheme)
        let foreground = resolvedColor(
            readableAccentForeground(nsColor, colorScheme: colorScheme),
            colorScheme: colorScheme
        )
        let softened = foreground.mixed(with: windowBackground(for: colorScheme), amount: 0.14).opaque

        if softened.hasMinimumContrast(on: surfaces) {
            return softened.nsColor
        }

        return foreground.nsColor
    }

    static func selectedFillSurface(for accent: TraceAccent, colorScheme: ColorScheme) -> TraceThemeResolvedColor {
        let background = windowBackground(for: colorScheme)
        let sourceColor: TraceThemeResolvedColor
        let fillOpacity: CGFloat

        if accent == .clear {
            sourceColor = resolvedColor(.labelColor, colorScheme: colorScheme)
            fillOpacity = colorScheme == .dark ? 0.20 : 0.16
        } else {
            sourceColor = resolvedColor(accent.nsColor(for: colorScheme), colorScheme: colorScheme)
            fillOpacity = colorScheme == .dark ? 0.34 : 0.78
        }

        return sourceColor.withAlpha(fillOpacity).blended(over: background).opaque
    }

    static func primaryText(on background: TraceThemeResolvedColor) -> NSColor {
        let blackContrast = TraceThemeResolvedColor.black.contrastRatio(with: background)
        let whiteContrast = TraceThemeResolvedColor.white.contrastRatio(with: background)
        return (blackContrast >= whiteContrast ? TraceThemeResolvedColor.black : .white).nsColor
    }

    static func secondaryText(on background: TraceThemeResolvedColor) -> NSColor {
        let primaryColor = TraceThemeResolvedColor(nsColor: primaryText(on: background), colorScheme: .light)
        let softened = primaryColor
            .mixed(with: background, amount: 0.14)
            .opaque

        if softened.contrastRatio(with: background) >= minimumContrastRatio {
            return softened.nsColor
        }

        return primaryColor.nsColor
    }

    static func windowBackground(for colorScheme: ColorScheme) -> TraceThemeResolvedColor {
        TraceThemeResolvedColor(nsColor: .windowBackgroundColor, colorScheme: colorScheme).opaque
    }

    private static func accentForegroundSurfaces(
        for nsColor: NSColor,
        colorScheme: ColorScheme
    ) -> [TraceThemeResolvedColor] {
        [
            windowBackground(for: colorScheme),
            resolvedColor(nsColor, colorScheme: colorScheme)
                .withAlpha(colorScheme == .dark ? 0.16 : 0.12)
                .blended(over: windowBackground(for: colorScheme))
                .opaque
        ]
    }
}

#if DEBUG
private enum TraceThemeContrastSelfCheck {
    private static var didRun = false

    static func runOnce() {
        guard !didRun else { return }
        didRun = true

        let representativeAccents: [NSColor] = [
            .controlAccentColor,
            .systemYellow,
            .systemOrange,
            .systemBlue,
            .systemPurple,
            .systemPink,
            .systemGreen,
            .systemTeal,
            .systemGray
        ]

        for colorScheme in [ColorScheme.light, .dark] {
            let neutralBackground = TraceThemeContrast.windowBackground(for: colorScheme)

            for nsColor in representativeAccents {
                let mutedAccentSurface = TraceThemeContrast.resolvedColor(nsColor, colorScheme: colorScheme)
                    .withAlpha(colorScheme == .dark ? 0.16 : 0.12)
                    .blended(over: neutralBackground)
                    .opaque
                let readableAccent = TraceThemeResolvedColor(
                    nsColor: TraceThemeContrast.readableAccentForeground(nsColor, colorScheme: colorScheme),
                    colorScheme: colorScheme
                )
                let secondaryAccent = TraceThemeResolvedColor(
                    nsColor: TraceThemeContrast.secondaryAccentForeground(nsColor, colorScheme: colorScheme),
                    colorScheme: colorScheme
                )
                assert(
                    readableAccent.hasMinimumContrast(on: [neutralBackground, mutedAccentSurface]),
                    "Accent foreground does not meet WCAG AA contrast."
                )
                assert(
                    secondaryAccent.hasMinimumContrast(on: [neutralBackground, mutedAccentSurface]),
                    "Secondary accent foreground does not meet WCAG AA contrast."
                )

                let rawAccent = TraceThemeContrast.resolvedColor(nsColor, colorScheme: colorScheme)
                let fillOpacity: CGFloat = colorScheme == .dark ? 0.34 : 0.78
                let selectedFillSurface = rawAccent
                    .withAlpha(fillOpacity)
                    .blended(over: neutralBackground)
                    .opaque
                let primaryText = TraceThemeResolvedColor(
                    nsColor: TraceThemeContrast.primaryText(on: selectedFillSurface),
                    colorScheme: colorScheme
                )
                let secondaryText = TraceThemeResolvedColor(
                    nsColor: TraceThemeContrast.secondaryText(on: selectedFillSurface),
                    colorScheme: colorScheme
                )
                let rawAccentText = TraceThemeResolvedColor(
                    nsColor: TraceThemeContrast.primaryText(on: rawAccent),
                    colorScheme: colorScheme
                )

                assert(
                    primaryText.hasMinimumContrast(on: [selectedFillSurface]),
                    "Selected primary text does not meet WCAG AA contrast."
                )
                assert(
                    secondaryText.hasMinimumContrast(on: [selectedFillSurface]),
                    "Selected secondary text does not meet WCAG AA contrast."
                )
                assert(
                    rawAccentText.hasMinimumContrast(on: [rawAccent]),
                    "Raw accent glyph text does not meet WCAG AA contrast."
                )
            }
        }
    }
}
#endif

private extension ColorScheme {
    var traceNSAppearance: NSAppearance {
        NSAppearance(named: self == .dark ? .darkAqua : .aqua) ?? NSApp.effectiveAppearance
    }
}

private extension CGFloat {
    var clampedToUnit: CGFloat {
        Swift.min(Swift.max(self, 0), 1)
    }
}

final class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()
    
    @Published private(set) var colorScheme: ColorScheme
    
    private let appearanceNotification = Notification.Name("AppleInterfaceThemeChangedNotification")
    
    private init() {
        colorScheme = Self.currentColorScheme
        
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(systemAppearanceDidChange),
            name: appearanceNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemAppearanceDidChange),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }
    
    private static var currentColorScheme: ColorScheme {
        let appearance = NSApp.effectiveAppearance
        let match = appearance.bestMatch(from: [.darkAqua, .aqua])
        return match == .darkAqua ? .dark : .light
    }
    
    @objc private func systemAppearanceDidChange() {
        DispatchQueue.main.async {
            self.colorScheme = Self.currentColorScheme
        }
    }
}

private struct TraceThemeKey: EnvironmentKey {
    static let defaultValue = TraceTheme(accent: .system, colorScheme: .light)
}

extension EnvironmentValues {
    var traceTheme: TraceTheme {
        get { self[TraceThemeKey.self] }
        set { self[TraceThemeKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    func traceThemed(accent: TraceAccent, colorScheme: ColorScheme) -> some View {
        let theme = TraceTheme(accent: accent, colorScheme: colorScheme)
        if accent.appliesAccent {
            environment(\.colorScheme, colorScheme)
                .environment(\.traceTheme, theme)
                .tint(theme.accentForeground)
        } else {
            environment(\.colorScheme, colorScheme)
                .environment(\.traceTheme, theme)
        }
    }
}
