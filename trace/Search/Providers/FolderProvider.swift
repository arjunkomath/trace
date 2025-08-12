//
//  FolderProvider.swift
//  trace
//
//  Created by Arjun on 12/8/2025.
//

import Foundation

class FolderProvider: ResultProvider {
    
    func getResults(for query: String, context: SearchContext) async -> [(SearchResult, Double)] {
        let folderResults = context.services.folderManager.searchFolders(query: query)
        var results: [(SearchResult, Double)] = []
        
        for folder in folderResults {
            let matchScore = FuzzyMatcher.match(query: context.queryLower, text: folder.name.lowercased())
            let commandId = "com.trace.folder.\(folder.id)"
            let usageScore = context.usageScores[commandId] ?? 0.0
            
            if let combinedScore = calculateUnifiedScore(matchScore: matchScore, usageScore: usageScore) {
                // Get hotkey for this folder
                let shortcut: KeyboardShortcut? = {
                    if let hotkeyString = folder.hotkey, !hotkeyString.isEmpty {
                        return KeyboardShortcut(keyCombo: hotkeyString)
                    }
                    return nil
                }()
                
                let folderAction = InstantCommandAction(
                    id: commandId,
                    displayName: "Open \(folder.name)",
                    iconName: folder.iconName,
                    operation: { [services = context.services] in
                        services.folderManager.openFolder(folder)
                    }
                )
                
                let result = SearchResult(
                    title: folder.name,
                    subtitle: folder.path,
                    icon: .system(folder.iconName),
                    type: .folder,
                    category: folder.isDefault ? nil : .customFolder,
                    shortcut: shortcut,
                    lastUsed: nil,
                    commandId: commandId,
                    accessory: nil,
                    commandAction: folderAction
                )
                
                results.append((result, combinedScore))
            }
        }
        
        return results
    }
}