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
    
    func color(for colorScheme: ColorScheme) -> Color {
        switch self {
        case .system:
            return Color(nsColor: .controlAccentColor)
        case .clear:
            return .secondary
        case .blue:
            return Color(nsColor: .systemBlue)
        case .teal:
            return Color(nsColor: .systemTeal)
        case .green:
            return Color(nsColor: .systemGreen)
        case .orange:
            return Color(nsColor: .systemOrange)
        case .rose:
            return Color(nsColor: .systemPink)
        case .violet:
            return Color(nsColor: .systemPurple)
        case .graphite:
            return Color(nsColor: colorScheme == .dark ? .systemGray : .darkGray)
        }
    }
    
    var prefersDarkTextOnLightFill: Bool {
        switch self {
        case .green, .orange, .teal:
            return true
        case .system, .clear, .blue, .rose, .violet, .graphite:
            return false
        }
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
        return accent.color(for: colorScheme)
    }
    
    var accentFill: Color {
        if accent == .clear {
            return colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
        }
        return accentForeground.opacity(colorScheme == .dark ? 0.34 : 0.78)
    }
    
    var accentFillMuted: Color {
        if accent == .clear {
            return colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
        }
        return accentForeground.opacity(colorScheme == .dark ? 0.16 : 0.12)
    }
    
    var accentGlassTint: Color {
        if accent == .clear {
            return .clear
        }
        return accentForeground.opacity(colorScheme == .dark ? 0.10 : 0.055)
    }
    
    var accentBorder: Color {
        if accent == .clear {
            return colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.10)
        }
        return accentForeground.opacity(colorScheme == .dark ? 0.34 : 0.22)
    }
    
    var onAccent: Color {
        if accent == .clear {
            return .primary
        }
        if colorScheme == .light && accent.prefersDarkTextOnLightFill {
            return Color.black.opacity(0.82)
        }
        return .white
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
            environment(\.traceTheme, theme)
                .tint(theme.accentForeground)
        } else {
            environment(\.traceTheme, theme)
        }
    }
}
