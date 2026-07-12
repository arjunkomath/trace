//
//  MenuItemProvider.swift
//  trace
//
//  Created by Codex on 8/7/2026.
//

import AppKit
import ApplicationServices
import Foundation

class MenuItemProvider: ResultProvider {
    static let scopeToken = "menu:"
    static let commandId = "com.trace.command.menu_items"
    static let menuItemCommandPrefix = "com.trace.menu_item."
    static let stateCommandPrefix = "com.trace.menu_state."
    static let scopedResultLimit = AppConstants.Search.defaultLimit

    private let setSearchText: (String) -> Void

    init(setSearchText: @escaping (String) -> Void) {
        self.setSearchText = setSearchText
    }

    func getResults(for query: String, context: SearchContext) async -> [(SearchResult, Double)] {
        guard !Self.isScoped(query) else {
            return []
        }

        let matchScore = matchesSearchTerms(query: query, terms: [
            "search menu items",
            "menu items",
            "menu bar",
            "app menu",
            "application menu",
            "menu"
        ])
        let usageScore = context.usageScores[Self.commandId] ?? 0.0

        guard let score = calculateUnifiedScore(matchScore: matchScore, usageScore: usageScore) else {
            return []
        }

        let action = InstantCommandAction(
            id: Self.commandId,
            displayName: "Search Menu Items",
            iconName: "filemenu.and.selection",
            operation: { [setSearchText] in
                DispatchQueue.main.async {
                    setSearchText(Self.scopeToken)
                    NotificationCenter.default.post(name: .shouldFocusSearchField, object: nil)
                }
            }
        )

        let result = SearchResult(
            title: "Search Menu Items",
            subtitle: "Search the previous app's menu bar",
            icon: .system("filemenu.and.selection"),
            type: .command,
            category: .menuItems,
            shortcut: nil,
            lastUsed: nil,
            commandId: Self.commandId,
            accessory: nil,
            commandAction: action
        )

        return [(result, score)]
    }

    func scopedResults(filter: String, context: SearchContext) async -> [SearchResult] {
        guard AXIsProcessTrusted() else {
            return [permissionRequiredResult(context: context)]
        }

        guard let app = context.services.permissionManager.currentTargetApplication else {
            return [emptyStateResult(
                title: "No Target Application",
                subtitle: "Focus another app, then open Trace again",
                commandId: "\(Self.stateCommandPrefix)no_target"
            )]
        }

        let items: [MenuItem]
        do {
            items = try context.services.menuBarService.menuItems(for: app)
        } catch MenuBarServiceError.permissionDenied {
            return [permissionRequiredResult(context: context)]
        } catch {
            return [emptyStateResult(
                title: "No Menu Items Available",
                subtitle: "\(app.localizedName ?? "This app") does not expose a readable menu bar",
                commandId: "\(Self.stateCommandPrefix)no_menu"
            )]
        }

        guard !items.isEmpty else {
            return [emptyStateResult(
                title: "No Menu Items Available",
                subtitle: "\(app.localizedName ?? "This app") does not expose enabled menu items",
                commandId: "\(Self.stateCommandPrefix)empty"
            )]
        }

        let trimmedFilter = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rankedItems: [(MenuItem, Double)]

        if trimmedFilter.isEmpty {
            rankedItems = items.map { ($0, 1.0) }
        } else {
            rankedItems = items.compactMap { item in
                let fullPath = item.pathTitles.joined(separator: " ").lowercased()
                let titleScore = FuzzyMatcher.match(query: trimmedFilter, text: item.title.lowercased())
                let pathScore = FuzzyMatcher.match(query: trimmedFilter, text: fullPath)
                let score = max(titleScore, pathScore)
                return score > 0.3 ? (item, score) : nil
            }
            .sorted { $0.1 > $1.1 }
        }

        guard !rankedItems.isEmpty else {
            return [emptyStateResult(
                title: "No Matching Menu Items",
                subtitle: "Try a different menu item name",
                commandId: "\(Self.stateCommandPrefix)no_matches"
            )]
        }

        return rankedItems.prefix(Self.scopedResultLimit).map { item, _ in
            menuItemResult(item, app: app, context: context)
        }
    }

    static func isScoped(_ query: String) -> Bool {
        query.lowercased().hasPrefix(scopeToken)
    }

    static func scopedFilter(from query: String) -> String {
        guard isScoped(query) else { return query }
        return String(query.dropFirst(scopeToken.count))
    }

    static func shouldSkipUsageTracking(commandId: String) -> Bool {
        commandId.hasPrefix(menuItemCommandPrefix) || commandId.hasPrefix(stateCommandPrefix)
    }

    static func isStateCommand(commandId: String?) -> Bool {
        commandId?.hasPrefix(stateCommandPrefix) == true
    }

    static func isMenuItemCommand(commandId: String?) -> Bool {
        commandId?.hasPrefix(menuItemCommandPrefix) == true
    }

    private func menuItemResult(
        _ item: MenuItem,
        app: NSRunningApplication,
        context: SearchContext
    ) -> SearchResult {
        let appID = app.bundleIdentifier ?? "unknown_app"
        let commandId = "\(Self.menuItemCommandPrefix)\(sanitizeIdentifierComponent(appID)).\(item.id)"
        let action = MenuItemCommandAction(
            id: commandId,
            displayName: item.title,
            iconName: "filemenu.and.selection",
            keyboardShortcut: item.shortcut?.displayString,
            description: item.pathTitles.joined(separator: " > "),
            item: item,
            app: app,
            menuBarService: context.services.menuBarService
        )

        return SearchResult(
            title: item.title,
            subtitle: subtitle(for: item, app: app),
            icon: .system("filemenu.and.selection"),
            type: .command,
            category: .menuItems,
            shortcut: item.shortcut,
            lastUsed: nil,
            commandId: commandId,
            accessory: nil,
            commandAction: action
        )
    }

    private func subtitle(for item: MenuItem, app: NSRunningApplication) -> String {
        let appName = app.localizedName ?? "Application"
        guard !item.menuPath.isEmpty else {
            return appName
        }
        return "\(appName) • \(item.menuPath)"
    }

    private func permissionRequiredResult(context: SearchContext) -> SearchResult {
        let action = InstantCommandAction(
            id: "\(Self.stateCommandPrefix)grant_accessibility",
            displayName: "Grant Accessibility Access",
            iconName: "hand.raised",
            operation: {
                context.services.permissionManager.requestWindowManagementPermissions()
            }
        )

        return SearchResult(
            title: "Grant Accessibility Access",
            subtitle: "Trace needs Accessibility permission to read menu items",
            icon: .system("hand.raised"),
            type: .command,
            category: .menuItems,
            shortcut: nil,
            lastUsed: nil,
            commandId: "\(Self.stateCommandPrefix)grant_accessibility",
            accessory: .status("Required", .orange),
            commandAction: action
        )
    }

    private func emptyStateResult(title: String, subtitle: String, commandId: String) -> SearchResult {
        let action = InstantCommandAction(
            id: commandId,
            displayName: title,
            iconName: "exclamationmark.circle",
            operation: {}
        )

        return SearchResult(
            title: title,
            subtitle: subtitle,
            icon: .system("exclamationmark.circle"),
            type: .command,
            category: .menuItems,
            shortcut: nil,
            lastUsed: nil,
            commandId: commandId,
            accessory: .status("Unavailable", .secondary),
            commandAction: action
        )
    }

    private func sanitizeIdentifierComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return value
            .lowercased()
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "_" }
            .reduce(into: "") { $0.append($1) }
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}

/// The payload is immutable, and MenuBarService protects its shared cache with a lock.
/// App activation is explicitly marshalled onto the main queue before the AX action runs.
struct MenuItemCommandAction: DisplayableCommandAction, @unchecked Sendable {
    let id: String
    let displayName: String
    let iconName: String?
    let keyboardShortcut: String?
    let description: String?
    let item: MenuItem
    let app: NSRunningApplication
    let menuBarService: MenuBarService
    let showsLoadingState = false

    func execute() async -> ActionResult {
        let success = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: menuBarService.press(item, in: app))
            }
        }
        if success {
            return .success(message: nil, data: nil)
        }
        return .failure(error: "Could not press \(item.title)")
    }
}
