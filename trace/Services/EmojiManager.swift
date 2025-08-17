//
//  EmojiManager.swift
//  trace
//

import Foundation
import os.log

class EmojiManager: ObservableObject {
    static let shared = EmojiManager()
    
    private let logger = AppLogger.emojiManager
    
    @Published private(set) var emojis: [Emoji] = []
    @Published private(set) var isLoaded = false
    
    private var emojisByCategory: [EmojiCategory: [Emoji]] = [:]
    private var emojiSearchCache: [String: [Emoji]] = [:]
    
    private init() {
        // Cache will be loaded during app initialization
    }
    
    // MARK: - Initialization
    
    /// Loads and caches all emojis on app launch
    func loadEmojis() {
        logger.info("Loading emoji database...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Load emojis from database
            let allEmojis = EmojiDatabase.allEmojis
            
            // Group by category for faster lookup
            var categorizedEmojis: [EmojiCategory: [Emoji]] = [:]
            for category in EmojiCategory.allCases {
                categorizedEmojis[category] = allEmojis.filter { $0.category == category }
            }
            
            let loadTime = CFAbsoluteTimeGetCurrent() - startTime
            
            DispatchQueue.main.async {
                self?.emojis = allEmojis
                self?.emojisByCategory = categorizedEmojis
                self?.isLoaded = true
                self?.logger.info("Loaded \(allEmojis.count) emojis in \(String(format: "%.2f", loadTime * 1000))ms")
            }
        }
    }
    
    // MARK: - Search
    
    /// Searches emojis by name and keywords
    func searchEmojis(query: String) -> [Emoji] {
        guard !query.isEmpty, isLoaded else { return [] }
        
        let lowercaseQuery = query.lowercased()
        
        // Check cache first
        if let cached = emojiSearchCache[lowercaseQuery] {
            return cached
        }
        
        let results = emojis.filter { emoji in
            emoji.searchableText.contains(lowercaseQuery)
        }.sorted { emoji1, emoji2 in
            // Prioritize exact name matches, then keyword matches
            let name1Match = emoji1.name.lowercased().hasPrefix(lowercaseQuery)
            let name2Match = emoji2.name.lowercased().hasPrefix(lowercaseQuery)
            
            if name1Match && !name2Match {
                return true
            } else if !name1Match && name2Match {
                return false
            }
            
            // If both or neither have name matches, sort by name length (shorter first)
            return emoji1.name.count < emoji2.name.count
        }
        
        // Cache the results
        emojiSearchCache[lowercaseQuery] = results
        
        return results
    }
    
    /// Gets emojis by category
    func getEmojis(in category: EmojiCategory) -> [Emoji] {
        return emojisByCategory[category] ?? []
    }
    
    /// Gets emoji by ID
    func getEmoji(by id: String) -> Emoji? {
        return emojis.first { $0.id == id }
    }
    
    // MARK: - Query Detection
    
    /// Determines if a query should trigger emoji search
    static func shouldTriggerEmojiSearch(for query: String) -> Bool {
        let lowercaseQuery = query.lowercased()
        
        // Trigger on colon prefix (like Slack/Discord)
        if query.hasPrefix(":") && query.count > 1 {
            return true
        }
        
        // Trigger on "emoji" keyword
        if lowercaseQuery.hasPrefix("emoji ") && lowercaseQuery.count > 6 {
            return true
        }
        
        // Trigger on common emoji-related terms
        let emojiTriggers = ["emoji", "emoticon", "smiley", "face"]
        return emojiTriggers.contains { trigger in
            lowercaseQuery.hasPrefix(trigger + " ") || lowercaseQuery == trigger
        }
    }
    
    /// Extracts the actual search term from an emoji query
    static func extractSearchTerm(from query: String) -> String {
        let lowercaseQuery = query.lowercased()
        
        // Remove colon prefix
        if query.hasPrefix(":") {
            return String(query.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        
        // Remove emoji prefix
        if lowercaseQuery.hasPrefix("emoji ") {
            return String(query.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        }
        
        // Remove other trigger words
        let triggers = ["emoticon ", "smiley ", "face "]
        for trigger in triggers {
            if lowercaseQuery.hasPrefix(trigger) {
                return String(query.dropFirst(trigger.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // If it's just the trigger word, return empty to show popular emojis
        let triggerWords = ["emoji", "emoticon", "smiley", "face"]
        if triggerWords.contains(lowercaseQuery) {
            return ""
        }
        
        return query
    }
    
    /// Gets popular emojis when no specific search term is provided
    func getPopularEmojis() -> [Emoji] {
        // Return commonly used emojis
        let popularIds = [
            "grinning_face", "face_with_tears_of_joy", "smiling_face_with_heart_eyes",
            "smiling_face_with_smiling_eyes", "winking_face", "thumbs_up", "red_heart",
            "fire", "ok_hand", "clapping_hands", "party_popper", "thinking_face"
        ]
        
        return popularIds.compactMap { id in
            emojis.first { $0.id == id }
        }
    }
    
    // MARK: - Memory Management
    
    /// Clears search cache to free memory if needed
    func clearSearchCache() {
        emojiSearchCache.removeAll()
        logger.debug("Cleared emoji search cache")
    }
}

// MARK: - Logger Extension

extension AppLogger {
    static let emojiManager = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.trace.app",
        category: "EmojiManager"
    )
}