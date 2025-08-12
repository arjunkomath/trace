//
//  LauncherFooterView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI

struct LauncherFooterView: View {
    let selectedResult: SearchResult?
    let selectedActionIndex: Int
    @Environment(\.colorScheme) var colorScheme
    
    init(selectedResult: SearchResult?, selectedActionIndex: Int = 0) {
        self.selectedResult = selectedResult
        self.selectedActionIndex = selectedActionIndex
    }
    
    var body: some View {
        if let result = selectedResult {
            HStack(spacing: 12) {
                
                Spacer()
                
                // Show all actions with selection highlighting
                if result.hasMultipleActions {
                    HStack(spacing: 2) {
                        ForEach(Array(result.allActions.enumerated()), id: \.offset) { index, action in
                            HStack(spacing: 4) {
                                Text(action.displayName)
                                    .font(.system(size: 12, weight: .medium))
                                
                                // Show return symbol for selected action
                                if index == selectedActionIndex {
                                    KeyBindingView(keys: ["↩"], isSelected: false, size: .small)
                                }
                            }
                            .foregroundColor(index == selectedActionIndex ? .primary : .secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(index == selectedActionIndex ? Color.accentColor.opacity(0.1) : Color.clear)
                            )
                        }
                        
                        KeyBindingView(keys: ["TAB"], isSelected: false, size: .small)
                            .padding(.leading, 8)
                    }
                } else {
                    // Default action on the right side for single actions
                    HStack(spacing: 6) {
                        Text(getActionDescription(for: result))
                            .font(.system(size: 12, weight: .medium))
                            .padding(.vertical, 3)
                            .foregroundColor(.secondary)
                        
                        KeyBindingView(keys: ["↩"], isSelected: false, size: .small)
                    }
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
            case "com.trace.command.math":
                return "Calculate"
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
            
        case .math:
            return "Calculate"
            
        default:
            return "Execute"
        }
    }
}

