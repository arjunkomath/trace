//
//  FuzzyMatcher.swift
//  trace
//
//  Created by Arjun on 9/8/2025.
//

import Foundation
import Ifrit

/// Shared fuzzy matching utility with consistent scoring across the app
struct FuzzyMatcher {
    
    private static let fuse = Fuse(
        location: 0,
        distance: 100,
        threshold: 0.4,
        isCaseSensitive: false
    )
    
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
            return 0.95
        }
        
        // Use Ifrit for fuzzy matching
        if let result = fuse.searchSync(query, in: text) {
            // Ifrit returns a score where lower is better (0 = perfect match)
            // Convert to our scoring system where higher is better (1.0 = perfect match)
            let normalizedScore = 1.0 - result.score
            
            // Apply a minimum threshold to filter out poor matches
            if normalizedScore < 0.3 {
                return 0.0
            }
            
            // Scale the score to our range, giving fuzzy matches up to 0.85
            return normalizedScore * 0.85
        }
        
        return 0.0
    }
    
    /// Matches against multiple search terms and returns the best score
    /// - Parameters:
    ///   - query: The search query
    ///   - terms: Array of terms to match against
    /// - Returns: The highest matching score from all terms
    static func matchBest(query: String, terms: [String]) -> Double {
        // Use Ifrit's built-in array search for better performance
        let results = fuse.searchSync(query, in: terms)
        
        if let bestResult = results.first {
            let normalizedScore = 1.0 - bestResult.diffScore
            
            // Check for exact or prefix matches in the original terms
            let queryLower = query.lowercased()
            for term in terms {
                let termLower = term.lowercased()
                if termLower == queryLower {
                    return 1.0
                }
                if termLower.hasPrefix(queryLower) {
                    return 0.95
                }
            }
            
            // Apply minimum threshold
            if normalizedScore < 0.3 {
                return 0.0
            }
            
            return normalizedScore * 0.85
        }
        
        return 0.0
    }
}