//
//  ResultRowView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI

struct ResultRowView: View {
    let result: SearchResult
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.traceTheme) private var traceTheme
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Group {
                switch result.icon {
                case .system(let name):
                    Image(systemName: name)
                        .font(.system(size: 20))
                case .emoji(let emoji):
                    Text(emoji)
                        .font(.system(size: 22))
                case .image(let image):
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .app(let bundleIdentifier):
                    AppIconView(bundleIdentifier: bundleIdentifier)
                        .frame(width: 24, height: 24)
                }
            }
            .foregroundColor(isSelected ? traceTheme.onAccent : (isHovered ? traceTheme.accentForeground : .secondary))
            .frame(width: 28, height: 28)
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? traceTheme.onAccent : .primary)
                
                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? traceTheme.onAccentSecondary : .secondary)
                }
            }
            
            Spacer()
            
            // Accessory (running indicator, badge, etc.)
            if let accessory = result.accessory {
                if accessory.isIndicatorDot {
                    Circle()
                        .fill(accessoryDisplayColor(accessory))
                        .frame(width: 6, height: 6)
                } else if let displayText = accessory.displayText {
                    Text(displayText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isSelected ? traceTheme.onAccent : accessoryDisplayColor(accessory))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(isSelected ? traceTheme.onAccent.opacity(0.18) : accessoryDisplayColor(accessory).opacity(0.15))
                        )
                }
            }
            
            // Loading spinner or result type
            if result.isLoading {
                ProgressView()
                    .frame(width: 10, height: 10)
                    .scaleEffect(0.5)
                    .foregroundColor(isSelected ? traceTheme.onAccent : .secondary)
            } else {
                Text(result.type.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? traceTheme.onAccentSecondary : .secondary)
                
                // Shortcut
                if let shortcut = result.shortcut {
                    KeyBindingView(shortcut: shortcut, isSelected: isSelected, size: .small)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isSelected ? traceTheme.accentFill :
            (isHovered ? traceTheme.accentFillMuted : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private func accessoryDisplayColor(_ accessory: SearchResultAccessory) -> Color {
        switch accessory {
        case .count:
            return traceTheme.accentForeground
        default:
            return accessory.color
        }
    }
}
