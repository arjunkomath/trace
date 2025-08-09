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
    @ObservedObject private var windowManager = WindowManager.shared
    
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Input - Fixed height section
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary.opacity(0.6))
                
                TextField("What would you like to do?", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { _, _ in
                        selectedIndex = 0
                    }
                
                if !searchText.isEmpty {
                    Button(action: { 
                        searchText = ""
                        selectedIndex = 0
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
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                                ResultRowView(
                                    result: result,
                                    isSelected: index == selectedIndex
                                )
                                .onTapGesture {
                                    selectedIndex = index
                                    executeSelectedResult()
                                }
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
            searchText = ""
            selectedIndex = 0
            
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
        .onKeyPress(.escape) {
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
        .toast(
            isShowing: $windowManager.showToast,
            message: windowManager.toastMessage,
            type: windowManager.toastType
        )
    }
    
    // MARK: - Data
    
    var hasResults: Bool {
        !searchText.isEmpty && !results.isEmpty
    }
    
    var results: [SearchResult] {
        guard !searchText.isEmpty else { return [] }
        
        let searchLower = searchText.lowercased()
        var scoredResults: [(SearchResult, Double)] = []
        
        // Get usage scores for all items
        let usageScores = UsageTracker.shared.getAllUsageScores()
        
        // Get apps but calculate our own scores for fair comparison
        let apps = AppSearchManager.shared.searchApps(query: searchText, limit: 30)
        for app in apps {
            // Calculate match score ourselves for consistency
            let matchScore = fuzzyMatch(query: searchLower, text: app.displayName.lowercased())
            
            // Skip if match score is too low
            if matchScore < 0.3 { continue }
            
            let result = SearchResult(
                title: app.displayName,
                subtitle: nil,
                icon: .app(app.bundleIdentifier),
                type: .application,
                category: "Applications",
                shortcut: nil,
                lastUsed: nil,
                action: {
                    AppSearchManager.shared.launchApp(app)
                }
            )
            
            // Calculate combined score: 60% match, 40% usage (increased usage weight)
            let usageScore = usageScores[app.bundleIdentifier] ?? 0.0
            let normalizedUsage = min(usageScore / 50.0, 1.0) // Normalize to 0-1, reaching 1.0 at 50 uses
            let combinedScore = (matchScore * 0.6) + (normalizedUsage * 0.4)
            
            scoredResults.append((result, combinedScore))
        }
        
        // Add system commands with fuzzy matching and usage scores
        var systemCommands: [(SearchResult, Double)] = []
        
        // Settings command - use same scoring as apps for fairness
        let settingsMatchScore = matchesSearchTerms(query: searchLower, terms: [
            "trace settings", "settings", "preferences", "config", "configuration", 
            "trace", "setup", "options", "prefs"
        ])
        if settingsMatchScore > 0.3 {
            let settingsId = "com.trace.command.settings"
            let usageScore = usageScores[settingsId] ?? 0.0
            let normalizedUsage = min(usageScore / 50.0, 1.0) // Same normalization as apps
            // Use same formula: 60% match, 40% usage
            let combinedScore = (settingsMatchScore * 0.6) + (normalizedUsage * 0.4)
            
            systemCommands.append((SearchResult(
                title: "Trace Settings",
                subtitle: "Configure hotkeys and preferences",
                icon: .system("gearshape"),
                type: .command,
                category: nil,
                shortcut: KeyboardShortcut(key: ",", modifiers: ["⌘"]),
                lastUsed: nil,
                action: {
                    openSettings()
                }
            ), combinedScore))
        }
        
        // Quit command - use same scoring as apps for fairness
        let quitMatchScore = matchesSearchTerms(query: searchLower, terms: [
            "quit trace", "quit", "exit", "close", "terminate", "stop", "end"
        ])
        if quitMatchScore > 0.3 {
            let quitId = "com.trace.command.quit"
            let usageScore = usageScores[quitId] ?? 0.0
            let normalizedUsage = min(usageScore / 50.0, 1.0) // Same normalization as apps
            // Use same formula: 60% match, 40% usage
            let combinedScore = (quitMatchScore * 0.6) + (normalizedUsage * 0.4)
            
            systemCommands.append((SearchResult(
                title: "Quit Trace",
                subtitle: "Exit the application",
                icon: .system("power"),
                type: .command,
                category: nil,
                shortcut: KeyboardShortcut(key: "Q", modifiers: ["⌘"]),
                lastUsed: nil,
                action: {
                    NSApp.terminate(nil)
                }
            ), combinedScore))
        }
        
        // Add system commands to scored results
        scoredResults.append(contentsOf: systemCommands)
        
        // Add window management commands with consistent scoring
        let windowCommands = getWindowManagementCommands(query: searchLower)
        for command in windowCommands {
            // Calculate match score for window command
            let matchScore = fuzzyMatch(query: searchLower, text: command.title.lowercased())
            if matchScore > 0.3 {
                let commandId = getCommandIdentifier(for: command.title)
                let usageScore = usageScores[commandId] ?? 0.0
                let normalizedUsage = min(usageScore / 50.0, 1.0)
                let combinedScore = (matchScore * 0.6) + (normalizedUsage * 0.4)
                scoredResults.append((command, combinedScore))
            }
        }
        
        // Sort all results by score
        let sortedResults = scoredResults
            .sorted { $0.1 > $1.1 }
            .prefix(10) // Limit to top 10 results
            .map { $0.0 }
        
        var finalResults = Array(sortedResults)
        
        // Always add Google search as last option
        let googleSearchResult = SearchResult(
            title: "Search Google for '\(searchText)'",
            subtitle: "Open in browser",
            icon: .system("globe"),
            type: .suggestion,
            category: "Web",
            shortcut: nil,
            lastUsed: nil,
            action: {
                if let encodedQuery = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                   let url = URL(string: "https://www.google.com/search?q=\(encodedQuery)") {
                    NSWorkspace.shared.open(url)
                }
            }
        )
        finalResults.append(googleSearchResult)
        
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
                UsageTracker.shared.recordUsage(for: bundleId, type: .application)
            }
        case .command:
            // Use a consistent identifier for commands instead of title
            let commandId = getCommandIdentifier(for: result.title)
            UsageTracker.shared.recordUsage(for: commandId, type: .command)
        case .suggestion:
            UsageTracker.shared.recordUsage(for: "com.trace.search.google", type: .webSearch)
        case .file, .person, .recent:
            // These types aren't implemented yet, so no tracking for now
            break
        }
        
        result.action()
        searchText = ""
        selectedIndex = 0
        onClose()
    }
    
    // MARK: - Helper Functions
    
    private func getCommandIdentifier(for title: String) -> String {
        // Map command titles to consistent identifiers
        switch title {
        case "Trace Settings":
            return "com.trace.command.settings"
        case "Quit Trace":
            return "com.trace.command.quit"
        default:
            // For window management commands, use the position as identifier
            if let position = WindowPosition.allCases.first(where: { $0.displayName == title }) {
                return "com.trace.window.\(position.rawValue)"
            }
            // Fallback to sanitized title
            return "com.trace.command.\(title.lowercased().replacingOccurrences(of: " ", with: "_"))"
        }
    }
    
    // MARK: - Fuzzy Search Helper
    
    private func fuzzyMatch(query: String, text: String) -> Double {
        let queryLower = query.lowercased()
        let textLower = text.lowercased()
        
        // Exact match gets highest score
        if textLower == queryLower {
            return 1.0
        }
        
        // Prefix match gets high score
        if textLower.hasPrefix(queryLower) {
            return 0.9
        }
        
        // Contains match gets medium score
        if textLower.contains(queryLower) {
            return 0.7
        }
        
        // Fuzzy character-by-character matching
        return fuzzyCharacterMatch(query: queryLower, text: textLower)
    }
    
    private func fuzzyCharacterMatch(query: String, text: String) -> Double {
        let queryChars = Array(query)
        let textChars = Array(text)
        
        var queryIndex = 0
        var matches = 0
        var consecutiveMatches = 0
        var maxConsecutive = 0
        
        for textChar in textChars {
            if queryIndex < queryChars.count && queryChars[queryIndex] == textChar {
                matches += 1
                queryIndex += 1
                consecutiveMatches += 1
                maxConsecutive = max(maxConsecutive, consecutiveMatches)
            } else {
                consecutiveMatches = 0
            }
        }
        
        // All query characters must be found
        guard matches == queryChars.count else { return 0 }
        
        // Score based on match ratio and consecutive matches
        let matchRatio = Double(matches) / Double(textChars.count)
        let consecutiveBonus = Double(maxConsecutive) / Double(queryChars.count)
        
        return min(0.6, matchRatio * 0.4 + consecutiveBonus * 0.2)
    }
    
    private func matchesSearchTerms(query: String, terms: [String]) -> Double {
        let bestMatch = terms.compactMap { term in
            fuzzyMatch(query: query, text: term)
        }.max() ?? 0
        
        return bestMatch
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
            fuzzyMatch(query: query, text: term) > 0.3
        }
        
        // Also check direct matches against position names
        let directMatches = WindowPosition.allCases.filter { position in
            let searchTerms = [
                position.rawValue,
                position.displayName.lowercased(),
                position.displayName.replacingOccurrences(of: " ", with: "").lowercased()
            ]
            return searchTerms.contains { term in
                fuzzyMatch(query: query, text: term) > 0.3
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
                
                let score = searchTerms.compactMap { term in
                    fuzzyMatch(query: query, text: term)
                }.max() ?? (hasWindowMatch ? 0.5 : 0)
                
                if score > 0.3 {
                    // Check if this window position has a hotkey assigned
                    let assignedHotkey = UserDefaults.standard.string(forKey: "window_\(position.rawValue)_hotkey")
                    let shortcut: KeyboardShortcut? = {
                        if let hotkeyString = assignedHotkey, !hotkeyString.isEmpty {
                            return KeyboardShortcut(keyCombo: hotkeyString)
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
                        action: {
                            WindowManager.shared.applyWindowPosition(position)
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
        case .almostMaximize: return "macwindow"
        case .maximizeHeight: return "arrow.up.and.down"
        case .smaller: return "minus.rectangle"
        case .larger: return "plus.rectangle"
        case .center: return "target"
        case .centerProminently: return "viewfinder"
        }
    }
}

// MARK: - Result Row

struct ResultRowView: View {
    let result: SearchResult
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme
    
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
            .foregroundColor(isSelected ? .white : .secondary)
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
            
            // Result type
            Text(result.type.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            
            // Shortcut
            if let shortcut = result.shortcut {
                KeyBindingView(shortcut: shortcut, isSelected: isSelected, size: .small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isSelected ? (colorScheme == .dark ? Color.white.opacity(0.1) : Color.accentColor.opacity(0.8)) : Color.clear
        )
    }
}

// MARK: - App Icon View

struct AppIconView: View {
    let bundleIdentifier: String
    @State private var icon: NSImage?
    
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
    }
    
    private func loadIcon() {
        guard let app = AppSearchManager.shared.getApp(by: bundleIdentifier) else { return }
        
        Task {
            let loadedIcon = await AppSearchManager.shared.getAppIcon(for: app)
            await MainActor.run {
                self.icon = loadedIcon
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
