//
//  AppResultProvider.swift
//  trace
//
//  Created by Arjun on 12/8/2025.
//

import Foundation

class AppResultProvider: ResultProvider {
    
    func getResults(for query: String, context: SearchContext) async -> [(SearchResult, Double)] {
        let apps = context.services.appSearchManager.searchApps(query: context.query, limit: 30)
        
        var results: [(SearchResult, Double)] = []
        
        for app in apps {
            let runningAppInfo = context.services.appSearchManager.getRunningAppInfo(
                bundleIdentifier: app.bundleIdentifier
            )
            let shortcut: KeyboardShortcut? = {
                if let hotkeyString = context.services.appHotkeyManager.getHotkey(for: app.bundleIdentifier), !hotkeyString.isEmpty {
                    return KeyboardShortcut(keyCombo: hotkeyString)
                }
                return nil
            }()
            
            let accessory: SearchResultAccessory? = runningAppInfo == nil ? nil : .runningIndicator
            
            let launchAction = InstantCommandAction(
                id: app.bundleIdentifier,
                displayName: "Launch \(app.displayName)",
                iconName: nil,
                operation: {
                    context.services.appSearchManager.launchApp(app)
                }
            )

            let commandAction: CommandAction
            if let runningAppInfo {
                let quitAction = QuitApplicationCommandAction(
                    bundleIdentifier: app.bundleIdentifier,
                    processIdentifier: runningAppInfo.processIdentifier,
                    applicationName: app.displayName
                )

                commandAction = MultiCommandAction(
                    id: app.bundleIdentifier,
                    primaryAction: launchAction,
                    secondaryActions: [quitAction]
                )
            } else {
                commandAction = launchAction
            }
            
            let result = SearchResult(
                title: app.displayName,
                subtitle: nil,
                icon: .app(app.bundleIdentifier),
                type: .application,
                category: .applications,
                shortcut: shortcut,
                lastUsed: nil,
                commandId: app.bundleIdentifier,
                accessory: accessory,
                commandAction: commandAction
            )
            
            let matchScore = FuzzyMatcher.match(query: query, text: app.displayName.lowercased())
            let usageScore = context.usageScores[app.bundleIdentifier] ?? 0.0
            
            if let combinedScore = calculateUnifiedScore(matchScore: matchScore, usageScore: usageScore) {
                results.append((result, combinedScore))
            }
        }
        
        return results
    }
}
