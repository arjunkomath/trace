//
//  SystemCommandProvider.swift
//  trace
//
//  Created by Arjun on 12/8/2025.
//

import Foundation
import AppKit

class SystemCommandProvider: ResultProvider {
    private let clearSearch: () -> Void
    private let onClose: () -> Void
    
    init(clearSearch: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.clearSearch = clearSearch
        self.onClose = onClose
    }
    
    func getResults(for query: String, context: SearchContext) async -> [(SearchResult, Double)] {
        var results: [(SearchResult, Double)] = []
        
        // Settings command
        if let settingsResult = createSettingsCommand(query: query, context: context) {
            results.append(settingsResult)
        }
        
        // Quit command
        if let quitResult = createQuitCommand(query: query, context: context) {
            results.append(quitResult)
        }
        
        return results
    }
    
    // MARK: - Private Methods
    
    private func createSettingsCommand(query: String, context: SearchContext) -> (SearchResult, Double)? {
        let settingsMatchScore = matchesSearchTerms(query: query, terms: [
            "trace settings", "settings", "preferences", "config", "configuration",
            "trace", "setup", "options", "prefs", "configure", "hotkeys"
        ])
        
        let settingsId = "com.trace.command.settings"
        let settingsUsageScore = context.usageScores[settingsId] ?? 0.0
        
        guard let settingsScore = calculateUnifiedScore(matchScore: settingsMatchScore, usageScore: settingsUsageScore) else {
            return nil
        }
        
        let settingsResult = createSystemCommand(
            commandId: settingsId,
            title: "Trace Settings",
            subtitle: "Configure hotkeys and preferences",
            icon: "gearshape",
            shortcut: nil,
            operation: createSettingsAction(commandId: settingsId, context: context) {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.showSettings()
                } else {
                    // Try alternative approach
                    NSApp.sendAction(#selector(AppDelegate.showSettings), to: nil, from: nil)
                }
            }
        )
        
        return (settingsResult, settingsScore)
    }
    
    private func createQuitCommand(query: String, context: SearchContext) -> (SearchResult, Double)? {
        let quitMatchScore = matchesSearchTerms(query: query, terms: [
            "quit trace", "quit", "exit", "close", "terminate", "stop", "end", "application"
        ])
        
        let quitId = "com.trace.command.quit"
        let quitUsageScore = context.usageScores[quitId] ?? 0.0
        
        guard let quitScore = calculateUnifiedScore(matchScore: quitMatchScore, usageScore: quitUsageScore) else {
            return nil
        }
        
        let quitResult = createSystemCommand(
            commandId: quitId,
            title: "Quit Trace",
            subtitle: "Exit the application",
            icon: "power",
            shortcut: KeyboardShortcut(key: "Q", modifiers: ["⌘"]),
            operation: createStandardAction(commandId: quitId, context: context) {
                NSApp.terminate(nil)
            }
        )
        
        return (quitResult, quitScore)
    }
    
    // MARK: - Helper Methods
    
    private func createSystemCommand(
        commandId: String,
        title: String,
        subtitle: String,
        icon: String,
        shortcut: KeyboardShortcut? = nil,
        operation: @escaping () -> Void
    ) -> SearchResult {
        let commandAction = InstantCommandAction(
            id: commandId,
            displayName: title,
            iconName: icon,
            operation: operation
        )
        
        return SearchResult(
            title: title,
            subtitle: subtitle,
            icon: .system(icon),
            type: .command,
            category: nil,
            shortcut: shortcut,
            lastUsed: nil,
            commandId: commandId,
            accessory: nil,
            commandAction: commandAction
        )
    }
    
    private func createStandardAction(commandId: String, context: SearchContext, customAction: @escaping () -> Void) -> () -> Void {
        return { [clearSearch, onClose] in
            context.services.usageTracker.recordUsage(for: commandId, type: UsageType.command)
            
            DispatchQueue.main.async {
                customAction()
                clearSearch()
                onClose()
            }
        }
    }
    
    private func createSettingsAction(commandId: String, context: SearchContext, customAction: @escaping () -> Void) -> () -> Void {
        return {
            context.services.usageTracker.recordUsage(for: commandId, type: UsageType.command)
            
            DispatchQueue.main.async {
                customAction()
                // Don't call clearSearch() or onClose() - let LauncherSearchLogic handle it
            }
        }
    }
}
