//
//  LauncherFooterView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI

struct LauncherFooterView: View {
    let selectedResult: SearchResult?
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if let result = selectedResult {
            HStack(spacing: 12) {
                Spacer()
                
                // Action on the right side
                HStack(spacing: 6) {
                    Text(getActionDescription(for: result))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    KeyBindingView(keys: ["↩"], isSelected: false, size: .small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Rectangle()
                    .fill(Color.primary.opacity(0.02))
            )
            .overlay(
                Rectangle()
                    .frame(height: 0.5)
                    .foregroundColor(Color.primary.opacity(0.15)),
                alignment: .top
            )
        }
    }
    
    private func getActionDescription(for result: SearchResult) -> String {
        switch result.type {
        case .application:
            return "Open Application"
            
        case .command:
            // Use proper command ID matching
            guard let commandId = result.commandId else {
                return "Execute Command"
            }
            
            switch commandId {
            case "com.trace.command.publicip", "com.trace.command.privateip":
                return "Copy to Clipboard"
            case "com.trace.command.settings":
                return "Open Settings"
            case "com.trace.command.quit":
                return "Quit Application"
            default:
                // Check for window commands using command ID prefix
                if commandId.hasPrefix("com.trace.window.") {
                    return "Move Window"
                }
                // Check for system settings commands using command ID prefix
                if commandId.hasPrefix("com.trace.controlcenter.") {
                    return "Open System Settings"
                }
                return "Execute Command"
            }
            
        case .suggestion:
            return "Search"
            
        case .folder:
            return "Open Folder"
            
        default:
            return "Execute"
        }
    }
}