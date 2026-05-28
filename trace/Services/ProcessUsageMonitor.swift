//
//  ProcessUsageMonitor.swift
//  trace
//
//  Created by Codex on 25/5/2026.
//

import Foundation
import Darwin

struct ProcessUsageSnapshot: Equatable {
    let bundleIdentifier: String
    let processIdentifier: pid_t
    let cpuPercent: Double?
    let memoryFootprintBytes: UInt64
    let sampledAt: Date

    var cpuDisplayText: String? {
        guard let cpuPercent else { return nil }
        let displayPercent = max(0, cpuPercent)

        if displayPercent < 10 {
            return String(format: "%.1f%%", displayPercent)
        }

        return "\(Int(displayPercent.rounded()))%"
    }

    var memoryMegabytes: Int {
        let megabyte = UInt64(1024 * 1024)
        return Int((memoryFootprintBytes + megabyte - 1) / megabyte)
    }

    var memoryDisplayText: String {
        let megabytes = memoryMegabytes

        guard megabytes > 1000 else {
            return "\(megabytes) MB"
        }

        let gigabytes = Double(megabytes) / 1024
        let roundedGigabytes = (gigabytes * 10).rounded() / 10

        if roundedGigabytes == Double(Int(roundedGigabytes)) {
            return "\(Int(roundedGigabytes)) GB"
        }

        return String(format: "%.1f GB", roundedGigabytes)
    }

    var normalDisplayText: String {
        if let cpuDisplayText {
            return "CPU \(cpuDisplayText) · \(memoryDisplayText)"
        }

        return memoryDisplayText
    }

    var compactDisplayText: String {
        if let cpuDisplayText {
            return "\(cpuDisplayText) · \(memoryDisplayText)"
        }

        return memoryDisplayText
    }
}

final class ProcessUsageMonitor {
    private static let minimumCPUCalculationInterval: TimeInterval = 0.5

    private struct RawProcessSample {
        let cumulativeCPUTimeByProcess: [ProcessIdentity: TimeInterval]
        let memoryFootprintBytes: UInt64
        let sampledAt: Date
        let processCount: Int
        let sampleSources: Set<ProcessUsageSampleSource>

        var cumulativeCPUTime: TimeInterval {
            cumulativeCPUTimeByProcess.values.reduce(0, +)
        }

        var sampleSourceDescription: String {
            sampleSources.map(\.rawValue).sorted().joined(separator: ",")
        }
    }

    private struct CPUCalculation {
        let percent: Double
        let elapsedTime: TimeInterval
        let cpuTime: TimeInterval
    }

    private let logger = AppLogger.processUsageMonitor
    private let sampler: ProcessUsageSampling
    private let queue = DispatchQueue(label: "com.trace.process-usage-monitor", qos: .utility)
    private var lastSamples: [pid_t: RawProcessSample] = [:]
    private var cachedSnapshots: [pid_t: ProcessUsageSnapshot] = [:]

    init(sampler: ProcessUsageSampling = DarwinProcessUsageSampler()) {
        self.sampler = sampler
    }

    func cachedSnapshot(for processIdentifier: pid_t, maxAge: TimeInterval? = nil) -> ProcessUsageSnapshot? {
        queue.sync {
            guard let snapshot = cachedSnapshots[processIdentifier] else { return nil }

            if let maxAge, Date().timeIntervalSince(snapshot.sampledAt) > maxAge {
                return nil
            }

            return snapshot
        }
    }

    func refreshSnapshot(
        for runningApp: RunningApplicationInfo,
        force: Bool = false,
        staleAfter: TimeInterval = AppConstants.Search.usagePassiveRefreshStaleness
    ) async -> ProcessUsageSnapshot? {
        if !force,
           let cachedSnapshot = cachedSnapshot(for: runningApp.processIdentifier, maxAge: staleAfter) {
            return cachedSnapshot
        }

        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                let snapshot = self.sampleLocked(
                    for: runningApp,
                    shouldLogDebug: force
                )
                continuation.resume(returning: snapshot)
            }
        }
    }

    func refreshSnapshotsIfStale(
        for runningApps: [RunningApplicationInfo],
        staleAfter: TimeInterval = AppConstants.Search.usagePassiveRefreshStaleness
    ) async -> [String: ProcessUsageSnapshot] {
        var snapshots: [String: ProcessUsageSnapshot] = [:]

        for runningApp in runningApps {
            guard !Task.isCancelled else { break }

            if let snapshot = await refreshSnapshot(for: runningApp, staleAfter: staleAfter) {
                snapshots[runningApp.bundleIdentifier] = snapshot
            }
        }

        return snapshots
    }

    func clearSnapshots(for processIdentifiers: [pid_t]) {
        queue.async { [weak self] in
            guard let self else { return }

            for processIdentifier in processIdentifiers {
                self.lastSamples.removeValue(forKey: processIdentifier)
                self.cachedSnapshots.removeValue(forKey: processIdentifier)
            }
        }
    }

    private func sampleLocked(
        for runningApp: RunningApplicationInfo,
        shouldLogDebug: Bool = false
    ) -> ProcessUsageSnapshot? {
        guard let rawSample = readProcessSample(processIdentifier: runningApp.processIdentifier) else {
            lastSamples.removeValue(forKey: runningApp.processIdentifier)
            cachedSnapshots.removeValue(forKey: runningApp.processIdentifier)
            logger.debug("Failed to read process usage for pid \(runningApp.processIdentifier)")
            return nil
        }

        let previousSample = lastSamples[runningApp.processIdentifier]
        lastSamples[runningApp.processIdentifier] = rawSample

        let cpuCalculation = Self.cpuCalculation(from: previousSample, to: rawSample)
        let cpuPercent = cpuCalculation?.percent
        let snapshot = ProcessUsageSnapshot(
            bundleIdentifier: runningApp.bundleIdentifier,
            processIdentifier: runningApp.processIdentifier,
            cpuPercent: cpuPercent,
            memoryFootprintBytes: rawSample.memoryFootprintBytes,
            sampledAt: rawSample.sampledAt
        )

        cachedSnapshots[runningApp.processIdentifier] = snapshot

        #if DEBUG
        if shouldLogDebug {
            logDebugSample(
                runningApp: runningApp,
                previousSample: previousSample,
                currentSample: rawSample,
                cpuCalculation: cpuCalculation
            )
        }
        #endif

        return snapshot
    }

    #if DEBUG
    private func logDebugSample(
        runningApp: RunningApplicationInfo,
        previousSample: RawProcessSample?,
        currentSample: RawProcessSample,
        cpuCalculation: CPUCalculation?
    ) {
        let memoryMegabytes = currentSample.memoryFootprintBytes / UInt64(1024 * 1024)

        guard let previousSample, let cpuCalculation else {
            logger.debug(
                """
                CPU sample baseline bundle=\(runningApp.bundleIdentifier, privacy: .public) \
                pid=\(runningApp.processIdentifier) \
                processes=\(currentSample.processCount) \
                sources=\(currentSample.sampleSourceDescription, privacy: .public) \
                cumulative=\(currentSample.cumulativeCPUTime, format: .fixed(precision: 6))s \
                memory=\(memoryMegabytes)MB
                """
            )
            return
        }

        logger.debug(
            """
            CPU sample bundle=\(runningApp.bundleIdentifier, privacy: .public) \
            pid=\(runningApp.processIdentifier) \
            processes=\(currentSample.processCount) \
            sources=\(currentSample.sampleSourceDescription, privacy: .public) \
            previous=\(previousSample.cumulativeCPUTime, format: .fixed(precision: 6))s \
            current=\(currentSample.cumulativeCPUTime, format: .fixed(precision: 6))s \
            delta=\(cpuCalculation.cpuTime, format: .fixed(precision: 6))s \
            elapsed=\(cpuCalculation.elapsedTime, format: .fixed(precision: 3))s \
            cpu=\(cpuCalculation.percent, format: .fixed(precision: 3))% \
            memory=\(memoryMegabytes)MB
            """
        )
    }
    #endif

    private func readProcessSample(processIdentifier: pid_t) -> RawProcessSample? {
        readProcessSample(processIdentifiers: [processIdentifier])
    }

    private func readProcessSample(processIdentifiers: [pid_t]) -> RawProcessSample? {
        let sampledAt = Date()
        var cumulativeCPUTimeByProcess: [ProcessIdentity: TimeInterval] = [:]
        var memoryFootprintBytes: UInt64 = 0
        var processCount = 0
        var sampleSources: Set<ProcessUsageSampleSource> = []

        for processIdentifier in processIdentifiers {
            guard let processSample = sampler.sample(processIdentifier: processIdentifier) else {
                continue
            }

            cumulativeCPUTimeByProcess[processSample.identity] = processSample.cumulativeCPUTime
            memoryFootprintBytes += processSample.memoryFootprintBytes
            processCount += 1
            sampleSources.insert(processSample.source)
        }

        guard processCount > 0 else { return nil }

        return RawProcessSample(
            cumulativeCPUTimeByProcess: cumulativeCPUTimeByProcess,
            memoryFootprintBytes: memoryFootprintBytes,
            sampledAt: sampledAt,
            processCount: processCount,
            sampleSources: sampleSources
        )
    }

    private static func cpuCalculation(from previousSample: RawProcessSample?, to currentSample: RawProcessSample) -> CPUCalculation? {
        guard let previousSample else { return nil }

        let elapsedTime = currentSample.sampledAt.timeIntervalSince(previousSample.sampledAt)
        var cpuTime: TimeInterval = 0
        var comparableProcessCount = 0

        guard elapsedTime >= minimumCPUCalculationInterval else { return nil }

        for (processIdentity, currentCPUTime) in currentSample.cumulativeCPUTimeByProcess {
            guard let previousCPUTime = previousSample.cumulativeCPUTimeByProcess[processIdentity] else {
                continue
            }

            let processCPUTime = currentCPUTime - previousCPUTime
            guard processCPUTime >= 0 else { continue }

            cpuTime += processCPUTime
            comparableProcessCount += 1
        }

        guard elapsedTime > 0, comparableProcessCount > 0 else { return nil }

        let percent = (cpuTime / elapsedTime) * 100
        guard percent.isFinite else { return nil }

        return CPUCalculation(
            percent: percent,
            elapsedTime: elapsedTime,
            cpuTime: cpuTime
        )
    }
}
