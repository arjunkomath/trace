//
//  ControlCenterProvider.swift
//  trace
//
//  Created by Arjun on 12/8/2025.
//

import Foundation

class ControlCenterProvider: ResultProvider {
    
    func getResults(for query: String, context: SearchContext) async -> [(SearchResult, Double)] {
        let controlCenterCommands = ControlCenterManager.shared.getControlCenterCommands(matching: query)
        var results: [(SearchResult, Double)] = []
        
        for command in controlCenterCommands {
            // Calculate match score for control center command (check both title and subtitle)
            var matchScore = FuzzyMatcher.match(query: query, text: command.title.lowercased())
            let subtitleScore = FuzzyMatcher.match(query: query, text: command.subtitle.lowercased())
            matchScore = max(matchScore, subtitleScore)
            
            let commandId = "com.trace.controlcenter.\(command.id)"
            let usageScore = context.usageScores[commandId] ?? 0.0
            
            if let combinedScore = calculateUnifiedScore(matchScore: matchScore, usageScore: usageScore) {
                let commandAction = InstantCommandAction(
                    id: commandId,
                    displayName: command.title,
                    iconName: command.icon,
                    operation: command.action
                )
                
                let searchResult = SearchResult(
                    title: command.title,
                    subtitle: command.subtitle,
                    icon: .system(command.icon),
                    type: .command,
                    category: command.category,
                    shortcut: nil,
                    lastUsed: nil,
                    commandId: commandId,
                    accessory: nil,
                    commandAction: commandAction
                )
                
                results.append((searchResult, combinedScore))
            }
        }
        
        return results
    }
}