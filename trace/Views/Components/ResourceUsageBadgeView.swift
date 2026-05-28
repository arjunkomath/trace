//
//  ResourceUsageBadgeView.swift
//  trace
//
//  Created by Codex on 25/5/2026.
//

import SwiftUI

enum ResourceUsageBadgeSize {
    case normal
    case compact

    var fontSize: CGFloat {
        switch self {
        case .normal:
            return 10
        case .compact:
            return 9
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .normal:
            return 9
        case .compact:
            return 8
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .normal:
            return 6
        case .compact:
            return 4
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .normal:
            return 2
        case .compact:
            return 1
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .normal:
            return 3
        case .compact:
            return 2
        }
    }
}

struct ResourceUsageBadgeView: View {
    let snapshot: ProcessUsageSnapshot
    let isSelected: Bool
    let size: ResourceUsageBadgeSize

    @Environment(\.traceTheme) private var traceTheme

    private var foregroundColor: Color {
        isSelected ? traceTheme.selectedRowForeground : .secondary
    }

    private var iconColor: Color {
        isSelected ? traceTheme.selectedRowForegroundSecondary : traceTheme.accentForeground
    }

    var body: some View {
        HStack(spacing: 5) {
            if let cpuDisplayText = snapshot.cpuDisplayText {
                usageMetric(
                    icon: "cpu",
                    value: cpuDisplayText,
                    accessibilityLabel: "CPU"
                )
            }

            usageMetric(
                icon: "memorychip",
                value: snapshot.memoryDisplayText,
                accessibilityLabel: "Memory"
            )
        }
        .font(.system(size: size.fontSize, weight: .medium))
        .foregroundColor(foregroundColor)
        .lineLimit(1)
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: size.cornerRadius)
                .fill(isSelected ? traceTheme.selectedRowForeground.opacity(0.18) : Color.secondary.opacity(0.15))
        )
        .accessibilityLabel(accessibilityText)
        .layoutPriority(1)
    }

    private var accessibilityText: String {
        if let cpuDisplayText = snapshot.cpuDisplayText {
            return "CPU \(cpuDisplayText), memory \(snapshot.memoryDisplayText)"
        }

        return "Memory \(snapshot.memoryDisplayText)"
    }

    private func usageMetric(icon: String, value: String, accessibilityLabel: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .semibold))
                .foregroundColor(iconColor)
                .accessibilityHidden(true)

            Text(value)
                .accessibilityLabel("\(accessibilityLabel) \(value)")
        }
    }
}
