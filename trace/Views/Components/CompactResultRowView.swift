//
//  CompactResultRowView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI

struct CompactResultRowView: View {
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
                        .font(.system(size: 18))
                case .emoji(let emoji):
                    Text(emoji)
                        .font(.system(size: 20))
                case .image(let image):
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .app(let bundleIdentifier):
                    AppIconView(bundleIdentifier: bundleIdentifier)
                        .frame(width: 20, height: 20)
                }
            }
            .foregroundColor(isSelected ? traceTheme.onAccent : (isHovered ? traceTheme.accentForeground : .secondary))
            .frame(width: 24, height: 24)
            
            // Title
            Text(result.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? traceTheme.onAccent : .primary)
                .lineLimit(1)
            
            // Subtitle (inline)
            if let subtitle = result.subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? traceTheme.onAccent.opacity(0.72) : .secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Accessory (running indicator, badge, etc.)
            if let accessory = result.accessory {
                if accessory.isIndicatorDot {
                    Circle()
                        .fill(accessoryDisplayColor(accessory))
                        .frame(width: 5, height: 5)
                } else if let displayText = accessory.displayText {
                    Text(displayText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(isSelected ? traceTheme.onAccent : accessoryDisplayColor(accessory))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isSelected ? traceTheme.onAccent.opacity(0.18) : accessoryDisplayColor(accessory).opacity(0.15))
                        )
                }
            }
            
            // Loading spinner or result type
            if result.isLoading {
                ProgressView()
                    .frame(width: 8, height: 8)
                    .scaleEffect(0.4)
                    .foregroundColor(isSelected ? traceTheme.onAccent : .secondary)
            } else {
                Text(result.type.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? traceTheme.onAccent.opacity(0.72) : .secondary)
                
                // Shortcut
                if let shortcut = result.shortcut {
                    KeyBindingView(shortcut: shortcut, isSelected: isSelected, size: .small)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8) // Reduced from 12 to make it more compact
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
