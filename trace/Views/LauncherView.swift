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

    @State var searchText = ""
    @State var selectedIndex = 0
    @State var selectedActionIndex = 0 // Track which action is selected
    @FocusState private var isSearchFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openSettings) var openSettings
    @ObservedObject var services = ServiceContainer.shared
    @ObservedObject var settingsManager = SettingsManager.shared
    @State var cachedResults: [SearchResult] = [] // Background-computed results
    @State var isSearching = false // Track if background search is running
    @State var currentSearchTask: Task<Void, Never>? // Track current search task
    @StateObject var actionExecutor = ActionExecutor() // Handle async actions
    @State var showActionsMenu = false // Track if actions menu is visible
    
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
            if showActionsMenu {
                showActionsMenu = false
            } else {
                clearSearch()
                onClose()
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
        .onKeyPress(.leftArrow) {
            if selectedIndex < results.count && results[selectedIndex].hasMultipleActions {
                if selectedActionIndex > 0 {
                    selectedActionIndex -= 1
                }
            }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            if selectedIndex < results.count && results[selectedIndex].hasMultipleActions {
                let actionCount = results[selectedIndex].allActions.count
                if selectedActionIndex < actionCount - 1 {
                    selectedActionIndex += 1
                }
            }
            return .handled
        }
    }
}
