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
    
    private enum FooterActionTone {
        case primary
        case secondary
    }
    
    init(selectedResult: SearchResult?, selectedActionIndex: Int = 0) {
        self.selectedResult = selectedResult
        self.selectedActionIndex = selectedActionIndex
    }
    
    var body: some View {
        if let result = selectedResult {
            HStack {
                Spacer(minLength: 0)
                
                HStack(spacing: 8) {
                    footerAction(
                        title: primaryActionTitle(for: result),
                        keys: ["↩"],
                        tone: .primary
                    )
                    
                    if result.hasMultipleActions {
                        Divider()
                            .frame(height: 16)
                        
                        footerAction(
                            title: "Actions",
                            keys: ["TAB"],
                            tone: .secondary
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            }
            .padding(.trailing, 18)
            .padding(.leading, 26)
            .padding(.top, 6)
            .padding(.bottom, 14)
        }
    }
    
    private func footerAction(title: String, keys: [String], tone: FooterActionTone) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: tone == .primary ? 12 : 11, weight: tone == .primary ? .medium : .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.86)
            
            footerKeyBinding(keys: keys)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private func footerKeyBinding(keys: [String]) -> some View {
        HStack(spacing: 3) {
            ForEach(keys.indices, id: \.self) { index in
                Text(keys[index])
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, keys[index].count > 1 ? 6 : 5)
                    .frame(height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.primary.opacity(0.06))
                    )
            }
        }
        .fixedSize()
    }
    
    private func primaryActionTitle(for result: SearchResult) -> String {
        if result.hasMultipleActions, result.allActions.indices.contains(selectedActionIndex) {
            return result.allActions[selectedActionIndex].displayName
        }
        
        return getActionDescription(for: result)
    }
    
    private func getWindowActionTitle() -> String {
        let permissionManager = PermissionManager.shared
        let capability = permissionManager.testWindowManagementCapability()
        
        switch capability {
        case .available(_, let app):
            let appName = app.localizedName ?? app.bundleIdentifier ?? "Unknown"
            return "Move \(appName)"
        case .permissionDenied:
            return "Grant Permission"
        case .noTargetApp:
            return "No Target App"
        case .noWindows:
            return "No Windows"
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
                    return getWindowActionTitle()
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
        
        case .emoji:
            return "Copy to Clipboard"
            
        default:
            return "Execute"
        }
    }
}
