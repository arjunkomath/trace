//
//  SystemCommandProvider.swift
//  trace
//
//  Created by Arjun on 12/8/2025.
//

import Foundation
import AppKit

class SystemCommandProvider: ResultProvider {
    private let clearSearch: () -> Void
    private let onClose: () -> Void

    init(clearSearch: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.clearSearch = clearSearch
        self.onClose = onClose
    }

    func getResults(for query: String, context: SearchContext) async -> [(SearchResult, Double)] {
        var results: [(SearchResult, Double)] = []

        // Settings command
        if let settingsResult = createSettingsCommand(query: query, context: context) {
            results.append(settingsResult)
        }

        // Refresh applications command
        if let refreshAppsResult = createRefreshApplicationsCommand(query: query, context: context) {
            results.append(refreshAppsResult)
        }

        // Caffeinate command
        if let caffeinateResult = createCaffeinateCommand(query: query, context: context) {
            results.append(caffeinateResult)
        }

        // Mirror command
        if let mirrorResult = createMirrorCommand(query: query, context: context) {
            results.append(mirrorResult)
        }

        // Quit command
        if let quitResult = createQuitCommand(query: query, context: context) {
            results.append(quitResult)
        }

        return results
    }

    // MARK: - Private Methods

    private func createSettingsCommand(query: String, context: SearchContext) -> (SearchResult, Double)? {
        let settingsMatchScore = matchesSearchTerms(query: query, terms: [
            "trace settings", "settings", "preferences", "config", "configuration",
            "trace", "setup", "options", "prefs", "configure", "hotkeys"
        ])

        let settingsId = "com.trace.command.settings"
        let settingsUsageScore = context.usageScores[settingsId] ?? 0.0

        guard let settingsScore = calculateUnifiedScore(matchScore: settingsMatchScore, usageScore: settingsUsageScore) else {
            return nil
        }

        let settingsResult = createSystemCommand(
            commandId: settingsId,
            title: "Trace Settings",
            subtitle: "Configure hotkeys and preferences",
            icon: "gearshape",
            shortcut: nil,
            operation: createSettingsAction(commandId: settingsId, context: context) {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.showSettings()
                } else {
                    // Try alternative approach
                    NSApp.sendAction(#selector(AppDelegate.showSettings), to: nil, from: nil)
                }
            }
        )

        return (settingsResult, settingsScore)
    }

    private func createRefreshApplicationsCommand(query: String, context: SearchContext) -> (SearchResult, Double)? {
        let refreshMatchScore = matchesSearchTerms(query: query, terms: [
            "refresh applications", "reload applications",
            "rescan applications", "rebuild application cache", "refresh app cache",
            "reload app cache", "refresh apps", "reload apps",
            "find applications", "find apps"
        ])

        let refreshId = "com.trace.command.refresh_applications"
        let refreshUsageScore = context.usageScores[refreshId] ?? 0.0

        guard let refreshScore = calculateUnifiedScore(matchScore: refreshMatchScore, usageScore: refreshUsageScore) else {
            return nil
        }

        let refreshResult = createSystemCommand(
            commandId: refreshId,
            title: "Refresh Applications",
            subtitle: "Rebuild the app list and icon cache",
            icon: "arrow.clockwise",
            shortcut: nil,
            operation: createStandardAction(commandId: refreshId, context: context) {
                context.services.appSearchManager.refreshCache()
                ToastManager.shared.showInfo("Refreshing applications...")
            }
        )

        return (refreshResult, refreshScore)
    }

    private func createCaffeinateCommand(query: String, context: SearchContext) -> (SearchResult, Double)? {
        let caffeinateMatchScore = matchesSearchTerms(query: query, terms: [
            "caffeinate", "start caffeinate", "stop caffeinate", "toggle caffeinate",
            "keep awake", "stay awake", "prevent sleep", "disable sleep",
            "display awake", "keep display awake", "keep mac awake", "sleep"
        ])

        let caffeinateId = "com.trace.command.caffeinate"
        let caffeinateUsageScore = context.usageScores[caffeinateId] ?? 0.0

        guard let caffeinateScore = calculateUnifiedScore(matchScore: caffeinateMatchScore, usageScore: caffeinateUsageScore) else {
            return nil
        }

        let isActive = context.services.caffeinateManager.isActive
        let flags = context.services.settingsManager.settings.caffeinateFlags
        let title = isActive ? "Stop Caffeinate" : "Start Caffeinate"
        let subtitle = isActive ? "Allow your Mac to sleep normally" : "Run /usr/bin/caffeinate \(flags)"
        let icon = isActive ? "cup.and.saucer.fill" : "cup.and.saucer"

        let caffeinateResult = createSystemCommand(
            commandId: caffeinateId,
            title: title,
            subtitle: subtitle,
            icon: icon,
            accessory: isActive ? .status("On", .green) : nil,
            operation: createStandardAction(commandId: caffeinateId, context: context) {
                let manager = context.services.caffeinateManager
                if manager.isActive {
                    manager.stop()
                    ToastManager.shared.showInfo("Caffeinate stopped")
                } else if manager.start() {
                    ToastManager.shared.showSuccess("Caffeinate started")
                }
            }
        )

        return (caffeinateResult, caffeinateScore)
    }

    private func createMirrorCommand(query: String, context: SearchContext) -> (SearchResult, Double)? {
        let mirrorMatchScore = matchesSearchTerms(query: query, terms: [
            "mirror", "show mirror", "camera", "webcam", "webcam preview",
            "camera preview", "video preview", "video check", "appearance check",
            "check camera", "check myself"
        ])

        let mirrorId = "com.trace.command.mirror"
        let mirrorUsageScore = context.usageScores[mirrorId] ?? 0.0

        guard let mirrorScore = calculateUnifiedScore(matchScore: mirrorMatchScore, usageScore: mirrorUsageScore) else {
            return nil
        }

        let mirrorResult = createSystemCommand(
            commandId: mirrorId,
            title: "Show Mirror",
            subtitle: "Open a temporary local webcam preview",
            icon: "video",
            operation: createStandardAction(commandId: mirrorId, context: context) {
                Task { @MainActor in
                    context.services.mirrorManager.show()
                }
            }
        )

        return (mirrorResult, mirrorScore)
    }

    private func createQuitCommand(query: String, context: SearchContext) -> (SearchResult, Double)? {
        let quitMatchScore = matchesSearchTerms(query: query, terms: [
            "quit trace", "quit", "exit", "close", "terminate", "stop", "end", "application"
        ])

        let quitId = "com.trace.command.quit"
        let quitUsageScore = context.usageScores[quitId] ?? 0.0

        guard let quitScore = calculateUnifiedScore(matchScore: quitMatchScore, usageScore: quitUsageScore) else {
            return nil
        }

        let quitResult = createSystemCommand(
            commandId: quitId,
            title: "Quit Trace",
            subtitle: "Exit the application",
            icon: "power",
            shortcut: KeyboardShortcut(key: "Q", modifiers: ["⌘"]),
            operation: createStandardAction(commandId: quitId, context: context) {
                NSApp.terminate(nil)
            }
        )

        return (quitResult, quitScore)
    }

    // MARK: - Helper Methods

    private func createSystemCommand(
        commandId: String,
        title: String,
        subtitle: String,
        icon: String,
        shortcut: KeyboardShortcut? = nil,
        accessory: SearchResultAccessory? = nil,
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
            category: nil,
            shortcut: shortcut,
            lastUsed: nil,
            commandId: commandId,
            accessory: accessory,
            commandAction: commandAction
        )
    }

    private func createStandardAction(commandId: String, context: SearchContext, customAction: @escaping () -> Void) -> () -> Void {
        return { [clearSearch, onClose] in
            context.services.usageTracker.recordUsage(for: commandId, type: UsageType.command)

            DispatchQueue.main.async {
                customAction()
                clearSearch()
                onClose()
            }
        }
    }

    private func createSettingsAction(commandId: String, context: SearchContext, customAction: @escaping () -> Void) -> () -> Void {
        return {
            context.services.usageTracker.recordUsage(for: commandId, type: UsageType.command)

            DispatchQueue.main.async {
                customAction()
                // Don't call clearSearch() or onClose() - let LauncherSearchLogic handle it
            }
        }
    }
}
