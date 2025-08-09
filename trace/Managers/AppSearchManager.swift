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
                    // Combine match score with usage score (70% match, 30% usage)
                    let combinedScore = (matchScore * 0.7) + (min(usageScore / 100.0, 1.0) * 0.3)
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
        
        // Fuzzy matching for partial matches - improved algorithm
        for (name, bundleIds) in appsByName {
            let matchScore = calculateMatchScore(query: queryLower, text: name)
            
            // Only include results with meaningful scores
            if matchScore > 0.1 {
                for bundleId in bundleIds where !processedBundleIds.contains(bundleId) {
                    if let app = apps[bundleId] {
                        let usageScore = usageScores[bundleId] ?? 0.0
                        // Combine match score with usage score (70% match, 30% usage)
                        let combinedScore = (matchScore * 0.7) + (min(usageScore / 100.0, 1.0) * 0.3)
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
            icon: nil
        )
    }
    
    private func updateAppsCache(_ newApps: [String: Application]) {
        apps = newApps
        rebuildNameIndex()
        
        logger.info("Loaded \(self.apps.count) applications")
    }
    
    private func rebuildNameIndex() {
        appsByName.removeAll()
        
        for (bundleId, app) in apps {
            let names = [
                app.name.lowercased(),
                app.displayName.lowercased()
            ]
            
            for name in Set(names) {
                if appsByName[name] == nil {
                    appsByName[name] = Set<String>()
                }
                appsByName[name]?.insert(bundleId)
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
