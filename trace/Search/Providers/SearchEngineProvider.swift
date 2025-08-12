//
//  SearchEngineProvider.swift
//  trace
//
//  Created by Arjun on 12/8/2025.
//

import Foundation

class SearchEngineProvider: ResultProvider {
    
    func getResults(for query: String, context: SearchContext) async -> [(SearchResult, Double)] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }
        
        var searchEngines: [SearchResult] = []
        
        // Google Search
        if let googleUrl = URL(string: "https://www.google.com/search?q=\(encodedQuery)") {
            let googleAction = URLCommandAction(
                id: "com.trace.search.google",
                displayName: "Search Google",
                iconName: "globe",
                url: googleUrl
            )
            searchEngines.append(SearchResult(
                title: "Search Google for '\(query)'",
                subtitle: "Open in browser",
                icon: .system("globe"),
                type: .suggestion,
                category: .web,
                shortcut: nil,
                lastUsed: nil,
                commandId: "com.trace.search.google",
                accessory: nil,
                commandAction: googleAction
            ))
        }
        
        // DuckDuckGo Search
        if let duckUrl = URL(string: "https://duckduckgo.com/?q=\(encodedQuery)") {
            let duckAction = URLCommandAction(
                id: "com.trace.search.duckduckgo",
                displayName: "Search DuckDuckGo",
                iconName: "shield",
                url: duckUrl
            )
            searchEngines.append(SearchResult(
                title: "Search DuckDuckGo for '\(query)'",
                subtitle: "Privacy-focused search",
                icon: .system("shield"),
                type: .suggestion,
                category: .web,
                shortcut: nil,
                lastUsed: nil,
                commandId: "com.trace.search.duckduckgo",
                accessory: nil,
                commandAction: duckAction
            ))
        }
        
        // Perplexity Search
        if let perplexityUrl = URL(string: "https://www.perplexity.ai/search?q=\(encodedQuery)") {
            let perplexityAction = URLCommandAction(
                id: "com.trace.search.perplexity",
                displayName: "Search Perplexity",
                iconName: "brain.head.profile",
                url: perplexityUrl
            )
            searchEngines.append(SearchResult(
                title: "Search Perplexity for '\(query)'",
                subtitle: "AI-powered search",
                icon: .system("brain.head.profile"),
                type: .suggestion,
                category: .web,
                shortcut: nil,
                lastUsed: nil,
                commandId: "com.trace.search.perplexity",
                accessory: nil,
                commandAction: perplexityAction
            ))
        }
        
        // Search engines always get low priority (0.1) so they appear at the bottom
        return searchEngines.map { ($0, 0.1) }
    }
}