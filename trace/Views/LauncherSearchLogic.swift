//
//  LauncherSearchLogic.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI
import AppKit

extension LauncherView {
    
    // MARK: - Data
    
    var hasResults: Bool {
        !searchText.isEmpty && !results.isEmpty
    }
    
    var results: [SearchResult] {
        guard !searchText.isEmpty else { 
            return []
        }
        return cachedResults
    }
    
    // MARK: - Scoring Utilities
    
    
    /// Unified scoring function for consistent scoring across all result types
    func calculateUnifiedScore(matchScore: Double, usageScore: Double, threshold: Double = 0.3) -> Double? {
        guard matchScore > threshold else { return nil }
        let normalizedUsage = normalizeUsageScore(usageScore)
        return (matchScore * 0.8) + (normalizedUsage * 0.2)
    }
    
    
    /// Create a system command result with common parameters
    func createSystemCommand(
        commandId: String,
        title: String,
        subtitle: String,
        icon: String,
        category: ResultCategory? = nil,
        shortcut: KeyboardShortcut? = nil,
        operation: @escaping () -> Void
    ) -> SearchResult {
        let commandAction = InstantCommandAction(
            id: commandId,
            displayName: title,
            iconName: icon,
            operation: operation
        )
        
        return SearchResult(
            title: title,
            subtitle: subtitle,
            icon: .system(icon),
            type: .command,
            category: category,
            shortcut: shortcut,
            lastUsed: nil,
            commandId: commandId,
            accessory: nil,
            commandAction: commandAction
        )
    }
    
    /// Standard action wrapper that tracks usage and closes launcher
    func createStandardAction(commandId: String, customAction: @escaping () -> Void) -> () -> Void {
        return { [services, self] in
            services.usageTracker.recordUsage(for: commandId, type: UsageType.command)
            
            // Ensure all UI operations happen on main thread
            DispatchQueue.main.async {
                customAction()
                self.clearSearch()
                self.onClose()
            }
        }
    }
    
    
    // MARK: - Search Functions
    
    /// Perform search calculations in background thread
    func performBackgroundSearch(for query: String) {
        // Cancel any existing search
        currentSearchTask?.cancel()
        
        currentSearchTask = Task.detached {
            guard !Task.isCancelled else { return }
            
            let searchResults = await self.calculateSearchResults(query: query)
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                // Only update if the query is still current
                if self.searchText == query {
                    self.cachedResults = searchResults
                }
            }
        }
    }
    
    /// Calculate search results on background thread
    func calculateSearchResults(query: String) async -> [SearchResult] {
        let searchLower = query.lowercased()
        var scoredResults: [(SearchResult, Double)] = []
        
        // Cache expensive operations once per search
        let usageScores = services.usageTracker.getAllUsageScores()
        let runningApps = services.appSearchManager.getRunningAppBundleIds()
        
        // Get apps with their pre-calculated scores from AppSearchManager
        let apps = services.appSearchManager.searchApps(query: query, limit: 30)
        
        for app in apps {
            // AppSearchManager already provides scored results, so we trust those scores
            // and only need to build the SearchResult objects
            
            // Get hotkey for this app (direct lookup for now - optimize in Phase 2)
            let shortcut: KeyboardShortcut? = {
                if let hotkeyString = services.appHotkeyManager.getHotkey(for: app.bundleIdentifier), !hotkeyString.isEmpty {
                    return KeyboardShortcut(keyCombo: hotkeyString)
                }
                return nil
            }()
            
            // Check if app is running (from cached lookup)
            let accessory: SearchResultAccessory? = runningApps.contains(app.bundleIdentifier) ? .runningIndicator : nil
            
            let launchAction = InstantCommandAction(
                id: app.bundleIdentifier,
                displayName: "Launch \(app.displayName)",
                iconName: nil,
                operation: { [services] in
                    services.appSearchManager.launchApp(app)
                }
            )
            
            let result = SearchResult(
                title: app.displayName,
                subtitle: nil,
                icon: .app(app.bundleIdentifier),
                type: .application,
                category: .applications,
                shortcut: shortcut,
                lastUsed: nil,
                commandId: app.bundleIdentifier,
                accessory: accessory,
                commandAction: launchAction
            )
            
            // Calculate proper fuzzy match score for consistency with commands
            let matchScore = FuzzyMatcher.match(query: searchLower, text: app.displayName.lowercased())
            let usageScore = usageScores[app.bundleIdentifier] ?? 0.0
            
            if let combinedScore = calculateUnifiedScore(matchScore: matchScore, usageScore: usageScore) {
                scoredResults.append((result, combinedScore))
            }
        }
        
        // Add system commands with fuzzy matching and usage scores
        var systemCommands: [(SearchResult, Double)] = []
        
        // Settings command
        let settingsMatchScore = matchesSearchTerms(query: searchLower, terms: [
            "trace settings", "settings", "preferences", "config", "configuration", 
            "trace", "setup", "options", "prefs", "configure", "hotkeys"
        ])
        let settingsId = "com.trace.command.settings"
        let settingsUsageScore = usageScores[settingsId] ?? 0.0
        if let settingsScore = calculateUnifiedScore(matchScore: settingsMatchScore, usageScore: settingsUsageScore) {
            let settingsResult = createSystemCommand(
                commandId: settingsId,
                title: "Trace Settings",
                subtitle: "Configure hotkeys and preferences",
                icon: "gearshape",
                shortcut: KeyboardShortcut(key: ",", modifiers: ["⌘"]),
                operation: createStandardAction(commandId: settingsId) {
                    openSettings()
                }
            )
            systemCommands.append((settingsResult, settingsScore))
        }
        
        
        // Quit command
        let quitMatchScore = matchesSearchTerms(query: searchLower, terms: [
            "quit trace", "quit", "exit", "close", "terminate", "stop", "end", "application"
        ])
        let quitId = "com.trace.command.quit"
        let quitUsageScore = usageScores[quitId] ?? 0.0
        if let quitScore = calculateUnifiedScore(matchScore: quitMatchScore, usageScore: quitUsageScore) {
            let quitResult = createSystemCommand(
                commandId: quitId,
                title: "Quit Trace",
                subtitle: "Exit the application",
                icon: "power",
                shortcut: KeyboardShortcut(key: "Q", modifiers: ["⌘"]),
                operation: createStandardAction(commandId: quitId) {
                    NSApp.terminate(nil)
                }
            )
            systemCommands.append((quitResult, quitScore))
        }
        
        // Public IP Address command
        let publicIPMatchScore = matchesSearchTerms(query: searchLower, terms: [
            "public ip", "external ip", "public ip address", "external ip address", "my ip", 
            "ip address", "public", "external", "internet ip", "wan ip", "outside ip"
        ])
        let publicIPId = "com.trace.command.publicip"
        let publicIPUsageScore = usageScores[publicIPId] ?? 0.0
        if let publicIPScore = calculateUnifiedScore(matchScore: publicIPMatchScore, usageScore: publicIPUsageScore) {
            // Primary action: Fetch and display (no clipboard copy)
            let fetchPublicIPAction = NetworkCommandAction(
                id: "\(publicIPId)-fetch",
                displayName: "Fetch IP",
                iconName: "eye",
                keyboardShortcut: "↩",
                description: "Fetch and display your public IP address",
                networkOperation: {
                    return await services.networkUtilities.getPublicIPAddress()
                },
                onResult: { ipAddress in
                    // Update the result in the cached results to show the IP
                    if let index = self.cachedResults.firstIndex(where: { $0.commandId == publicIPId }) {
                        let updatedResult = self.cachedResults[index]
                        
                        // Create a new result with updated title and subtitle
                        let updatedResultWithIP = SearchResult(
                            title: "Public IP Address: \(ipAddress)",
                            subtitle: updatedResult.subtitle,
                            icon: updatedResult.icon,
                            type: updatedResult.type,
                            category: updatedResult.category,
                            shortcut: updatedResult.shortcut,
                            lastUsed: updatedResult.lastUsed,
                            commandId: updatedResult.commandId,
                            isLoading: false,
                            accessory: .status("Fetched", .blue),
                            commandAction: updatedResult.commandAction
                        )
                        
                        self.cachedResults[index] = updatedResultWithIP
                    }
                },
                skipClipboard: true
            )
            
            // Secondary action: Fetch and copy to clipboard
            let copyPublicIPAction = NetworkCommandAction(
                id: "\(publicIPId)-copy",
                displayName: "Copy to Clipboard",
                iconName: "doc.on.clipboard",
                keyboardShortcut: nil,
                description: "Fetch your public IP address and copy to clipboard",
                networkOperation: {
                    return await services.networkUtilities.getPublicIPAddress()
                },
                onResult: { ipAddress in
                    // Update the result in the cached results to show copied state
                    if let index = self.cachedResults.firstIndex(where: { $0.commandId == publicIPId }) {
                        let updatedResult = self.cachedResults[index]
                        
                        let updatedResultWithIP = SearchResult(
                            title: "Public IP Address: \(ipAddress)",
                            subtitle: "Copied \(ipAddress) to clipboard",
                            icon: updatedResult.icon,
                            type: updatedResult.type,
                            category: updatedResult.category,
                            shortcut: updatedResult.shortcut,
                            lastUsed: updatedResult.lastUsed,
                            commandId: updatedResult.commandId,
                            isLoading: false,
                            accessory: .status("Copied", .green),
                            commandAction: updatedResult.commandAction
                        )
                        
                        self.cachedResults[index] = updatedResultWithIP
                    }
                },
                skipClipboard: false
            )
            
            // Create multi-action container
            let publicIPMultiAction = MultiCommandAction(
                id: publicIPId,
                primaryAction: fetchPublicIPAction,
                secondaryActions: [copyPublicIPAction]
            )
            
            let publicIPResult = SearchResult(
                title: "Public IP Address",
                subtitle: "Get your external IP address",
                icon: .system("globe"),
                type: .command,
                category: .network,
                shortcut: nil,
                lastUsed: nil,
                commandId: publicIPId,
                isLoading: false,
                accessory: nil,
                commandAction: publicIPMultiAction
            )
            
            systemCommands.append((publicIPResult, publicIPScore))
        }
        
        // Private IP Address command
        let privateIPMatchScore = matchesSearchTerms(query: searchLower, terms: [
            "private ip", "local ip", "private ip address", "local ip address", "internal ip",
            "lan ip", "network ip", "private", "local", "internal", "wifi ip", "ethernet ip"
        ])
        let privateIPId = "com.trace.command.privateip"
        let privateIPUsageScore = usageScores[privateIPId] ?? 0.0
        if let privateIPScore = calculateUnifiedScore(matchScore: privateIPMatchScore, usageScore: privateIPUsageScore) {
            // Primary action: Fetch and display (no clipboard copy)
            let fetchPrivateIPAction = NetworkCommandAction(
                id: "\(privateIPId)-fetch",
                displayName: "Fetch IP",
                iconName: "eye",
                keyboardShortcut: "↩",
                description: "Fetch and display your private IP address",
                networkOperation: {
                    return services.networkUtilities.getPrivateIPAddress()
                },
                onResult: { ipAddress in
                    // Update the result in the cached results to show the IP
                    if let index = self.cachedResults.firstIndex(where: { $0.commandId == privateIPId }) {
                        let updatedResult = self.cachedResults[index]
                        
                        // Create a new result with updated title and subtitle
                        let updatedResultWithIP = SearchResult(
                            title: "Private IP Address: \(ipAddress)",
                            subtitle: updatedResult.subtitle,
                            icon: updatedResult.icon,
                            type: updatedResult.type,
                            category: updatedResult.category,
                            shortcut: updatedResult.shortcut,
                            lastUsed: updatedResult.lastUsed,
                            commandId: updatedResult.commandId,
                            isLoading: false,
                            accessory: .status("Fetched", .blue),
                            commandAction: updatedResult.commandAction
                        )
                        
                        self.cachedResults[index] = updatedResultWithIP
                    }
                },
                skipClipboard: true
            )
            
            // Secondary action: Fetch and copy to clipboard
            let copyPrivateIPAction = NetworkCommandAction(
                id: "\(privateIPId)-copy",
                displayName: "Copy to Clipboard",
                iconName: "doc.on.clipboard",
                keyboardShortcut: nil,
                description: "Fetch your private IP address and copy to clipboard",
                networkOperation: {
                    return services.networkUtilities.getPrivateIPAddress()
                },
                onResult: { ipAddress in
                    // Update the result in the cached results to show copied state
                    if let index = self.cachedResults.firstIndex(where: { $0.commandId == privateIPId }) {
                        let updatedResult = self.cachedResults[index]
                        
                        let updatedResultWithIP = SearchResult(
                            title: "Private IP Address: \(ipAddress)",
                            subtitle: "Copied \(ipAddress) to clipboard",
                            icon: updatedResult.icon,
                            type: updatedResult.type,
                            category: updatedResult.category,
                            shortcut: updatedResult.shortcut,
                            lastUsed: updatedResult.lastUsed,
                            commandId: updatedResult.commandId,
                            isLoading: false,
                            accessory: .status("Copied", .green),
                            commandAction: updatedResult.commandAction
                        )
                        
                        self.cachedResults[index] = updatedResultWithIP
                    }
                },
                skipClipboard: false
            )
            
            // Create multi-action container
            let privateIPMultiAction = MultiCommandAction(
                id: privateIPId,
                primaryAction: fetchPrivateIPAction,
                secondaryActions: [copyPrivateIPAction]
            )
            
            let privateIPResult = SearchResult(
                title: "Private IP Address",
                subtitle: "Get your local network IP address",
                icon: .system("wifi"),
                type: .command,
                category: .network,
                shortcut: nil,
                lastUsed: nil,
                commandId: privateIPId,
                isLoading: false,
                accessory: nil,
                commandAction: privateIPMultiAction
            )
            
            systemCommands.append((privateIPResult, privateIPScore))
        }
        
        // Add math calculation if query is a math expression
        if MathEvaluator.isMathExpression(query) {
            let mathId = "com.trace.command.math"
            
            // Primary action: Calculate and show result
            let calculateAction = MathCommandAction(
                id: "\(mathId)-calculate",
                displayName: "Calculate",
                expression: query,
                iconName: "equal.circle",
                keyboardShortcut: "↩",
                description: "Calculate the result",
                onResult: { result in
                    // Update the result in the cached results to show the calculation
                    if let index = self.cachedResults.firstIndex(where: { $0.commandId == mathId }) {
                        let updatedResult = self.cachedResults[index]
                        
                        // Create a new result with updated title showing the answer
                        let updatedResultWithAnswer = SearchResult(
                            title: "\(query) = \(result)",
                            subtitle: "Math calculation result",
                            icon: updatedResult.icon,
                            type: updatedResult.type,
                            category: updatedResult.category,
                            shortcut: updatedResult.shortcut,
                            lastUsed: updatedResult.lastUsed,
                            commandId: updatedResult.commandId,
                            isLoading: false,
                            accessory: .status("Calculated", .green),
                            commandAction: updatedResult.commandAction
                        )
                        
                        self.cachedResults[index] = updatedResultWithAnswer
                    }
                }
            )
            
            // Secondary action: Calculate and copy to clipboard
            let copyResultAction = MathCopyCommandAction(
                id: "\(mathId)-copy",
                displayName: "Copy Result",
                expression: query,
                iconName: "doc.on.clipboard",
                description: "Calculate and copy result to clipboard",
                onResult: { result in
                    // Update the result in the cached results to show copied state
                    if let index = self.cachedResults.firstIndex(where: { $0.commandId == mathId }) {
                        let updatedResult = self.cachedResults[index]
                        
                        let updatedResultWithAnswer = SearchResult(
                            title: "\(query) = \(result)",
                            subtitle: "Copied \(result) to clipboard",
                            icon: updatedResult.icon,
                            type: updatedResult.type,
                            category: updatedResult.category,
                            shortcut: updatedResult.shortcut,
                            lastUsed: updatedResult.lastUsed,
                            commandId: updatedResult.commandId,
                            isLoading: false,
                            accessory: .status("Copied", .blue),
                            commandAction: updatedResult.commandAction
                        )
                        
                        self.cachedResults[index] = updatedResultWithAnswer
                    }
                }
            )
            
            // Create multi-action container
            let mathMultiAction = MultiCommandAction(
                id: mathId,
                primaryAction: calculateAction,
                secondaryActions: [copyResultAction]
            )
            
            let mathResult = SearchResult(
                title: "\(query) = ?",
                subtitle: "Calculate math expression",
                icon: .system("plus.forwardslash.minus"),
                type: .math,
                category: nil,
                shortcut: nil,
                lastUsed: nil,
                commandId: mathId,
                isLoading: false,
                accessory: nil,
                commandAction: mathMultiAction
            )
            
            // Math results get high priority (score 1.0)
            scoredResults.append((mathResult, 1.0))
        }
        
        // Add system commands to scored results
        scoredResults.append(contentsOf: systemCommands)
        
        // Add Control Center commands with unified scoring
        let controlCenterCommands = getControlCenterCommands(query: searchLower)
        for command in controlCenterCommands {
            // Calculate match score for control center command (check both title and subtitle)
            var matchScore = FuzzyMatcher.match(query: searchLower, text: command.title.lowercased())
            let subtitleScore = FuzzyMatcher.match(query: searchLower, text: command.subtitle.lowercased())
            matchScore = max(matchScore, subtitleScore)
            
            let commandId = "com.trace.controlcenter.\(command.id)"
            let usageScore = usageScores[commandId] ?? 0.0
            
            if let combinedScore = calculateUnifiedScore(matchScore: matchScore, usageScore: usageScore) {
                let commandAction = InstantCommandAction(
                    id: commandId,
                    displayName: command.title,
                    iconName: command.icon,
                    operation: command.action
                )
                
                let searchResult = SearchResult(
                    title: command.title,
                    subtitle: command.subtitle,
                    icon: .system(command.icon),
                    type: .command,
                    category: command.category,
                    shortcut: nil,
                    lastUsed: nil,
                    commandId: commandId,
                    accessory: nil,
                    commandAction: commandAction
                )
                
                scoredResults.append((searchResult, combinedScore))
            }
        }
        
        // Add window management commands with unified scoring
        let windowCommands = getWindowManagementCommands(query: searchLower)
        for command in windowCommands {
            // Calculate match score for window command (check both title and subtitle)
            var matchScore = FuzzyMatcher.match(query: searchLower, text: command.title.lowercased())
            if let subtitle = command.subtitle {
                let subtitleScore = FuzzyMatcher.match(query: searchLower, text: subtitle.lowercased())
                matchScore = max(matchScore, subtitleScore)
            }
            
            let commandId = command.commandId ?? getCommandIdentifier(for: command.title)
            let usageScore = usageScores[commandId] ?? 0.0
            
            if let combinedScore = calculateUnifiedScore(matchScore: matchScore, usageScore: usageScore) {
                scoredResults.append((command, combinedScore))
            }
        }
        
        // Add folder shortcuts with unified scoring
        let folderResults = services.folderManager.searchFolders(query: searchLower)
        for folder in folderResults {
            let matchScore = FuzzyMatcher.match(query: searchLower, text: folder.name.lowercased())
            let commandId = "com.trace.folder.\(folder.id)"
            let usageScore = usageScores[commandId] ?? 0.0
            
            if let combinedScore = calculateUnifiedScore(matchScore: matchScore, usageScore: usageScore) {
                // Get hotkey for this folder
                let shortcut: KeyboardShortcut? = {
                    if let hotkeyString = folder.hotkey, !hotkeyString.isEmpty {
                        return KeyboardShortcut(keyCombo: hotkeyString)
                    }
                    return nil
                }()
                
                let folderAction = InstantCommandAction(
                    id: commandId,
                    displayName: "Open \(folder.name)",
                    iconName: folder.iconName,
                    operation: { [services] in
                        services.folderManager.openFolder(folder)
                    }
                )
                
                let result = SearchResult(
                    title: folder.name,
                    subtitle: folder.path,
                    icon: .system(folder.iconName),
                    type: .folder,
                    category: folder.isDefault ? nil : .customFolder,
                    shortcut: shortcut,
                    lastUsed: nil,
                    commandId: commandId,
                    accessory: nil,
                    commandAction: folderAction
                )
                
                scoredResults.append((result, combinedScore))
            }
        }
        
        // Sort all results by score
        let sortedResults = scoredResults
            .sorted { $0.1 > $1.1 }
            .prefix(10) // Limit to top 10 results
            .map { $0.0 }
        
        var finalResults = Array(sortedResults)
        
        // Add search engine options
        var searchEngines: [SearchResult] = []
        
        if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
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
        }
        
        finalResults.append(contentsOf: searchEngines)
        
        return finalResults
    }
    
    // MARK: - Helper Functions
    
    func getControlCenterCommands(query: String) -> [ControlCenterCommand] {
        return ControlCenterManager.shared.getControlCenterCommands(matching: query)
    }
    
    func getCommandIdentifier(for title: String) -> String {
        // Fallback identifier for commands without explicit commandId
        return "com.trace.command.\(title.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }
    
    func matchesSearchTerms(query: String, terms: [String]) -> Double {
        return FuzzyMatcher.matchBest(query: query, terms: terms)
    }
    
    func normalizeUsageScore(_ score: Double) -> Double {
        // More aggressive normalization that better rewards frequently used items
        // Usage of 1 = 0.1, Usage of 5 = 0.35, Usage of 10 = 0.55, Usage of 20 = 0.75, Usage of 50+ = 1.0
        if score <= 0 { return 0 }
        if score >= 50 { return 1.0 }
        
        // Use logarithmic scale for better differentiation
        return min(log10(score + 1) / log10(51), 1.0)
    }
    
    // MARK: - Window Management
    
    func getWindowManagementCommands(query: String) -> [SearchResult] {
        var commands: [SearchResult] = []
        
        // Only show window commands if user is searching for window-related terms
        let windowTerms = [
            "window", "win", "resize", "move", "position", "left", "right", "center", "top", "bottom",
            "half", "third", "quarter", "maximize", "max", "larger", "smaller", "split"
        ]
        
        let hasWindowMatch = windowTerms.contains { term in
            FuzzyMatcher.match(query: query, text: term) > 0.3
        }
        
        // Also check direct matches against position names
        let directMatches = WindowPosition.allCases.filter { position in
            let searchTerms = [
                position.rawValue,
                position.displayName.lowercased(),
                position.displayName.replacingOccurrences(of: " ", with: "").lowercased()
            ]
            return searchTerms.contains { term in
                FuzzyMatcher.match(query: query, text: term) > 0.3
            }
        }
        
        if hasWindowMatch || !directMatches.isEmpty {
            // If we have direct matches, prioritize those, otherwise show all that meet threshold
            let positionsToCheck = !directMatches.isEmpty ? directMatches : WindowPosition.allCases
            
            for position in positionsToCheck {
                let searchTerms = [
                    position.rawValue,
                    position.displayName.lowercased(),
                    position.displayName.replacingOccurrences(of: " ", with: "").lowercased()
                ]
                
                let score = FuzzyMatcher.matchBest(query: query, terms: searchTerms)
                
                // Use consistent scoring with other commands
                if score > 0.3 {
                    // Check if this window position has a hotkey assigned
                    let shortcut: KeyboardShortcut? = {
                        if let hotkeyData = SettingsManager.shared.getWindowHotkey(for: position.rawValue) {
                            return KeyboardShortcut(keyCombo: hotkeyData.hotkey)
                        }
                        return nil
                    }()
                    
                    let windowAction = InstantCommandAction(
                        id: "com.trace.window.\(position.rawValue)",
                        displayName: position.displayName,
                        iconName: getWindowIcon(for: position),
                        operation: { [services] in
                            services.windowManager.applyWindowPosition(position)
                        }
                    )
                    
                    commands.append(SearchResult(
                        title: position.displayName,
                        subtitle: position.subtitle,
                        icon: .system(getWindowIcon(for: position)),
                        type: .command,
                        category: .window,
                        shortcut: shortcut,
                        lastUsed: nil,
                        commandId: "com.trace.window.\(position.rawValue)",
                        accessory: nil,
                        commandAction: windowAction
                    ))
                }
            }
        }
        
        return commands.sorted { $0.title < $1.title }
    }
    
    func getWindowIcon(for position: WindowPosition) -> String {
        switch position {
        case .leftHalf: return "rectangle.split.2x1"
        case .rightHalf: return "rectangle.split.2x1"
        case .centerHalf: return "rectangle.center.inset.filled"
        case .topHalf: return "rectangle.split.1x2"
        case .bottomHalf: return "rectangle.split.1x2"
        case .topLeft, .topRight, .bottomLeft, .bottomRight: return "rectangle.split.2x2"
        case .firstThird, .centerThird, .lastThird: return "rectangle.split.3x1"
        case .firstTwoThirds, .lastTwoThirds: return "rectangle.split.3x1"
        case .maximize: return "arrow.up.left.and.arrow.down.right"
        case .fullScreen: return "rectangle.fill"
        case .almostMaximize: return "macwindow"
        case .maximizeHeight: return "arrow.up.and.down"
        case .smaller: return "minus.rectangle"
        case .larger: return "plus.rectangle"
        case .center: return "target"
        case .centerProminently: return "viewfinder"
        }
    }
    
    
    // MARK: - Search and Actions
    
    /// Clear search state and reset UI
    func clearSearch() {
        currentSearchTask?.cancel()
        searchText = ""
        cachedResults = []
        selectedIndex = 0
    }
    
    /// Get result with current loading state
    func getResultWithLoadingState(_ result: SearchResult) -> SearchResult {
        var updatedResult = result
        updatedResult.isLoading = actionExecutor.isLoading(result.commandAction.id)
        return updatedResult
    }
    
    /// Execute the currently selected result
    func executeSelectedResult() {
        guard selectedIndex < results.count else { return }
        let result = results[selectedIndex]
        
        // Track usage based on result type
        switch result.type {
        case .application:
            if case .app(let bundleId) = result.icon {
                services.usageTracker.recordUsage(for: bundleId, type: UsageType.application)
            }
        case .command:
            // Use the command's semantic identifier for tracking
            let commandId = result.commandId ?? getCommandIdentifier(for: result.title)
            services.usageTracker.recordUsage(for: commandId, type: UsageType.command)
        case .suggestion:
            let commandId = result.commandId ?? "com.trace.search.unknown"
            services.usageTracker.recordUsage(for: commandId, type: UsageType.webSearch)
        case .folder:
            // Use the command's semantic identifier for tracking folders
            let commandId = result.commandId ?? "com.trace.folder.unknown"
            services.usageTracker.recordUsage(for: commandId, type: UsageType.command)
        case .math:
            // Track math calculations
            let commandId = result.commandId ?? "com.trace.math.calculation"
            services.usageTracker.recordUsage(for: commandId, type: UsageType.command)
        case .file, .person, .recent:
            // These types aren't implemented yet, so no tracking for now
            break
        }
        
        let commandAction = result.commandAction
        
        // For multi-action results, execute the selected action
        if result.hasMultipleActions {
            let selectedAction = result.allActions[selectedActionIndex]
            actionExecutor.executeAction(by: selectedAction.id, from: commandAction) { success in
                // For multi-action results, always keep launcher open
                // User can dismiss with ESC when done
                selectedIndex = 0
            }
        } else {
            // Single action - execute normally
            actionExecutor.execute(commandAction) { success in
                // For network and math commands, don't close launcher and keep search visible
                if commandAction is NetworkCommandAction || commandAction is MathCommandAction {
                    // Keep launcher open and don't clear search - user can see the result
                    // Reset selection to first item
                    selectedIndex = 0
                } else {
                    // For other commands, close launcher
                    clearSearch()
                    onClose()
                }
            }
        }
    }
}