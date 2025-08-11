//
//  AppSearchManager.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import Foundation
import AppKit
import Cocoa
import Ifrit

class AppSearchManager: ObservableObject {
    
    private let logger = AppLogger.appSearchManager
    private weak var usageTracker: UsageTracker?
    
    private var apps: [String: Application] = [:] // bundleId -> Application
    private var appsByName: [String: Set<String>] = [:] // lowercase name -> bundle IDs
    private let iconQueue = DispatchQueue(label: "com.trace.appsearch.icons", qos: .utility)
    private var iconCache: [String: NSImage] = [:] // bundleId -> NSImage cache
    private let iconCacheQueue = DispatchQueue(label: "com.trace.appsearch.iconcache", attributes: .concurrent)
    private var fileSystemWatcher: Any?
    private var refreshTimer: Timer?
    private var isLoading = false
    
    private let applicationPaths = AppConstants.Paths.applications
    
    // Ifrit fuzzy search instance with optimized settings
    private let fuse = Fuse(
        location: 0,
        distance: 100,
        threshold: 0.35,  // More lenient for typos
        isCaseSensitive: false
    )
    
    init(usageTracker: UsageTracker? = nil) {
        self.usageTracker = usageTracker
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
        
        // Get usage scores for all apps
        let usageScores = usageTracker?.getAllUsageScores() ?? [:]
        
        // Use Ifrit's weighted multi-field search for better results
        let allApps = Array(apps.values)
        
        // Search across all apps using Ifrit's weighted properties
        let searchResults = fuse.searchSync(query, in: allApps, by: \Application.properties)
        
        // Process search results
        for result in searchResults {
            guard result.index < allApps.count else { continue }
            let app = allApps[result.index]
            
            // Convert Ifrit score (0 = perfect, 1 = no match) to our system (1 = perfect, 0 = no match)
            let matchScore = 1.0 - result.diffScore
            
            // Skip poor matches
            guard matchScore > 0.2 else { continue }
            
            // Combine with usage score
            let usageScore = usageScores[app.bundleIdentifier] ?? 0.0
            let normalizedUsage = normalizeUsageScore(usageScore)
            
            // Weight: 60% match quality, 40% usage frequency - give more weight to usage
            let combinedScore = (matchScore * 0.6) + (normalizedUsage * 0.4)
            
            scoredResults.append((app, combinedScore))
            
            // Limit results for performance
            if scoredResults.count >= limit * 2 {
                break
            }
        }
        
        // Sort by combined score and return top results
        return scoredResults
            .sorted { $0.1 > $1.1 || ($0.1 == $1.1 && $0.0.displayName.localizedCaseInsensitiveCompare($1.0.displayName) == .orderedAscending) }
            .prefix(limit)
            .map { $0.0 }
    }
    
    @MainActor
    func getAppIcon(for app: Application) async -> NSImage? {
        let bundleId = app.bundleIdentifier
        
        // Check cache first (concurrent read)
        let cachedIcon = await withCheckedContinuation { continuation in
            iconCacheQueue.async { [weak self] in
                let icon = self?.iconCache[bundleId]
                continuation.resume(returning: icon)
            }
        }
        
        if let cachedIcon = cachedIcon {
            return cachedIcon
        }
        
        // Load icon asynchronously
        return await withCheckedContinuation { continuation in
            iconQueue.async { [weak self] in
                let icon = NSWorkspace.shared.icon(forFile: app.url.path)
                icon.size = AppConstants.Search.iconSize
                
                // Store in concurrent cache
                self?.iconCacheQueue.async(flags: .barrier) {
                    self?.iconCache[bundleId] = icon
                }
                
                // Also update the app's icon for legacy compatibility
                Task { @MainActor in
                    self?.apps[bundleId]?.icon = icon
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
        
        Task { [weak self] in
            await self?.discoverApps()
        }
    }
    
    private func discoverApps() async {
        var discoveredApps: [String: Application] = [:]
        
        // Use TaskGroup for concurrent directory scanning
        await withTaskGroup(of: [Application].self) { group in
            for path in applicationPaths {
                group.addTask { [weak self] in
                    let expandedPath = NSString(string: path).expandingTildeInPath
                    
                    // Check if directory exists before scanning
                    let fileManager = FileManager.default
                    guard fileManager.fileExists(atPath: expandedPath) else {
                        self?.logger.debug("Directory does not exist, skipping: \(expandedPath)")
                        return []
                    }
                    
                    // Adjust max depth based on directory type
                    let maxDepth = self?.getMaxDepthForPath(expandedPath) ?? 2
                    return await self?.scanDirectory(at: expandedPath, depth: 0, maxDepth: maxDepth) ?? []
                }
            }
            
            // Collect results from all tasks
            for await apps in group {
                for app in apps {
                    discoveredApps[app.bundleIdentifier] = app
                }
            }
        }
        
        await MainActor.run { [weak self] in
            self?.updateAppsCache(discoveredApps)
            self?.isLoading = false
        }
    }
    
    private func getMaxDepthForPath(_ path: String) -> Int {
        // Limit depth for certain directories to improve performance
        if path.contains("/usr/local") || path.contains("/opt") {
            return 3 // These might have apps deeper in the hierarchy
        } else if path.contains("Application Support") {
            return 1 // Usually apps are directly in Application Support folders
        } else if path.contains("CoreServices") {
            return 2 // CoreServices has some nested folders
        }
        return 2 // Default depth
    }
    
    private func scanDirectory(at path: String) async -> [Application] {
        return await scanDirectory(at: path, depth: 0, maxDepth: 2)
    }
    
    private func scanDirectory(at path: String, depth: Int, maxDepth: Int) async -> [Application] {
        let fileManager = FileManager.default
        var apps: [Application] = []
        
        // Prevent scanning too deeply to avoid performance issues
        guard depth <= maxDepth else { return apps }
        
        // Skip certain directories that shouldn't contain apps or might cause issues
        let skipPatterns = ["node_modules", ".git", ".Trash", "Caches", "Logs", "tmp"]
        for pattern in skipPatterns {
            if path.contains(pattern) {
                return apps
            }
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: path),
                includingPropertiesForKeys: [.isApplicationKey, .contentModificationDateKey, .isDirectoryKey],
                options: [] // Don't skip hidden files - some system apps are symlinks that appear "hidden"
            )
            
            for url in contents {
                if url.pathExtension == "app" {
                    if let app = createApp(from: url) {
                        apps.append(app)
                    }
                } else if depth < maxDepth {
                    // Check if it's a directory and scan recursively
                    let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
                    if resourceValues?.isDirectory == true && !url.lastPathComponent.hasPrefix(".") {
                        // Skip directories that are unlikely to contain apps
                        let dirName = url.lastPathComponent.lowercased()
                        if !dirName.contains("cache") && !dirName.contains("log") && !dirName.contains("temp") {
                            // Recursively scan subdirectories
                            let subdirectoryApps = await scanDirectory(at: url.path, depth: depth + 1, maxDepth: maxDepth)
                            apps.append(contentsOf: subdirectoryApps)
                        }
                    }
                }
            }
        } catch {
            // Only log errors for important directories, not for permission-denied system directories
            if !error.localizedDescription.contains("Operation not permitted") {
                logger.debug("Failed to scan directory \(path): \(error.localizedDescription)")
            }
        }
        
        return apps
    }
    
    private func createApp(from url: URL) -> Application? {
        // Resolve symlinks first - important for system apps like Safari
        let resolvedURL = url.resolvingSymlinksInPath()
        
        guard let bundle = Bundle(url: resolvedURL) else {
            logger.debug("Failed to create Bundle for: \(resolvedURL.path) (original: \(url.path))")
            return nil
        }
        
        guard let bundleId = bundle.bundleIdentifier else {
            logger.debug("No bundle identifier for: \(url.path)")
            return nil
        }
        
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
            url: url, // Use original URL for display purposes
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
        // More aggressive normalization that better rewards frequently used items
        // Usage of 1 = 0.1, Usage of 5 = 0.35, Usage of 10 = 0.55, Usage of 20 = 0.75, Usage of 50+ = 1.0
        if score <= 0 { return 0 }
        if score >= 50 { return 1.0 }
        
        // Use logarithmic scale for better differentiation
        return min(log10(score + 1) / log10(51), 1.0)
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
    
    
    // MARK: - Lifecycle Management
    
    func shutdown() {
        stopFileSystemWatcher()
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
