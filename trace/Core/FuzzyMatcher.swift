//
//  FuzzyMatcher.swift
//  trace
//
//  Created by Arjun on 9/8/2025.
//

import Foundation

/// Shared fuzzy matching utility with consistent scoring across the app
struct FuzzyMatcher {
    
    /// Performs fuzzy matching between a query and text
    /// - Parameters:
    ///   - query: The search query
    ///   - text: The text to match against
    /// - Returns: A score between 0.0 and 1.0, where 1.0 is a perfect match
    static func match(query: String, text: String) -> Double {
        let queryLower = query.lowercased()
        let textLower = text.lowercased()
        
        // Exact match gets highest score
        if textLower == queryLower {
            return 1.0
        }
        
        // Prefix match gets high score
        if textLower.hasPrefix(queryLower) {
            return 0.9
        }
        
        // Contains match gets medium score
        if textLower.contains(queryLower) {
            return 0.7
        }
        
        // Fuzzy character-by-character matching
        return fuzzyCharacterMatch(query: queryLower, text: textLower)
    }
    
    /// Matches against multiple search terms and returns the best score
    /// - Parameters:
    ///   - query: The search query
    ///   - terms: Array of terms to match against
    /// - Returns: The highest matching score from all terms
    static func matchBest(query: String, terms: [String]) -> Double {
        return terms.compactMap { term in
            match(query: query, text: term)
        }.max() ?? 0.0
    }
    
    // MARK: - Private Helpers
    
    private static func fuzzyCharacterMatch(query: String, text: String) -> Double {
        let queryChars = Array(query)
        let textChars = Array(text)
        
        var queryIndex = 0
        var matches = 0
        var consecutiveMatches = 0
        var maxConsecutive = 0
        
        for textChar in textChars {
            if queryIndex < queryChars.count && queryChars[queryIndex] == textChar {
                matches += 1
                queryIndex += 1
                consecutiveMatches += 1
                maxConsecutive = max(maxConsecutive, consecutiveMatches)
            } else {
                consecutiveMatches = 0
            }
        }
        
        // All query characters must be found
        guard matches == queryChars.count else { return 0 }
        
        // Score based on match ratio and consecutive matches
        let matchRatio = Double(matches) / Double(textChars.count)
        let consecutiveBonus = Double(maxConsecutive) / Double(queryChars.count)
        
        return min(0.6, matchRatio * 0.4 + consecutiveBonus * 0.2)
    }
}