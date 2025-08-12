//
//  WindowManagementProvider.swift
//  trace
//
//  Created by Arjun on 12/8/2025.
//

import Foundation

class WindowManagementProvider: ResultProvider {
    
    func getResults(for query: String, context: SearchContext) async -> [(SearchResult, Double)] {
        let windowCommands = getWindowManagementCommands(query: query, context: context)
        var results: [(SearchResult, Double)] = []
        
        for command in windowCommands {
            // Calculate match score for window command (check both title and subtitle)
            var matchScore = FuzzyMatcher.match(query: query, text: command.title.lowercased())
            if let subtitle = command.subtitle {
                let subtitleScore = FuzzyMatcher.match(query: query, text: subtitle.lowercased())
                matchScore = max(matchScore, subtitleScore)
            }
            
            let commandId = command.commandId ?? getCommandIdentifier(for: command.title)
            let usageScore = context.usageScores[commandId] ?? 0.0
            
            if let combinedScore = calculateUnifiedScore(matchScore: matchScore, usageScore: usageScore) {
                results.append((command, combinedScore))
            }
        }
        
        return results
    }
    
    // MARK: - Private Methods
    
    private func getWindowManagementCommands(query: String, context: SearchContext) -> [SearchResult] {
        var commands: [SearchResult] = []
        
        // Only show window commands if user is searching for window-related terms
        let windowTerms = [
            "window", "win", "resize", "move", "position", "left", "right", "center", "top", "bottom",
            "half", "third", "quarter", "maximize", "max", "larger", "smaller", "split"
        ]
        
        let hasWindowMatch = windowTerms.contains { term in
            FuzzyMatcher.match(query: query, text: term) > 0.3
        }
        
        // Also check direct matches against position names
        let directMatches = WindowPosition.allCases.filter { position in
            let searchTerms = [
                position.rawValue,
                position.displayName.lowercased(),
                position.displayName.replacingOccurrences(of: " ", with: "").lowercased()
            ]
            return searchTerms.contains { term in
                FuzzyMatcher.match(query: query, text: term) > 0.3
            }
        }
        
        if hasWindowMatch || !directMatches.isEmpty {
            // If we have direct matches, prioritize those, otherwise show all that meet threshold
            let positionsToCheck = !directMatches.isEmpty ? directMatches : WindowPosition.allCases
            
            for position in positionsToCheck {
                let searchTerms = [
                    position.rawValue,
                    position.displayName.lowercased(),
                    position.displayName.replacingOccurrences(of: " ", with: "").lowercased()
                ]
                
                let score = FuzzyMatcher.matchBest(query: query, terms: searchTerms)
                
                // Use consistent scoring with other commands
                if score > 0.3 {
                    // Check if this window position has a hotkey assigned
                    let shortcut: KeyboardShortcut? = {
                        if let hotkeyData = SettingsManager.shared.getWindowHotkey(for: position.rawValue) {
                            return KeyboardShortcut(keyCombo: hotkeyData.hotkey)
                        }
                        return nil
                    }()
                    
                    let windowAction = InstantCommandAction(
                        id: "com.trace.window.\(position.rawValue)",
                        displayName: position.displayName,
                        iconName: getWindowIcon(for: position),
                        operation: {
                            context.services.windowManager.applyWindowPosition(position)
                        }
                    )
                    
                    commands.append(SearchResult(
                        title: position.displayName,
                        subtitle: position.subtitle,
                        icon: .system(getWindowIcon(for: position)),
                        type: .command,
                        category: .window,
                        shortcut: shortcut,
                        lastUsed: nil,
                        commandId: "com.trace.window.\(position.rawValue)",
                        accessory: nil,
                        commandAction: windowAction
                    ))
                }
            }
        }
        
        return commands.sorted { $0.title < $1.title }
    }
    
    private func getWindowIcon(for position: WindowPosition) -> String {
        switch position {
        case .leftHalf: return "rectangle.split.2x1"
        case .rightHalf: return "rectangle.split.2x1"
        case .centerHalf: return "rectangle.center.inset.filled"
        case .topHalf: return "rectangle.split.1x2"
        case .bottomHalf: return "rectangle.split.1x2"
        case .topLeft, .topRight, .bottomLeft, .bottomRight: return "rectangle.split.2x2"
        case .firstThird, .centerThird, .lastThird: return "rectangle.split.3x1"
        case .firstTwoThirds, .lastTwoThirds: return "rectangle.split.3x1"
        case .maximize: return "arrow.up.left.and.arrow.down.right"
        case .fullScreen: return "rectangle.fill"
        case .almostMaximize: return "macwindow"
        case .maximizeHeight: return "arrow.up.and.down"
        case .smaller: return "minus.rectangle"
        case .larger: return "plus.rectangle"
        case .center: return "target"
        case .centerProminently: return "viewfinder"
        }
    }
    
    private func getCommandIdentifier(for title: String) -> String {
        // Fallback identifier for commands without explicit commandId
        return "com.trace.command.\(title.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }
}