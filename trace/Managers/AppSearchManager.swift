//
//  AppSearchManager.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import Foundation
import AppKit
import Cocoa

class AppSearchManager: ObservableObject {
    
    private let logger = AppLogger.appSearchManager
    static let shared = AppSearchManager()
    
    private var apps: [String: Application] = [:] // bundleId -> Application
    private var appsByName: [String: Set<String>] = [:] // lowercase name -> bundle IDs
    private let queue = DispatchQueue(label: "com.trace.appsearch", qos: .userInitiated, attributes: .concurrent)
    private let iconQueue = DispatchQueue(label: "com.trace.appsearch.icons", qos: .utility)
    private var fileSystemWatcher: Any?
    private var refreshTimer: Timer?
    private var isLoading = false
    
    private let applicationPaths = AppConstants.Paths.applications
    
    private init() {
        loadAppsInBackground()
        setupFileSystemWatcher()
    }
    
    deinit {
        stopFileSystemWatcher()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Public API
    
    func searchApps(query: String, limit: Int = AppConstants.Search.defaultLimit) -> [Application] {
        guard !query.isEmpty else { return [] }
        
        let queryLower = query.lowercased()
        var scoredResults: [(Application, Double)] = []
        var processedBundleIds = Set<String>()
        
        // Get usage scores for all apps
        let usageScores = UsageTracker.shared.getAllUsageScores()
        
        // Fast path: exact name matches
        if let bundleIds = appsByName[queryLower] {
            for bundleId in bundleIds {
                if let app = apps[bundleId] {
                    let matchScore = 1.0
                    let usageScore = usageScores[bundleId] ?? 0.0
                    let normalizedUsage = normalizeUsageScore(usageScore)
                    let combinedScore = (matchScore * 0.6) + (normalizedUsage * 0.4)
                    scoredResults.append((app, combinedScore))
                    processedBundleIds.insert(bundleId)
                }
            }
        }
        
        // Early return if we have enough exact matches
        if scoredResults.count >= limit {
            return Array(scoredResults
                .sorted { $0.1 > $1.1 }
                .prefix(limit)
                .map { $0.0 })
        }
        
        // Enhanced fuzzy matching with keyword and description support
        for (name, bundleIds) in appsByName {
            let matchScore = calculateMatchScore(query: queryLower, text: name)
            
            // Only include results with meaningful scores
            if matchScore > 0.1 {
                for bundleId in bundleIds where !processedBundleIds.contains(bundleId) {
                    if let app = apps[bundleId] {
                        // Calculate enhanced match score considering all searchable content
                        let enhancedMatchScore = calculateEnhancedMatchScore(query: queryLower, app: app, baseScore: matchScore)
                        
                        let usageScore = usageScores[bundleId] ?? 0.0
                        let normalizedUsage = normalizeUsageScore(usageScore)
                        let combinedScore = (enhancedMatchScore * 0.6) + (normalizedUsage * 0.4)
                        scoredResults.append((app, combinedScore))
                        processedBundleIds.insert(bundleId)
                        
                        if scoredResults.count >= limit * 3 { // Get more for better sorting
                            break
                        }
                    }
                }
            }
            
            if scoredResults.count >= limit * 3 {
                break
            }
        }
        
        // Sort by combined score (match + usage) and return top results
        return scoredResults
            .sorted { $0.1 > $1.1 || ($0.1 == $1.1 && $0.0.displayName.localizedCaseInsensitiveCompare($1.0.displayName) == .orderedAscending) }
            .prefix(limit)
            .map { $0.0 }
    }
    
    @MainActor
    func getAppIcon(for app: Application) async -> NSImage? {
        // Return cached icon if available
        if let cachedIcon = apps[app.bundleIdentifier]?.icon {
            return cachedIcon
        }
        
        // Load icon asynchronously
        return await withCheckedContinuation { continuation in
            iconQueue.async { [weak self] in
                let icon = NSWorkspace.shared.icon(forFile: app.url.path)
                icon.size = AppConstants.Search.iconSize
                
                Task { @MainActor in
                    self?.apps[app.bundleIdentifier]?.icon = icon
                    continuation.resume(returning: icon)
                }
            }
        }
    }
    
    // Legacy completion-based method for backward compatibility
    func getAppIcon(for app: Application, completion: @escaping (NSImage?) -> Void) {
        Task {
            let icon = await getAppIcon(for: app)
            completion(icon)
        }
    }
    
    func launchApp(_ app: Application) {
        NSWorkspace.shared.open(app.url)
    }
    
    func getApp(by bundleIdentifier: String) -> Application? {
        return apps[bundleIdentifier]
    }
    
    // MARK: - App Discovery
    
    private func loadAppsInBackground() {
        guard !isLoading else { return }
        isLoading = true
        
        queue.async { [weak self] in
            self?.discoverApps()
        }
    }
    
    private func discoverApps() {
        let group = DispatchGroup()
        var discoveredApps: [String: Application] = [:]
        let lock = NSLock()
        
        for path in applicationPaths {
            group.enter()
            
            queue.async {
                defer { group.leave() }
                
                let expandedPath = NSString(string: path).expandingTildeInPath
                let apps = self.scanDirectory(at: expandedPath)
                
                lock.lock()
                for app in apps {
                    discoveredApps[app.bundleIdentifier] = app
                }
                lock.unlock()
            }
        }
        
        group.notify(queue: DispatchQueue.main) { [weak self] in
            self?.updateAppsCache(discoveredApps)
            self?.isLoading = false
        }
    }
    
    private func scanDirectory(at path: String) -> [Application] {
        let fileManager = FileManager.default
        var apps: [Application] = []
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.isApplicationKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            for url in contents {
                guard url.pathExtension == "app" else { continue }
                
                if let app = createApp(from: url) {
                    apps.append(app)
                }
            }
        } catch {
            logger.error("Failed to scan directory \(path): \(error.localizedDescription)")
        }
        
        return apps
    }
    
    private func createApp(from url: URL) -> Application? {
        guard let bundle = Bundle(url: url) else { return nil }
        guard let bundleId = bundle.bundleIdentifier else { return nil }
        
        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        
        let name = url.deletingPathExtension().lastPathComponent
        
        // Extract description and keywords for better search
        let description = extractAppDescription(from: bundle)
        let keywords = extractAppKeywords(from: bundle, name: name, displayName: displayName)
        
        let lastModified: Date
        do {
            let resourceValues = try url.resourceValues(forKeys: [.contentModificationDateKey])
            lastModified = resourceValues.contentModificationDate ?? Date.distantPast
        } catch {
            lastModified = Date.distantPast
            logger.warning("Failed to get modification date for \(url.path): \(error.localizedDescription)")
        }
        
        return Application(
            id: bundleId,
            name: name,
            displayName: displayName,
            url: url,
            bundleIdentifier: bundleId,
            lastModified: lastModified,
            description: description,
            keywords: keywords,
            icon: nil
        )
    }
    
    private func extractAppDescription(from bundle: Bundle) -> String? {
        // Try various description keys from Info.plist
        let description = bundle.object(forInfoDictionaryKey: "CFBundleGetInfoString") as? String
            ?? bundle.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        
        // Clean up the description if found
        return description?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractAppKeywords(from bundle: Bundle, name: String, displayName: String) -> [String] {
        var keywords: Set<String> = []
        
        // Add basic names
        keywords.insert(name.lowercased())
        keywords.insert(displayName.lowercased())
        
        // Add bundle identifier components once
        if let bundleId = bundle.bundleIdentifier {
            let components = bundleId.components(separatedBy: ".").compactMap { component -> String? in
                let lowercased = component.lowercased()
                return (!lowercased.isEmpty && lowercased != "com" && lowercased != "app") ? lowercased : nil
            }
            keywords.formUnion(components)
        }
        
        // Add category-based keywords
        if let category = bundle.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String {
            keywords.formUnion(categoryToKeywords(category))
        }
        
        return Array(keywords).filter { !$0.isEmpty }
    }
    
    private func categoryToKeywords(_ category: String) -> [String] {
        let categoryKeywords: [String: [String]] = [
            "public.app-category.utilities": ["utility", "utilities", "tool", "tools"],
            "public.app-category.productivity": ["productivity", "work", "office"],
            "public.app-category.graphics-design": ["design", "graphics", "art", "creative"],
            "public.app-category.developer-tools": ["developer", "development", "code", "programming"],
            "public.app-category.entertainment": ["entertainment", "fun", "media"],
            "public.app-category.lifestyle": ["lifestyle", "personal"],
            "public.app-category.business": ["business", "enterprise", "work"],
            "public.app-category.education": ["education", "learning", "study"],
            "public.app-category.finance": ["finance", "money", "banking"],
            "public.app-category.games": ["games", "gaming", "play"],
            "public.app-category.music": ["music", "audio", "sound"],
            "public.app-category.photo-video": ["photo", "video", "media", "camera"],
            "public.app-category.social-networking": ["social", "network", "communication"],
            "public.app-category.travel": ["travel", "maps", "navigation"]
        ]
        
        return categoryKeywords[category] ?? []
    }
    
    private func normalizeUsageScore(_ score: Double) -> Double {
        return min(sqrt(score) / 10.0, 1.0)
    }
    
    private func updateAppsCache(_ newApps: [String: Application]) {
        apps = newApps
        rebuildNameIndex()
        
        logger.info("Loaded \(self.apps.count) applications")
    }
    
    private func rebuildNameIndex() {
        appsByName.removeAll()
        
        for (bundleId, app) in apps {
            var searchableTerms = Set<String>()
            
            // Add basic names
            searchableTerms.insert(app.name.lowercased())
            searchableTerms.insert(app.displayName.lowercased())
            
            // Add keywords to searchable terms
            searchableTerms.formUnion(app.keywords)
            
            // Add description words if available (limit to prevent index explosion)
            if let description = app.description {
                let descriptionWords = description.lowercased()
                    .components(separatedBy: .whitespacesAndNewlines)
                    .filter { $0.count > 2 }
                    .prefix(5) // Limit to first 5 meaningful words
                searchableTerms.formUnion(descriptionWords)
            }
            
            // Create index entries for all searchable terms
            for term in searchableTerms.filter({ !$0.isEmpty }) {
                appsByName[term, default: Set<String>()].insert(bundleId)
                
                // Limited prefix indexing to reduce memory usage
                if term.count > 3 && term.count <= 8 {
                    for i in 3...min(term.count, 6) { // Reduced from 10 to 6
                        let prefix = String(term.prefix(i))
                        appsByName[prefix, default: Set<String>()].insert(bundleId)
                    }
                }
            }
        }
    }
    
    // MARK: - File System Monitoring
    
    private func setupFileSystemWatcher() {
        // For now, use timer-based monitoring for reliability
        // FSEvents can be implemented later if needed
        setupTimerBasedWatcher()
    }
    
    private func setupTimerBasedWatcher() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.Search.refreshInterval, repeats: true) { [weak self] _ in
            self?.loadAppsInBackground()
        }
    }
    
    private func stopFileSystemWatcher() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    // MARK: - Search Scoring
    
    private func calculateEnhancedMatchScore(query: String, app: Application, baseScore: Double) -> Double {
        var bestScore = baseScore
        
        // Check direct name matches (highest priority)
        let nameScore = max(
            calculateMatchScore(query: query, text: app.name.lowercased()),
            calculateMatchScore(query: query, text: app.displayName.lowercased())
        )
        bestScore = max(bestScore, nameScore)
        
        // Check keyword matches (high priority)
        for keyword in app.keywords {
            let keywordScore = calculateMatchScore(query: query, text: keyword) * 0.8 // Slightly lower than name
            bestScore = max(bestScore, keywordScore)
        }
        
        // Check description matches (medium priority) - already indexed, so skip expensive reprocessing
        // Description words are already included in the search index for better performance
        
        return bestScore
    }
    
    private func calculateMatchScore(query: String, text: String) -> Double {
        guard !query.isEmpty && !text.isEmpty else { return 0 }
        
        // Exact match gets highest score
        if text == query {
            return 1.0
        }
        
        // Prefix match gets high score
        if text.hasPrefix(query) {
            return 0.9
        }
        
        // Contains match gets medium score
        if text.contains(query) {
            return 0.7
        }
        
        // Fuzzy match using simple character-based scoring
        return fuzzyMatchScore(query: query, text: text)
    }
    
    private func fuzzyMatchScore(query: String, text: String) -> Double {
        let queryChars = Array(query)
        let textChars = Array(text)
        
        var queryIndex = 0
        var matches = 0
        var consecutiveMatches = 0
        var maxConsecutive = 0
        var lastMatchIndex = -1
        
        for (textIndex, textChar) in textChars.enumerated() {
            if queryIndex < queryChars.count && queryChars[queryIndex] == textChar {
                matches += 1
                queryIndex += 1
                
                // Track consecutive matches for bonus scoring
                if textIndex == lastMatchIndex + 1 {
                    consecutiveMatches += 1
                } else {
                    consecutiveMatches = 1
                }
                maxConsecutive = max(maxConsecutive, consecutiveMatches)
                lastMatchIndex = textIndex
            }
        }
        
        // All query characters must be found
        guard matches == queryChars.count else { return 0 }
        
        // Base score from match ratio
        let matchRatio = Double(matches) / Double(textChars.count)
        
        // Bonus for consecutive matches (rewards word boundaries and prefixes)
        let consecutiveBonus = Double(maxConsecutive) / Double(queryChars.count) * 0.3
        
        // Bonus for early matches (rewards prefix matches)
        let earlyMatchBonus = lastMatchIndex < textChars.count / 2 ? 0.1 : 0
        
        return min(0.6, matchRatio * 0.4 + consecutiveBonus + earlyMatchBonus)
    }
}
