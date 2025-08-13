//
//  QuickLinksProvider.swift
//  trace
//
//  Created by Claude on 13/8/2025.
//

import Foundation

class QuickLinksProvider: ResultProvider {
    
    func getResults(for query: String, context: SearchContext) async -> [(SearchResult, Double)] {
        let quickLinkResults = context.services.quickLinksManager.searchQuickLinks(query: query)
        var results: [(SearchResult, Double)] = []
        
        for quickLink in quickLinkResults {
            let matchScore = calculateMatchScore(quickLink: quickLink, query: context.queryLower)
            let commandId = "com.trace.quicklink.\(quickLink.id)"
            let usageScore = context.usageScores[commandId] ?? 0.0
            
            if let combinedScore = calculateUnifiedScore(matchScore: matchScore, usageScore: usageScore) {
                // Get hotkey for this quick link
                let shortcut: KeyboardShortcut? = {
                    if let hotkeyString = quickLink.hotkey, !hotkeyString.isEmpty {
                        return KeyboardShortcut(keyCombo: hotkeyString)
                    }
                    return nil
                }()
                
                // Create appropriate action based on link type
                let action: CommandAction
                if quickLink.isWebLink || !quickLink.isFileLink {
                    // Web link or unrecognized format - use URL action
                    action = URLCommandAction(
                        id: commandId,
                        displayName: "Open \(quickLink.name)",
                        iconName: quickLink.systemIconName,
                        url: quickLink.url ?? URL(string: quickLink.urlString)!
                    )
                } else {
                    // File link - use instant action
                    action = InstantCommandAction(
                        id: commandId,
                        displayName: "Open \(quickLink.name)",
                        iconName: quickLink.systemIconName,
                        operation: { [services = context.services] in
                            services.quickLinksManager.openQuickLink(quickLink)
                        }
                    )
                }
                
                // Determine subtitle
                let subtitle: String
                if quickLink.isFileLink {
                    // Show file path for file links
                    subtitle = quickLink.url?.path ?? quickLink.urlString
                } else {
                    // Show domain or full URL for web links
                    if let url = quickLink.url, let host = url.host {
                        subtitle = host
                    } else {
                        subtitle = quickLink.urlString
                    }
                }
                
                // Determine the result type and category
                let (resultType, category): (SearchResultType, ResultCategory?) = {
                    if quickLink.isSystemDefault || quickLink.isFileLink {
                        return (.folder, quickLink.isSystemDefault ? nil : .customFolder)
                    } else {
                        return (.suggestion, nil)
                    }
                }()
                
                let result = SearchResult(
                    title: quickLink.name,
                    subtitle: subtitle,
                    icon: .system(quickLink.systemIconName),
                    type: resultType,
                    category: category,
                    shortcut: shortcut,
                    lastUsed: nil,
                    commandId: commandId,
                    accessory: nil,
                    commandAction: action
                )
                
                results.append((result, combinedScore))
            }
        }
        
        return results
    }
    
    // MARK: - Private Methods
    
    private func calculateMatchScore(quickLink: QuickLink, query: String) -> Double {
        let searchableTerms = quickLink.searchableTerms
        let matchScore = matchesSearchTerms(query: query, terms: searchableTerms)
        
        // Boost exact name matches
        if quickLink.name.lowercased() == query {
            return min(matchScore + 0.3, 1.0)
        }
        
        // Boost prefix matches in name
        if quickLink.name.lowercased().hasPrefix(query) {
            return min(matchScore + 0.2, 1.0)
        }
        
        return matchScore
    }
}