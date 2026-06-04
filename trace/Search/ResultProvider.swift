//
//  ResultProvider.swift
//  trace
//
//  Created by Arjun on 12/8/2025.
//

import Foundation
import os.log

protocol ResultProvider {
    var providerName: String { get }
    func getResults(for query: String, context: SearchContext) async -> [(SearchResult, Double)]
}

struct SearchContext {
    let query: String
    let queryLower: String
    let usageScores: [String: Double]
    let services: ServiceContainer
    let runningApps: Set<String>
    let eventPublisher: ResultEventPublisher
    
    init(
        query: String, 
        services: ServiceContainer, 
        runningApps: Set<String>, 
        eventPublisher: ResultEventPublisher
    ) {
        self.query = query
        self.queryLower = query.lowercased()
        self.usageScores = services.usageTracker.getAllUsageScores()
        self.services = services
        self.runningApps = runningApps
        self.eventPublisher = eventPublisher
    }
}

class SearchCoordinator {
    private let providers: [ResultProvider]
    private let logger = AppLogger.launcherView
    
    init(providers: [ResultProvider]) {
        self.providers = providers
    }
    
    func search(
        query: String, 
        services: ServiceContainer, 
        runningApps: Set<String>, 
        eventPublisher: ResultEventPublisher
    ) async -> [SearchResult] {
        let context = SearchContext(
            query: query, 
            services: services, 
            runningApps: runningApps, 
            eventPublisher: eventPublisher
        )
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var allResults: [(SearchResult, Double)] = []

        logger.debug("Search started query='\(query, privacy: .private)' providers=\(self.providers.count)")
        
        // Collect results from all providers concurrently
        await withTaskGroup(of: [(SearchResult, Double)].self) { group in
            for provider in providers {
                group.addTask { [logger] in
                    let providerStartTime = CFAbsoluteTimeGetCurrent()
                    let results = await provider.getResults(for: context.queryLower, context: context)
                    let elapsedMilliseconds = (CFAbsoluteTimeGetCurrent() - providerStartTime) * 1000
                    logger.debug(
                        "Search provider \(provider.providerName, privacy: .public) returned \(results.count) results in \(elapsedMilliseconds, format: .fixed(precision: 1))ms"
                    )
                    return results
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
        
        let finalResults = Array(sortedResults)
        let elapsedMilliseconds = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.debug("Search completed query='\(query, privacy: .private)' results=\(finalResults.count) elapsed=\(elapsedMilliseconds, format: .fixed(precision: 1))ms")

        return finalResults
    }
}

// MARK: - Helper Functions

extension ResultProvider {
    var providerName: String {
        String(describing: Self.self)
    }

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
