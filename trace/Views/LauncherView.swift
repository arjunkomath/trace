//
//  LauncherView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI
import AppKit
import CoreGraphics

struct LauncherView: View {

    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openSettings) private var openSettings
    @ObservedObject private var services = ServiceContainer.shared
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var loadingCommands: Set<String> = [] // Track which commands are loading
    @State private var cachedResults: [SearchResult] = [] // Background-computed results
    @State private var isSearching = false // Track if background search is running
    @State private var currentSearchTask: Task<Void, Never>? // Track current search task
    
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Input - Fixed height section
            HStack(spacing: 12) {
                Image(systemName: "filemenu.and.selection")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary.opacity(0.6))
                
                TextField("What would you like to do?", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { _, newValue in
                        selectedIndex = 0
                        
                        // Cancel any existing search task
                        currentSearchTask?.cancel()
                        
                        // Clear results immediately if search is empty
                        if newValue.isEmpty {
                            cachedResults = []
                        } else {
                            // Start search immediately
                            performBackgroundSearch(for: newValue)
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: { 
                        clearSearch()
                        // Restore focus after clearing search
                        DispatchQueue.main.async {
                            isSearchFocused = true
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(height: AppConstants.Window.launcherHeight)
            
            // Results section - expandable
            VStack(spacing: 0) {
                if hasResults {
                    Divider()
                        .opacity(0.2)
                    
                    // Results header
                    HStack {
                        Text("Results")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        Spacer()
                    }
                    .background(Color.primary.opacity(0.02))
                    
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                                    Group {
                                        if ResultsLayout(rawValue: settingsManager.settings.resultsLayout) == .compact {
                                            CompactResultRowView(
                                                result: result,
                                                isSelected: index == selectedIndex
                                            )
                                        } else {
                                            ResultRowView(
                                                result: result,
                                                isSelected: index == selectedIndex
                                            )
                                        }
                                    }
                                    .id(index)
                                    .onTapGesture {
                                        selectedIndex = index
                                        executeSelectedResult()
                                    }
                                }
                            }
                        }
                        .onChange(of: selectedIndex) { _, newIndex in
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                    }
                    .frame(maxHeight: AppConstants.Window.maxResultsHeight)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: AppConstants.Window.launcherWidth)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.Window.cornerRadius)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.Window.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.Window.cornerRadius)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.15), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.6 : 0.3),
            radius: AppConstants.Window.shadowRadius,
            x: AppConstants.Window.shadowOffset.width,
            y: AppConstants.Window.shadowOffset.height
        )
        .padding(AppConstants.Window.searchPadding)
        .onAppear {
            clearSearch()
            // Set focus immediately
            isSearchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .shouldFocusSearchField)) { _ in
            // Respond to focus requests from LauncherWindow
            isSearchFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .launcherWindowDidBecomeKey)) { _ in
            // Additional focus attempt when window becomes key
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
        .onDisappear {
            currentSearchTask?.cancel()
        }
        .onKeyPress(.escape) {
            clearSearch()
            onClose()
            return .handled
        }
        .onKeyPress(.return) {
            executeSelectedResult()
            return .handled
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < results.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
    }
    
    // MARK: - Data
    
    var hasResults: Bool {
        !searchText.isEmpty && !results.isEmpty
    }
    
    // MARK: - Scoring Utilities
    
    /// Calculate combined score from match score and usage
    private func calculateCombinedScore(matchScore: Double, usageScore: Double, usageNormalizationFactor: Double = 50.0) -> Double {
        let normalizedUsage = min(usageScore / usageNormalizationFactor, 1.0)
        return (matchScore * 0.6) + (normalizedUsage * 0.4)
    }
    
    /// Check if match score meets minimum threshold and calculate combined score
    private func shouldIncludeCommand(matchScore: Double, usageScore: Double, threshold: Double = 0.3) -> (Bool, Double) {
        guard matchScore > threshold else { return (false, 0.0) }
        let combinedScore = calculateCombinedScore(matchScore: matchScore, usageScore: usageScore)
        return (true, combinedScore)
    }
    
    /// Create a system command result with common parameters
    private func createSystemCommand(
        commandId: String,
        title: String,
        subtitle: String,
        icon: String,
        category: String? = nil,
        shortcut: KeyboardShortcut? = nil,
        action: @escaping () -> Void
    ) -> SearchResult {
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
            action: action
        )
    }
    
    /// Clear search state and reset UI
    private func clearSearch() {
        currentSearchTask?.cancel()
        searchText = ""
        cachedResults = []
        selectedIndex = 0
    }
    
    /// Standard action wrapper that tracks usage and closes launcher
    private func createStandardAction(commandId: String, customAction: @escaping () -> Void) -> () -> Void {
        return { [services, self] in
            services.usageTracker.recordUsage(for: commandId, type: .command)
            customAction()
            clearSearch()
            onClose()
        }
    }
    
    /// Create an IP command with dynamic title/subtitle and loading state support
    private func createIPCommand(
        commandId: String,
        matchScore: Double,
        usageScore: Double,
        terms: [String],
        baseTitle: String,
        baseSubtitle: String,
        icon: String,
        cachedValue: String?,
        onAction: @escaping (String?, @escaping () -> Void) -> Void
    ) -> (SearchResult, Double)? {
        let (shouldInclude, score) = shouldIncludeCommand(matchScore: matchScore, usageScore: usageScore)
        guard shouldInclude else { return nil }
        
        // Dynamic title and subtitle based on cached value
        let displayTitle = cachedValue != nil ? "\(baseTitle): \(cachedValue!)" : baseTitle
        let displaySubtitle = cachedValue != nil ? "Copy \(cachedValue!) to clipboard" : baseSubtitle
        
        var result = createSystemCommand(
            commandId: commandId,
            title: displayTitle,
            subtitle: displaySubtitle,
            icon: icon,
            category: "Network",
            action: createStandardAction(commandId: commandId) {
                onAction(cachedValue) {
                    // Callback for additional cleanup if needed
                }
            }
        )
        
        result.isLoading = isCommandLoading(commandId)
        return (result, score)
    }
    
    var results: [SearchResult] {
        guard !searchText.isEmpty else { 
            return []
        }
        return cachedResults
    }
    
    /// Perform search calculations in background thread
    private func performBackgroundSearch(for query: String) {
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
    private func calculateSearchResults(query: String) async -> [SearchResult] {
        let searchLower = query.lowercased()
        var scoredResults: [(SearchResult, Double)] = []
        
        // Get usage scores for all items (this can be heavy)
        let usageScores = services.usageTracker.getAllUsageScores()
        
        // Get apps but calculate our own scores for fair comparison
        let apps = services.appSearchManager.searchApps(query: query, limit: 30)
        for app in apps {
            // Calculate match score ourselves for consistency
            let matchScore = FuzzyMatcher.match(query: searchLower, text: app.displayName.lowercased())
            
            // Skip if match score is too low
            if matchScore < 0.3 { continue }
            
            // Check if there's a hotkey assigned for this app
            let shortcut: KeyboardShortcut? = {
                if let hotkeyString = services.appHotkeyManager.getHotkey(for: app.bundleIdentifier), !hotkeyString.isEmpty {
                    return KeyboardShortcut(keyCombo: hotkeyString)
                }
                return nil
            }()
            
            // Check if app is currently running
            let isRunning = services.appSearchManager.isAppRunning(bundleIdentifier: app.bundleIdentifier)
            let accessory: SearchResultAccessory? = isRunning ? .runningIndicator : nil
            
            let result = SearchResult(
                title: app.displayName,
                subtitle: nil,
                icon: .app(app.bundleIdentifier),
                type: .application,
                category: "Applications",
                shortcut: shortcut,
                lastUsed: nil,
                commandId: app.bundleIdentifier,
                accessory: accessory,
                action: { [services] in
                    services.appSearchManager.launchApp(app)
                }
            )
            
            // Calculate combined score using unified scoring
            let usageScore = usageScores[app.bundleIdentifier] ?? 0.0
            let combinedScore = calculateCombinedScore(matchScore: matchScore, usageScore: usageScore)
            
            scoredResults.append((result, combinedScore))
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
        let (includeSettings, settingsScore) = shouldIncludeCommand(matchScore: settingsMatchScore, usageScore: settingsUsageScore)
        
        if includeSettings {
            let settingsResult = createSystemCommand(
                commandId: settingsId,
                title: "Trace Settings",
                subtitle: "Configure hotkeys and preferences",
                icon: "gearshape",
                shortcut: KeyboardShortcut(key: ",", modifiers: ["⌘"]),
                action: createStandardAction(commandId: settingsId) {
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
        let (includeQuit, quitScore) = shouldIncludeCommand(matchScore: quitMatchScore, usageScore: quitUsageScore)
        
        if includeQuit {
            let quitResult = createSystemCommand(
                commandId: quitId,
                title: "Quit Trace",
                subtitle: "Exit the application",
                icon: "power",
                shortcut: KeyboardShortcut(key: "Q", modifiers: ["⌘"]),
                action: createStandardAction(commandId: quitId) {
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
        let cachedPublicIP = services.networkUtilities.getCachedPublicIP()
        
        // Start fetching public IP if not cached and not already loading
        if publicIPMatchScore > 0.3 && cachedPublicIP == nil && !isCommandLoading(publicIPId) {
            setCommandLoading(publicIPId, isLoading: true)
            Task { @MainActor in
                _ = await services.networkUtilities.getPublicIPAddress()
                setCommandLoading(publicIPId, isLoading: false)
            }
        }
        
        if let publicIPResult = createIPCommand(
            commandId: publicIPId,
            matchScore: publicIPMatchScore,
            usageScore: publicIPUsageScore,
            terms: ["public ip", "external ip", "my ip"],
            baseTitle: "Public IP Address",
            baseSubtitle: "Get your external IP address",
            icon: "globe",
            cachedValue: cachedPublicIP
        ) { cachedIP, cleanup in
            if let ip = cachedIP {
                services.networkUtilities.copyToClipboard(ip)
                let notification = NSUserNotification()
                notification.title = "Public IP Copied"
                notification.informativeText = "Your public IP address \(ip) has been copied to the clipboard"
                NSUserNotificationCenter.default.deliver(notification)
            } else {
                let notification = NSUserNotification()
                notification.title = "Public IP Loading"
                notification.informativeText = "Please wait while we fetch your public IP address"
                NSUserNotificationCenter.default.deliver(notification)
            }
        } {
            systemCommands.append(publicIPResult)
        }
        
        // Private IP Address command
        let privateIPMatchScore = matchesSearchTerms(query: searchLower, terms: [
            "private ip", "local ip", "private ip address", "local ip address", "internal ip",
            "lan ip", "network ip", "private", "local", "internal", "wifi ip", "ethernet ip"
        ])
        let privateIPId = "com.trace.command.privateip"
        let privateIPUsageScore = usageScores[privateIPId] ?? 0.0
        let cachedPrivateIP = services.networkUtilities.getCachedPrivateIP()
        
        if let privateIPResult = createIPCommand(
            commandId: privateIPId,
            matchScore: privateIPMatchScore,
            usageScore: privateIPUsageScore,
            terms: ["private ip", "local ip", "internal ip"],
            baseTitle: "Private IP Address", 
            baseSubtitle: "Get your local network IP address",
            icon: "wifi",
            cachedValue: cachedPrivateIP
        ) { cachedIP, cleanup in
            // Set brief loading state for consistency (private IP is usually instant)
            self.setCommandLoading(privateIPId, isLoading: true)
            
            // Use a small delay to show spinner briefly since private IP is usually instant
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let ip = cachedIP ?? services.networkUtilities.getPrivateIPAddress() {
                    services.networkUtilities.copyToClipboard(ip)
                    let notification = NSUserNotification()
                    notification.title = "Private IP Copied"
                    notification.informativeText = "Your private IP address \(ip) has been copied to the clipboard"
                    NSUserNotificationCenter.default.deliver(notification)
                } else {
                    let notification = NSUserNotification()
                    notification.title = "IP Address Not Found"
                    notification.informativeText = "Could not determine your private IP address"
                    NSUserNotificationCenter.default.deliver(notification)
                }
                self.setCommandLoading(privateIPId, isLoading: false)
            }
        } {
            systemCommands.append(privateIPResult)
        }
        
        // Add system commands to scored results
        scoredResults.append(contentsOf: systemCommands)
        
        // Add Control Center commands with consistent scoring
        let controlCenterCommands = getControlCenterCommands(query: searchLower)
        for command in controlCenterCommands {
            // Calculate match score for control center command (check both title and subtitle)
            var matchScore = FuzzyMatcher.match(query: searchLower, text: command.title.lowercased())
            let subtitleScore = FuzzyMatcher.match(query: searchLower, text: command.subtitle.lowercased())
            matchScore = max(matchScore, subtitleScore)
            if matchScore > 0.3 {
                let commandId = "com.trace.controlcenter.\(command.id)"
                let usageScore = usageScores[commandId] ?? 0.0
                let normalizedUsage = min(usageScore / 50.0, 1.0)
                let combinedScore = (matchScore * 0.6) + (normalizedUsage * 0.4)
                
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
                    action: command.action
                )
                
                scoredResults.append((searchResult, combinedScore))
            }
        }
        
        // Add window management commands with consistent scoring
        let windowCommands = getWindowManagementCommands(query: searchLower)
        for command in windowCommands {
            // Calculate match score for window command (check both title and subtitle)
            var matchScore = FuzzyMatcher.match(query: searchLower, text: command.title.lowercased())
            if let subtitle = command.subtitle {
                let subtitleScore = FuzzyMatcher.match(query: searchLower, text: subtitle.lowercased())
                matchScore = max(matchScore, subtitleScore)
            }
            if matchScore > 0.3 {
                let commandId = command.commandId ?? getCommandIdentifier(for: command.title)
                let usageScore = usageScores[commandId] ?? 0.0
                let normalizedUsage = normalizeUsageScore(usageScore)
                let combinedScore = (matchScore * 0.6) + (normalizedUsage * 0.4)
                scoredResults.append((command, combinedScore))
            }
        }
        
        // Add folder shortcuts with consistent scoring
        let folderResults = services.folderManager.searchFolders(query: searchLower)
        for folder in folderResults {
            let matchScore = FuzzyMatcher.match(query: searchLower, text: folder.name.lowercased())
            if matchScore > 0.3 {
                let commandId = "com.trace.folder.\(folder.id)"
                let usageScore = usageScores[commandId] ?? 0.0
                let normalizedUsage = normalizeUsageScore(usageScore)
                let combinedScore = (matchScore * 0.6) + (normalizedUsage * 0.4)
                
                // Get hotkey for this folder
                let shortcut: KeyboardShortcut? = {
                    if let hotkeyString = folder.hotkey, !hotkeyString.isEmpty {
                        return KeyboardShortcut(keyCombo: hotkeyString)
                    }
                    return nil
                }()
                
                let result = SearchResult(
                    title: folder.name,
                    subtitle: folder.path,
                    icon: .system(folder.iconName),
                    type: .folder,
                    category: folder.isDefault ? nil : "Custom Folder",
                    shortcut: shortcut,
                    lastUsed: nil,
                    commandId: commandId,
                    accessory: nil,
                    action: { [services] in
                        services.folderManager.openFolder(folder)
                    }
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
        let searchEngines = [
            SearchResult(
                title: "Search Google for '\(query)'",
                subtitle: "Open in browser",
                icon: .system("globe"),
                type: .suggestion,
                category: "Web",
                shortcut: nil,
                lastUsed: nil,
                commandId: "com.trace.search.google",
                accessory: nil,
                action: {
                    if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       let url = URL(string: "https://www.google.com/search?q=\(encodedQuery)") {
                        NSWorkspace.shared.open(url)
                    }
                }
            ),
            SearchResult(
                title: "Search DuckDuckGo for '\(query)'",
                subtitle: "Privacy-focused search",
                icon: .system("shield"),
                type: .suggestion,
                category: "Web",
                shortcut: nil,
                lastUsed: nil,
                commandId: "com.trace.search.duckduckgo",
                accessory: nil,
                action: {
                    if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       let url = URL(string: "https://duckduckgo.com/?q=\(encodedQuery)") {
                        NSWorkspace.shared.open(url)
                    }
                }
            ),
            SearchResult(
                title: "Search Perplexity for '\(query)'",
                subtitle: "AI-powered search",
                icon: .system("brain.head.profile"),
                type: .suggestion,
                category: "Web",
                shortcut: nil,
                lastUsed: nil,
                commandId: "com.trace.search.perplexity",
                accessory: nil,
                action: {
                    if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                       let url = URL(string: "https://www.perplexity.ai/search?q=\(encodedQuery)") {
                        NSWorkspace.shared.open(url)
                    }
                }
            )
        ]
        
        finalResults.append(contentsOf: searchEngines)
        
        return finalResults
    }
    
    // MARK: - Actions
    
    func executeSelectedResult() {
        guard selectedIndex < results.count else { return }
        let result = results[selectedIndex]
        
        // Track usage based on result type
        switch result.type {
        case .application:
            if case .app(let bundleId) = result.icon {
                services.usageTracker.recordUsage(for: bundleId, type: .application)
            }
        case .command:
            // Use the command's semantic identifier for tracking
            let commandId = result.commandId ?? getCommandIdentifier(for: result.title)
            services.usageTracker.recordUsage(for: commandId, type: .command)
        case .suggestion:
            let commandId = result.commandId ?? "com.trace.search.unknown"
            services.usageTracker.recordUsage(for: commandId, type: .webSearch)
        case .folder:
            // Use the command's semantic identifier for tracking folders
            let commandId = result.commandId ?? "com.trace.folder.unknown"
            services.usageTracker.recordUsage(for: commandId, type: .command)
        case .file, .person, .recent:
            // These types aren't implemented yet, so no tracking for now
            break
        }
        
        // Special handling for quit command - let the action handle everything
        if result.title == "Quit Trace" {
            result.action()
            // Don't call onClose() here - action already handles it
            return
        }
        
        result.action()
        searchText = ""
        selectedIndex = 0
        onClose()
    }
    
    // MARK: - Helper Functions
    
    private func getControlCenterCommands(query: String) -> [ControlCenterCommand] {
        return ControlCenterManager.shared.getControlCenterCommands(matching: query)
    }
    
    private func getCommandIdentifier(for title: String) -> String {
        // Fallback identifier for commands without explicit commandId
        return "com.trace.command.\(title.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }
    
    // MARK: - Helper Functions
    
    private func matchesSearchTerms(query: String, terms: [String]) -> Double {
        return FuzzyMatcher.matchBest(query: query, terms: terms)
    }
    
    private func normalizeUsageScore(_ score: Double) -> Double {
        // More aggressive normalization that better rewards frequently used items
        // Usage of 1 = 0.1, Usage of 5 = 0.35, Usage of 10 = 0.55, Usage of 20 = 0.75, Usage of 50+ = 1.0
        if score <= 0 { return 0 }
        if score >= 50 { return 1.0 }
        
        // Use logarithmic scale for better differentiation
        return min(log10(score + 1) / log10(51), 1.0)
    }
    
    // MARK: - Window Management
    
    private func getWindowManagementCommands(query: String) -> [SearchResult] {
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
            // If we have direct matches, prioritize those, otherwise show common ones
            let positionsToShow = !directMatches.isEmpty ? directMatches : [
                .leftHalf, .rightHalf, .center, .maximize, .almostMaximize,
                .topLeft, .topRight, .bottomLeft, .bottomRight
            ]
            
            for position in positionsToShow {
                let searchTerms = [
                    position.rawValue,
                    position.displayName.lowercased(),
                    position.displayName.replacingOccurrences(of: " ", with: "").lowercased()
                ]
                
                let score = FuzzyMatcher.matchBest(query: query, terms: searchTerms)
                
                if score > 0.3 {
                    // Check if this window position has a hotkey assigned
                    let shortcut: KeyboardShortcut? = {
                        if let hotkeyData = SettingsManager.shared.getWindowHotkey(for: position.rawValue) {
                            return KeyboardShortcut(keyCombo: hotkeyData.hotkey)
                        }
                        return nil
                    }()
                    
                    commands.append(SearchResult(
                        title: position.displayName,
                        subtitle: position.subtitle,
                        icon: .system(getWindowIcon(for: position)),
                        type: .command,
                        category: "Window",
                        shortcut: shortcut,
                        lastUsed: nil,
                        commandId: "com.trace.window.\(position.rawValue)",
                        accessory: nil,
                        action: { [services] in
                            services.windowManager.applyWindowPosition(position)
                        }
                    ))
                }
            }
        }
        
        return commands.sorted { $0.title < $1.title }
    }
    
    private func getWindowIcon(for position: WindowPosition) -> String {
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
    
    // MARK: - Loading State Management
    
    private func setCommandLoading(_ commandId: String, isLoading: Bool) {
        DispatchQueue.main.async {
            if isLoading {
                self.loadingCommands.insert(commandId)
            } else {
                self.loadingCommands.remove(commandId)
            }
        }
    }
    
    private func isCommandLoading(_ commandId: String) -> Bool {
        return loadingCommands.contains(commandId)
    }
}

// MARK: - Result Row

struct ResultRowView: View {
    let result: SearchResult
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Group {
                switch result.icon {
                case .system(let name):
                    Image(systemName: name)
                        .font(.system(size: 20))
                case .emoji(let emoji):
                    Text(emoji)
                        .font(.system(size: 22))
                case .image(let image):
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .app(let bundleIdentifier):
                    AppIconView(bundleIdentifier: bundleIdentifier)
                        .frame(width: 24, height: 24)
                }
            }
            .foregroundColor(isSelected ? .white : (isHovered ? .primary : .secondary))
            .frame(width: 28, height: 28)
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                }
            }
            
            Spacer()
            
            // Accessory (running indicator, badge, etc.)
            if let accessory = result.accessory {
                if accessory.isIndicatorDot {
                    Circle()
                        .fill(accessory.color)
                        .frame(width: 6, height: 6)
                } else if let displayText = accessory.displayText {
                    Text(displayText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isSelected ? .white : accessory.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(accessory.color.opacity(isSelected ? 0.3 : 0.15))
                        )
                }
            }
            
            // Loading spinner or result type
            if result.isLoading {
                ProgressView()
                    .frame(width: 10, height: 10)
                    .scaleEffect(0.5)
                    .foregroundColor(isSelected ? .white : .secondary)
            } else {
                Text(result.type.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                
                // Shortcut
                if let shortcut = result.shortcut {
                    KeyBindingView(shortcut: shortcut, isSelected: isSelected, size: .small)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isSelected ? (colorScheme == .dark ? Color.white.opacity(0.1) : Color.accentColor.opacity(0.8)) : 
            (isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Compact Result Row

struct CompactResultRowView: View {
    let result: SearchResult
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Group {
                switch result.icon {
                case .system(let name):
                    Image(systemName: name)
                        .font(.system(size: 18))
                case .emoji(let emoji):
                    Text(emoji)
                        .font(.system(size: 20))
                case .image(let image):
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .app(let bundleIdentifier):
                    AppIconView(bundleIdentifier: bundleIdentifier)
                        .frame(width: 20, height: 20)
                }
            }
            .foregroundColor(isSelected ? .white : (isHovered ? .primary : .secondary))
            .frame(width: 24, height: 24)
            
            // Title
            Text(result.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)
            
            // Subtitle (inline)
            if let subtitle = result.subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Accessory (running indicator, badge, etc.)
            if let accessory = result.accessory {
                if accessory.isIndicatorDot {
                    Circle()
                        .fill(accessory.color)
                        .frame(width: 5, height: 5)
                } else if let displayText = accessory.displayText {
                    Text(displayText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(isSelected ? .white : accessory.color)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(accessory.color.opacity(isSelected ? 0.3 : 0.15))
                        )
                }
            }
            
            // Loading spinner or result type
            if result.isLoading {
                ProgressView()
                    .frame(width: 8, height: 8)
                    .scaleEffect(0.4)
                    .foregroundColor(isSelected ? .white : .secondary)
            } else {
                Text(result.type.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                
                // Shortcut
                if let shortcut = result.shortcut {
                    KeyBindingView(shortcut: shortcut, isSelected: isSelected, size: .small)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8) // Reduced from 12 to make it more compact
        .background(
            isSelected ? (colorScheme == .dark ? Color.white.opacity(0.1) : Color.accentColor.opacity(0.8)) : 
            (isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - App Icon View

struct AppIconView: View {
    let bundleIdentifier: String
    @State private var icon: NSImage?
    @State private var loadingTask: Task<Void, Never>?
    
    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loadIcon()
        }
        .onChange(of: bundleIdentifier) { _, newBundleId in
            // Cancel existing task and reload when bundle identifier changes
            loadingTask?.cancel()
            icon = nil
            loadIcon()
        }
        .onDisappear {
            loadingTask?.cancel()
        }
    }
    
    private func loadIcon() {
        loadingTask?.cancel()
        
        let services = ServiceContainer.shared
        guard let app = services.appSearchManager.getApp(by: bundleIdentifier) else { return }
        
        loadingTask = Task { [bundleIdentifier] in
            let loadedIcon = await services.appSearchManager.getAppIcon(for: app)
            
            // Only update if this task hasn't been cancelled and bundle ID hasn't changed
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                // Double-check bundle identifier hasn't changed while loading
                if self.bundleIdentifier == bundleIdentifier {
                    self.icon = loadedIcon
                }
            }
        }
    }
}

// MARK: - Visual Effect View

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
