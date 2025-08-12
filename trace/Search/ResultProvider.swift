//
//  ResultProvider.swift
//  trace
//
//  Created by Arjun on 12/8/2025.
//

import Foundation

protocol ResultProvider {
    func getResults(for query: String, context: SearchContext) async -> [(SearchResult, Double)]
}

struct SearchContext {
    let query: String
    let queryLower: String
    let usageScores: [String: Double]
    let services: ServiceContainer
    let runningApps: Set<String>
    let updateCachedResults: @MainActor (String, @escaping (SearchResult) -> SearchResult) -> Void
    
    init(
        query: String, 
        services: ServiceContainer, 
        runningApps: Set<String>, 
        updateCachedResults: @escaping @MainActor (String, @escaping (SearchResult) -> SearchResult) -> Void
    ) {
        self.query = query
        self.queryLower = query.lowercased()
        self.usageScores = services.usageTracker.getAllUsageScores()
        self.services = services
        self.runningApps = runningApps
        self.updateCachedResults = updateCachedResults
    }
}

class SearchCoordinator {
    private let providers: [ResultProvider]
    
    init(providers: [ResultProvider]) {
        self.providers = providers
    }
    
    func search(
        query: String, 
        services: ServiceContainer, 
        runningApps: Set<String>, 
        updateCachedResults: @escaping @MainActor (String, @escaping (SearchResult) -> SearchResult) -> Void
    ) async -> [SearchResult] {
        let context = SearchContext(
            query: query, 
            services: services, 
            runningApps: runningApps, 
            updateCachedResults: updateCachedResults
        )
        
        var allResults: [(SearchResult, Double)] = []
        
        // Collect results from all providers concurrently
        await withTaskGroup(of: [(SearchResult, Double)].self) { group in
            for provider in providers {
                group.addTask {
                    await provider.getResults(for: context.queryLower, context: context)
                }
            }
            
            for await providerResults in group {
                allResults.append(contentsOf: providerResults)
            }
        }
        
        // Sort all results by score and limit
        let sortedResults = allResults
            .sorted { $0.1 > $1.1 }
            .prefix(10)
            .map { $0.0 }
        
        return Array(sortedResults)
    }
}

// MARK: - Helper Functions

extension ResultProvider {
    func calculateUnifiedScore(matchScore: Double, usageScore: Double, threshold: Double = 0.3) -> Double? {
        guard matchScore > threshold else { return nil }
        let normalizedUsage = normalizeUsageScore(usageScore)
        return (matchScore * 0.8) + (normalizedUsage * 0.2)
    }
    
    func normalizeUsageScore(_ score: Double) -> Double {
        if score <= 0 { return 0 }
        if score >= 50 { return 1.0 }
        return min(log10(score + 1) / log10(51), 1.0)
    }
    
    func matchesSearchTerms(query: String, terms: [String]) -> Double {
        return FuzzyMatcher.matchBest(query: query, terms: terms)
    }
}