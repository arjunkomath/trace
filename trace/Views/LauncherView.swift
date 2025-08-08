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
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Animation.focusDelay) {
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
    }
    
    // MARK: - Data
    
    var hasResults: Bool {
        !searchText.isEmpty && !results.isEmpty
    }
    
    var results: [SearchResult] {
        guard !searchText.isEmpty else { return [] }
        
        let searchLower = searchText.lowercased()
        var allResults: [SearchResult] = []
        
        // Add app results first (most common use case)
        let apps = AppSearchManager.shared.searchApps(query: searchText, limit: 8)
        let appResults = apps.map { app in
            SearchResult(
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
        }
        allResults.append(contentsOf: appResults)
        
        // Add system commands with fuzzy matching
        var systemCommands: [(SearchResult, Double)] = []
        
        // Settings command
        let settingsScore = matchesSearchTerms(query: searchLower, terms: [
            "trace settings", "settings", "preferences", "config", "configuration", 
            "trace", "setup", "options", "prefs"
        ])
        if settingsScore > 0 {
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
            ), settingsScore))
        }
        
        // Quit command
        let quitScore = matchesSearchTerms(query: searchLower, terms: [
            "quit trace", "quit", "exit", "close", "terminate", "stop", "end"
        ])
        if quitScore > 0 {
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
            ), quitScore))
        }
        
        // Sort system commands by score and add to results
        let sortedSystemCommands = systemCommands
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
        allResults.append(contentsOf: sortedSystemCommands)
        
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
        allResults.append(googleSearchResult)
        
        return allResults
    }
    
    // MARK: - Actions
    
    func executeSelectedResult() {
        guard selectedIndex < results.count else { return }
        results[selectedIndex].action()
        searchText = ""
        selectedIndex = 0
        onClose()
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
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.white.opacity(0.1) : Color.secondary.opacity(0.08))
                )
            
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
