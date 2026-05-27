//
//  LauncherUsageBadges.swift
//  trace
//
//  Created by Codex on 25/5/2026.
//

import Foundation

extension LauncherView {
    func refreshUsageBadgesForVisibleResults() {
        applyCachedUsageBadgesForVisibleResults()
        schedulePassiveUsageRefresh()
        restartFocusedUsagePolling()
    }

    func cancelUsageSampling() {
        passiveUsageRefreshTask?.cancel()
        passiveUsageRefreshTask = nil

        focusedUsagePollingTask?.cancel()
        focusedUsagePollingTask = nil
    }

    private func schedulePassiveUsageRefresh() {
        passiveUsageRefreshTask?.cancel()

        let runningApps = visibleRunningApplicationInfos()
        guard !runningApps.isEmpty else { return }

        let monitor = services.processUsageMonitor
        passiveUsageRefreshTask = Task {
            try? await Task.sleep(nanoseconds: AppConstants.Search.usagePassiveRefreshDebounceNanoseconds)
            guard !Task.isCancelled else { return }

            let snapshots = await monitor.refreshSnapshotsIfStale(for: runningApps)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                let currentVisibleApps = Set(visibleRunningApplicationInfos())

                for runningApp in runningApps where currentVisibleApps.contains(runningApp) {
                    if let snapshot = snapshots[runningApp.bundleIdentifier] {
                        updateUsageAccessory(bundleIdentifier: runningApp.bundleIdentifier, snapshot: snapshot)
                    }
                }
            }
        }
    }

    func restartFocusedUsagePolling() {
        focusedUsagePollingTask?.cancel()

        guard let focusedApp = selectedRunningApplicationInfo() else {
            focusedUsagePollingTask = nil
            return
        }

        let monitor = services.processUsageMonitor
        focusedUsagePollingTask = Task {
            try? await Task.sleep(nanoseconds: AppConstants.Search.usageFocusedStartDelayNanoseconds)

            while !Task.isCancelled {
                let isStillFocused = await MainActor.run {
                    selectedRunningApplicationInfo() == focusedApp
                }

                guard isStillFocused else { return }

                let snapshot = await monitor.refreshSnapshot(for: focusedApp, force: true)

                await MainActor.run {
                    guard selectedRunningApplicationInfo() == focusedApp else { return }
                    updateUsageAccessory(bundleIdentifier: focusedApp.bundleIdentifier, snapshot: snapshot)
                }

                guard snapshot != nil else { return }

                try? await Task.sleep(nanoseconds: AppConstants.Search.usageFocusedPollingIntervalNanoseconds)
            }
        }
    }

    private func applyCachedUsageBadgesForVisibleResults() {
        let monitor = services.processUsageMonitor

        for runningApp in visibleRunningApplicationInfos() {
            guard let snapshot = monitor.cachedSnapshot(for: runningApp.processIdentifier) else { continue }
            updateUsageAccessory(bundleIdentifier: runningApp.bundleIdentifier, snapshot: snapshot)
        }
    }

    private func selectedRunningApplicationInfo() -> RunningApplicationInfo? {
        guard selectedIndex < results.count else { return nil }
        return runningApplicationInfo(for: results[selectedIndex])
    }

    private func visibleRunningApplicationInfos() -> [RunningApplicationInfo] {
        var seenBundleIdentifiers: Set<String> = []
        var runningApps: [RunningApplicationInfo] = []

        for result in results {
            guard let runningApp = runningApplicationInfo(for: result),
                  seenBundleIdentifiers.insert(runningApp.bundleIdentifier).inserted else {
                continue
            }

            runningApps.append(runningApp)
        }

        return runningApps
    }

    private func runningApplicationInfo(for result: SearchResult) -> RunningApplicationInfo? {
        guard result.type == .application,
              case .app(let bundleIdentifier) = result.icon else {
            return nil
        }

        return services.appSearchManager.getRunningAppInfo(bundleIdentifier: bundleIdentifier)
    }

    private func updateUsageAccessory(bundleIdentifier: String, snapshot: ProcessUsageSnapshot?) {
        guard let index = cachedResults.firstIndex(where: { result in
            result.type == .application && result.commandId == bundleIdentifier
        }) else {
            return
        }

        let nextAccessory: SearchResultAccessory?
        if let snapshot {
            nextAccessory = .resourceUsage(snapshot)
        } else if services.appSearchManager.isAppRunning(bundleIdentifier: bundleIdentifier) {
            nextAccessory = .runningIndicator
        } else {
            nextAccessory = nil
        }

        guard accessoryDisplayKey(cachedResults[index].accessory) != accessoryDisplayKey(nextAccessory) else {
            return
        }

        cachedResults[index] = cachedResults[index].replacingAccessory(nextAccessory)
    }

    private func accessoryDisplayKey(_ accessory: SearchResultAccessory?) -> String {
        guard let accessory else { return "none" }

        if accessory.isIndicatorDot {
            return "running"
        }

        return accessory.displayText ?? "empty"
    }
}
