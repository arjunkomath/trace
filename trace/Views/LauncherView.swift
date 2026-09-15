//
//  LauncherView.swift
//  trace
//
//  Created by Arjun on 7/8/2025.
//

import SwiftUI
import AppKit
import Combine

struct LauncherView: View {

    @State var searchText = ""
    @State var selectedIndex = 0
    @State var selectedActionIndex = 0 // Track which action is selected
    @FocusState private var isSearchFocused: Bool
    @Environment(\.openSettings) var openSettings
    @ObservedObject var services = ServiceContainer.shared
    @ObservedObject var settingsManager = SettingsManager.shared
    @State var cachedResults: [SearchResult] = [] // Background-computed results
    @State var currentSearchTask: Task<Void, Never>? // Track current search task
    @StateObject var actionExecutor = ActionExecutor() // Handle async actions
    @StateObject var eventPublisher = ResultEventPublisher() // Event publisher for result updates
    @State var cancellables = Set<AnyCancellable>() // Combine cancellables
    @State var passiveUsageRefreshTask: Task<Void, Never>?
    @State var focusedUsagePollingTask: Task<Void, Never>?

    let onClose: () -> Void

    // Keep semantic text and material colors legible on the launcher's black surface.
    private let effectiveColorScheme: ColorScheme = .dark

    var body: some View {
        liquidGlassContainer(spacing: 0) {
            VStack(spacing: 10) {
                // Search Input - Fixed height section
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    TextField("Search apps, commands, and quick links", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22))
                        .foregroundStyle(.primary)
                        .focused($isSearchFocused)
                        .accessibilityLabel("Search Trace")
                        .onChange(of: searchText) { _, newValue in
                            selectedIndex = 0
                            selectedActionIndex = 0

                            // Cancel any existing search task
                            currentSearchTask?.cancel()

                            // Clear results immediately if search is empty
                            if newValue.isEmpty {
                                cachedResults = []
                                cancelUsageSampling()
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
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                        .help("Clear search (Esc)")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(height: AppConstants.Window.launcherHeight)
                .background(containerGradient(topOpacity: 0.95), in: Capsule())
                .glassEffect(.regular, in: Capsule())
                .clipShape(Capsule())

                // Results section - expandable
                if hasResults {
                    VStack(spacing: 0) {
                        // Results header
                        HStack {
                            Text("Results")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            Spacer()
                        }

                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                                        Group {
                                            if ResultsLayout(rawValue: settingsManager.settings.resultsLayout) == .compact {
                                                CompactResultRowView(
                                                    result: getResultWithLoadingState(result),
                                                    isSelected: index == selectedIndex
                                                )
                                            } else {
                                                ResultRowView(
                                                    result: getResultWithLoadingState(result),
                                                    isSelected: index == selectedIndex
                                                )
                                            }
                                        }
                                        .id(index)
                                        .onTapGesture {
                                            selectedIndex = index
                                            selectedActionIndex = 0
                                            executeSelectedResult()
                                        }
                                    }
                                }
                            }
                            .onChange(of: selectedIndex) { _, newIndex in
                                withAnimation(.easeOut(duration: 0.2)) {
                                    proxy.scrollTo(newIndex, anchor: .center)
                                }
                                restartFocusedUsagePolling()
                            }
                        }
                        .frame(maxHeight: AppConstants.Window.maxResultsHeight)

                        // Footer showing available actions and shortcuts
                        LauncherFooterView(
                            selectedResult: selectedIndex < results.count ? results[selectedIndex] : nil,
                            selectedActionIndex: selectedActionIndex
                        )
                    }
                    .background(
                        containerGradient(topOpacity: 0.3),
                        in: RoundedRectangle(cornerRadius: adaptiveCornerRadius)
                    )
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: adaptiveCornerRadius))
                    .clipShape(RoundedRectangle(cornerRadius: adaptiveCornerRadius))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: AppConstants.Window.launcherWidth)
            .shadow(
                color: Color.black.opacity(effectiveColorScheme == .dark ? 0.4 : 0.2),
                radius: AppConstants.Window.shadowRadius * 0.8,
                x: AppConstants.Window.shadowOffset.width,
                y: AppConstants.Window.shadowOffset.height
            )
        }
        .traceThemed(accent: settingsManager.selectedAccent, colorScheme: effectiveColorScheme)
        .preferredColorScheme(effectiveColorScheme)
        .padding(AppConstants.Window.searchPadding)
        .onAppear {
            clearSearch()
            services.appSearchManager.refreshIfStale()
            setupResultEventHandling()
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
                services.appSearchManager.refreshIfStale()
                refreshUsageBadgesForVisibleResults()
                isSearchFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .launcherWindowWillHide)) { _ in
            cancelUsageSampling()
            clearSearch()
        }
        .onChange(of: results.count) { _, _ in
            notifyContentSizeDidChange()
        }
        .onDisappear {
            currentSearchTask?.cancel()
            cancelUsageSampling()
            cancellables.removeAll()
        }
        .onKeyPress(.escape) {
            if searchText.isEmpty {
                onClose()
            } else {
                clearSearch()
                isSearchFocused = true
            }
            return .handled
        }
        .onKeyPress(.return) {
            executeSelectedResult()
            return .handled
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
                selectedActionIndex = 0 // Reset action selection when changing results
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < results.count - 1 {
                selectedIndex += 1
                selectedActionIndex = 0 // Reset action selection when changing results
            }
            return .handled
        }
        .onKeyPress(.tab) {
            if selectedIndex < results.count && results[selectedIndex].hasMultipleActions {
                let actionCount = results[selectedIndex].allActions.count
                selectedActionIndex = (selectedActionIndex + 1) % actionCount
            }
            return .handled
        }
    }

    private func containerGradient(topOpacity: Double) -> LinearGradient {
        LinearGradient(
            colors: [.black.opacity(topOpacity), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func notifyContentSizeDidChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .launcherContentSizeDidChange, object: nil)
        }
    }
}
