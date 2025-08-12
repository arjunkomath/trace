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
    
    /// Calculate search results using provider system
    func calculateSearchResults(query: String) async -> [SearchResult] {
        let runningApps = services.appSearchManager.getRunningAppBundleIds()
        let searchCoordinator = createSearchCoordinator()
        
        return await searchCoordinator.search(
            query: query,
            services: services,
            runningApps: runningApps,
            eventPublisher: eventPublisher
        )
    }
    
    /// Create search coordinator with all providers
    private func createSearchCoordinator() -> SearchCoordinator {
        let providers: [ResultProvider] = [
            AppResultProvider(),
            SystemCommandProvider(
                clearSearch: clearSearch,
                onClose: onClose,
                openSettings: { openSettings() }
            ),
            NetworkCommandProvider(),
            ControlCenterProvider(),
            WindowManagementProvider(),
            FolderProvider(),
            MathResultProvider(),
            SearchEngineProvider()
        ]
        
        return SearchCoordinator(providers: providers)
    }
    
    
    /// Generate command identifier from title
    func getCommandIdentifier(for title: String) -> String {
        return "com.trace.command.\(title.lowercased().replacingOccurrences(of: " ", with: "_"))"
    }
    
    /// Setup reactive event handling for result updates
    func setupResultEventHandling() {
        eventPublisher.events
            .receive(on: DispatchQueue.main)
            .sink { event in
                handleResultUpdate(event)
            }
            .store(in: &cancellables)
    }
    
    /// Handle result update events reactively
    private func handleResultUpdate(_ event: ResultUpdateEvent) {
        switch event {
        case .loading(let commandId):
            updateResultState(commandId: commandId) { result in
                return SearchResult(
                    title: result.title,
                    subtitle: result.subtitle,
                    icon: result.icon,
                    type: result.type,
                    category: result.category,
                    shortcut: result.shortcut,
                    lastUsed: result.lastUsed,
                    commandId: result.commandId,
                    isLoading: true,
                    accessory: result.accessory,
                    commandAction: result.commandAction
                )
            }
        case .completed(let commandId, let title, let subtitle, let accessory):
            updateResultState(commandId: commandId) { result in
                return SearchResult(
                    title: title,
                    subtitle: subtitle,
                    icon: result.icon,
                    type: result.type,
                    category: result.category,
                    shortcut: result.shortcut,
                    lastUsed: result.lastUsed,
                    commandId: result.commandId,
                    isLoading: false,
                    accessory: accessory,
                    commandAction: result.commandAction
                )
            }
        case .failed(let commandId, let error):
            updateResultState(commandId: commandId) { result in
                return SearchResult(
                    title: result.title,
                    subtitle: error,
                    icon: result.icon,
                    type: result.type,
                    category: result.category,
                    shortcut: result.shortcut,
                    lastUsed: result.lastUsed,
                    commandId: result.commandId,
                    isLoading: false,
                    accessory: .status("Error", .red),
                    commandAction: result.commandAction
                )
            }
        }
    }
    
    /// Update individual result state
    private func updateResultState(commandId: String, transform: (SearchResult) -> SearchResult) {
        if let index = cachedResults.firstIndex(where: { $0.commandId == commandId }) {
            cachedResults[index] = transform(cachedResults[index])
        }
    }
    
    // MARK: - Helper Functions
    
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
