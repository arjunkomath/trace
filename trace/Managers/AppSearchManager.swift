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
    // MARK: - Constants
    private enum Constants {
        static let refreshInterval: TimeInterval = 60.0
        static let iconSize = NSSize(width: 24, height: 24)
        static let defaultSearchLimit = 10
    }
    static let shared = AppSearchManager()
    
    private var apps: [String: Application] = [:] // bundleId -> Application
    private var appsByName: [String: Set<String>] = [:] // lowercase name -> bundle IDs
    private let queue = DispatchQueue(label: "com.trace.appsearch", qos: .userInitiated, attributes: .concurrent)
    private let iconQueue = DispatchQueue(label: "com.trace.appsearch.icons", qos: .utility)
    private var fileSystemWatcher: Any?
    private var refreshTimer: Timer?
    private var isLoading = false
    
    private let applicationPaths = [
        "/Applications",
        "/System/Applications",
        "~/Applications"
    ]
    
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
    
    func searchApps(query: String, limit: Int = Constants.defaultSearchLimit) -> [Application] {
        guard !query.isEmpty else { return [] }
        
        let queryLower = query.lowercased()
        var results: [Application] = []
        var scores: [String: Double] = [:]
        
        // Fast path: exact name matches
        if let bundleIds = appsByName[queryLower] {
            for bundleId in bundleIds {
                if let app = apps[bundleId] {
                    results.append(app)
                    scores[bundleId] = 1.0
                }
            }
        }
        
        // Fuzzy matching for partial matches
        if results.count < limit {
            for (name, bundleIds) in appsByName {
                if results.count >= limit { break }
                
                if name.contains(queryLower) && !bundleIds.allSatisfy({ scores.keys.contains($0) }) {
                    let score = calculateMatchScore(query: queryLower, text: name)
                    
                    for bundleId in bundleIds {
                        if !scores.keys.contains(bundleId), let app = apps[bundleId] {
                            results.append(app)
                            scores[bundleId] = score
                            
                            if results.count >= limit { break }
                        }
                    }
                }
            }
        }
        
        // Sort by relevance score (higher is better)
        return results.sorted { app1, app2 in
            let score1 = scores[app1.bundleIdentifier] ?? 0
            let score2 = scores[app2.bundleIdentifier] ?? 0
            
            if score1 != score2 {
                return score1 > score2
            }
            
            // Secondary sort: alphabetical by display name
            return app1.displayName.localizedCaseInsensitiveCompare(app2.displayName) == .orderedAscending
        }
    }
    
    func getAppIcon(for app: Application, completion: @escaping (NSImage?) -> Void) {
        if let cachedIcon = apps[app.bundleIdentifier]?.icon {
            completion(cachedIcon)
            return
        }
        
        iconQueue.async { [weak self] in
            let icon = NSWorkspace.shared.icon(forFile: app.url.path)
            icon.size = Constants.iconSize
            
            DispatchQueue.main.async {
                self?.apps[app.bundleIdentifier]?.icon = icon
                completion(icon)
            }
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
            NSLog("Failed to scan directory %@: %@", path, error.localizedDescription)
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
            NSLog("Failed to get modification date for %@: %@", url.path, error.localizedDescription)
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
        
        NSLog("AppSearchManager: Loaded %d applications", apps.count)
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
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Constants.refreshInterval, repeats: true) { [weak self] _ in
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
        
        for textChar in textChars {
            if queryIndex < queryChars.count && queryChars[queryIndex] == textChar {
                matches += 1
                queryIndex += 1
            }
        }
        
        if matches == queryChars.count {
            return 0.5 * (Double(matches) / Double(text.count))
        }
        
        return 0
    }
}
