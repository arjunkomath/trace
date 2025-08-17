//
//  EmojiResultProvider.swift
//  trace
//

import Foundation

class EmojiResultProvider: ResultProvider {
    private let emojiManager = EmojiManager.shared
    
    func getResults(for query: String, context: SearchContext) async -> [(SearchResult, Double)] {
        // Only trigger emoji search for specific queries
        guard EmojiManager.shouldTriggerEmojiSearch(for: query) else {
            return []
        }
        
        // Ensure emojis are loaded
        guard emojiManager.isLoaded else {
            return []
        }
        
        // Extract search term from query
        let searchTerm = EmojiManager.extractSearchTerm(from: query)
        
        // Get matching emojis
        let matchingEmojis: [Emoji]
        if searchTerm.isEmpty {
            // Show popular emojis when no specific search term
            matchingEmojis = emojiManager.getPopularEmojis()
        } else {
            matchingEmojis = emojiManager.searchEmojis(query: searchTerm)
        }
        
        var results: [(SearchResult, Double)] = []
        
        for emoji in matchingEmojis {
            let searchTerms = [
                emoji.name,
                emoji.keywords.joined(separator: " ")
            ]
            
            // Calculate match score
            let matchScore: Double
            if searchTerm.isEmpty {
                // For popular emojis, use a high base score
                matchScore = 0.9
            } else {
                matchScore = matchesSearchTerms(query: searchTerm, terms: searchTerms)
            }
            
            // Use prefixed emoji ID for usage tracking
            let prefixedEmojiId = "com.trace.emoji.\(emoji.id)"
            let usageScore = context.usageScores[prefixedEmojiId] ?? 0
            
            if let finalScore = calculateUnifiedScore(matchScore: matchScore, usageScore: usageScore) {
                let commandAction = EmojiCommandAction(
                    id: "emoji_\(emoji.id)",
                    displayName: "Copy \(emoji.emoji)",
                    emoji: emoji.emoji,
                    iconName: nil,
                    description: "\(emoji.name) - \(emoji.category.displayName)"
                )
                
                let searchResult = SearchResult(
                    title: emoji.name,
                    subtitle: "Copy to clipboard · \(emoji.category.displayName)",
                    icon: .emoji(emoji.emoji),
                    type: .emoji,
                    category: nil,
                    shortcut: nil,
                    lastUsed: nil,
                    commandId: prefixedEmojiId,
                    accessory: nil,
                    commandAction: commandAction
                )
                
                results.append((searchResult, finalScore))
            }
        }
        
        // Sort by relevance and limit results
        return results.sorted { $0.1 > $1.1 }.prefix(AppConstants.Search.emojiResultLimit).map { $0 }
    }
}