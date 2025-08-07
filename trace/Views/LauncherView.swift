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
    // MARK: - Constants
    private enum Constants {
        static let windowWidth: CGFloat = 750
        static let windowHeight: CGFloat = 60
        static let maxResultsHeight: CGFloat = 300
        static let searchPadding: CGFloat = 30
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 12
        static let shadowOffset = CGSize(width: 0, height: 6)
        static let commaKeyCode: CGKeyCode = 0x2B
    }
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @FocusState private var isSearchFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Input - Fixed height section
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary.opacity(0.6))
                
                TextField("What would you like to find today?", text: $searchText)
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
            .frame(height: Constants.windowHeight)
            
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
                    .frame(maxHeight: Constants.maxResultsHeight)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: Constants.windowWidth)
        .background(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .fill(.regularMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.15), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.6 : 0.3),
            radius: Constants.shadowRadius,
            x: Constants.shadowOffset.width,
            y: Constants.shadowOffset.height
        )
        .padding(Constants.searchPadding)
        .onAppear {
            searchText = ""
            selectedIndex = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
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
        
        var allResults: [SearchResult] = []
        
        // Add command results
        let commandResults = [
            SearchResult(
                title: "Trace Settings",
                subtitle: "Preferences",
                icon: .system("gearshape"),
                type: .command,
                category: nil,
                shortcut: KeyboardShortcut(key: ",", modifiers: ["⌘"]),
                lastUsed: nil,
                action: {
                    // Simulate Cmd+, keypress which we know works
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let source = CGEventSource(stateID: .combinedSessionState)
                        
                        // Create keydown event for comma with command modifier
                        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: Constants.commaKeyCode, keyDown: true)
                        keyDown?.flags = .maskCommand
                        keyDown?.post(tap: .cghidEventTap)
                        
                        // Create keyup event
                        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: Constants.commaKeyCode, keyDown: false)
                        keyUp?.flags = .maskCommand
                        keyUp?.post(tap: .cghidEventTap)
                    }
                }
            )
        ]
        
        let filteredCommands = commandResults.filter { result in
            let searchLower = searchText.lowercased()
            let titleLower = result.title.lowercased()
            let subtitleLower = (result.subtitle ?? "").lowercased()
            
            return titleLower.contains(searchLower) || 
                   subtitleLower.contains(searchLower) ||
                   "settings".contains(searchLower)
        }
        
        // Add app results
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
        
        // Combine results: apps first, then commands
        allResults.append(contentsOf: appResults)
        allResults.append(contentsOf: filteredCommands)
        
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
    
    func openSettings() {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showPreferences()
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
                        .font(.system(size: 16))
                case .emoji(let emoji):
                    Text(emoji)
                        .font(.system(size: 18))
                case .image(let image):
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .app(let bundleIdentifier):
                    AppIconView(bundleIdentifier: bundleIdentifier)
                        .frame(width: 16, height: 16)
                }
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .frame(width: 24, height: 24)
            
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
                .foregroundColor(isSelected ? .white.opacity(0.6) : .secondary.opacity(0.5))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.white.opacity(0.1) : Color.secondary.opacity(0.08))
                )
            
            // Shortcut
            if let shortcut = result.shortcut {
                HStack(spacing: 2) {
                    ForEach(shortcut.modifiers + [shortcut.key], id: \.self) { key in
                        Text(key)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary.opacity(0.6))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.1))
                            )
                    }
                }
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
        if let app = AppSearchManager.shared.getApp(by: bundleIdentifier) {
            AppSearchManager.shared.getAppIcon(for: app) { loadedIcon in
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