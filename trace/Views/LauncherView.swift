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
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @State var cachedResults: [SearchResult] = [] // Background-computed results
    @State var currentSearchTask: Task<Void, Never>? // Track current search task
    @StateObject var actionExecutor = ActionExecutor() // Handle async actions
    @StateObject var eventPublisher = ResultEventPublisher() // Event publisher for result updates
    @State var cancellables = Set<AnyCancellable>() // Combine cancellables
    @State var passiveUsageRefreshTask: Task<Void, Never>?
    @State var focusedUsagePollingTask: Task<Void, Never>?

    let onClose: () -> Void

    private var effectiveColorScheme: ColorScheme {
        appearanceManager.colorScheme
    }

    private var theme: TraceTheme {
        TraceTheme(accent: settingsManager.selectedAccent, colorScheme: effectiveColorScheme)
    }

    var body: some View {
        liquidGlassContainer(spacing: 12) {
            VStack(spacing: 0) {
                // Search Input - Fixed height section
                HStack(spacing: 12) {
                    Image(systemName: "filemenu.and.selection")
                        .font(.system(size: 16))
                        .foregroundColor(theme.accentForegroundSecondary)

                    TextField("What would you like to do?", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18))
                        .focused($isSearchFocused)
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
                                .foregroundColor(theme.accentForegroundSecondary)
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
                            .overlay(theme.accentBorder)
                            .opacity(0.45)

                        // Results header
                        HStack {
                            Text("Results")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.accentForegroundSecondary)
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
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: AppConstants.Window.launcherWidth)
            .background(
                RoundedRectangle(cornerRadius: adaptiveCornerRadius)
                    .fill(theme.accentGlassTint)
            )
            .liquidGlassEffect(interactive: true)
            .clipShape(RoundedRectangle(cornerRadius: adaptiveCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: adaptiveCornerRadius)
                    .stroke(theme.accentBorder, lineWidth: 0.5)
            )
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
        }
        .onDisappear {
            currentSearchTask?.cancel()
            cancelUsageSampling()
            cancellables.removeAll()
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
}
