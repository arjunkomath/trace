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
    let residentMemoryBytes: UInt64
    let sampledAt: Date

    var cpuDisplayText: String? {
        guard let cpuPercent else { return nil }

        if cpuPercent >= 0.05, cpuPercent < 1 {
            return "<1%"
        }

        return "\(max(0, Int(cpuPercent.rounded())))%"
    }

    var residentMemoryMegabytes: Int {
        let megabyte = UInt64(1024 * 1024)
        return Int((residentMemoryBytes + megabyte - 1) / megabyte)
    }

    var residentMemoryDisplayText: String {
        let megabytes = residentMemoryMegabytes

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
            return "CPU \(cpuDisplayText) · \(residentMemoryDisplayText)"
        }

        return residentMemoryDisplayText
    }

    var compactDisplayText: String {
        if let cpuDisplayText {
            return "\(cpuDisplayText) · \(residentMemoryDisplayText)"
        }

        return residentMemoryDisplayText
    }
}

final class ProcessUsageMonitor {
    private struct RawProcessSample {
        let cumulativeCPUTime: TimeInterval
        let residentMemoryBytes: UInt64
        let sampledAt: Date
        let processCount: Int
    }

    private struct CPUCalculation {
        let percent: Double
        let elapsedTime: TimeInterval
        let cpuTime: TimeInterval
    }

    private struct ProcessGroupCacheEntry {
        let processIdentifiers: [pid_t]
        let cachedAt: Date
    }

    private let logger = AppLogger.processUsageMonitor
    private let queue = DispatchQueue(label: "com.trace.process-usage-monitor", qos: .utility)
    private var lastSamples: [pid_t: RawProcessSample] = [:]
    private var cachedSnapshots: [pid_t: ProcessUsageSnapshot] = [:]
    private var processGroupCache: [pid_t: ProcessGroupCacheEntry] = [:]

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
                    aggregatesHelpers: force,
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
                self.processGroupCache.removeValue(forKey: processIdentifier)
            }
        }
    }

    private func sampleLocked(
        for runningApp: RunningApplicationInfo,
        aggregatesHelpers: Bool = false,
        shouldLogDebug: Bool = false
    ) -> ProcessUsageSnapshot? {
        let processIdentifiers = aggregatesHelpers
            ? processGroupProcessIdentifiers(for: runningApp.processIdentifier)
            : [runningApp.processIdentifier]

        guard let rawSample = Self.readProcessSample(processIdentifiers: processIdentifiers) else {
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
            residentMemoryBytes: rawSample.residentMemoryBytes,
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

    private func processGroupProcessIdentifiers(for rootProcessIdentifier: pid_t) -> [pid_t] {
        let now = Date()

        if let cacheEntry = processGroupCache[rootProcessIdentifier],
           now.timeIntervalSince(cacheEntry.cachedAt) < 5 {
            return cacheEntry.processIdentifiers
        }

        let processIdentifiers = Self.descendantProcessIdentifiers(rootProcessIdentifier: rootProcessIdentifier)
        processGroupCache[rootProcessIdentifier] = ProcessGroupCacheEntry(
            processIdentifiers: processIdentifiers,
            cachedAt: now
        )

        return processIdentifiers
    }

    #if DEBUG
    private func logDebugSample(
        runningApp: RunningApplicationInfo,
        previousSample: RawProcessSample?,
        currentSample: RawProcessSample,
        cpuCalculation: CPUCalculation?
    ) {
        let memoryMegabytes = currentSample.residentMemoryBytes / UInt64(1024 * 1024)

        guard let previousSample, let cpuCalculation else {
            logger.debug(
                """
                CPU sample baseline bundle=\(runningApp.bundleIdentifier, privacy: .public) \
                pid=\(runningApp.processIdentifier) \
                processes=\(currentSample.processCount) \
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

    private static func readProcessSample(processIdentifier: pid_t) -> RawProcessSample? {
        readProcessSample(processIdentifiers: [processIdentifier])
    }

    private static func readProcessSample(processIdentifiers: [pid_t]) -> RawProcessSample? {
        let sampledAt = Date()
        var cumulativeCPUTime: TimeInterval = 0
        var residentMemoryBytes: UInt64 = 0
        var processCount = 0

        for processIdentifier in processIdentifiers {
            guard let processSample = readSingleProcessSample(processIdentifier: processIdentifier) else {
                continue
            }

            cumulativeCPUTime += processSample.cumulativeCPUTime
            residentMemoryBytes += processSample.residentMemoryBytes
            processCount += 1
        }

        guard processCount > 0 else { return nil }

        return RawProcessSample(
            cumulativeCPUTime: cumulativeCPUTime,
            residentMemoryBytes: residentMemoryBytes,
            sampledAt: sampledAt,
            processCount: processCount
        )
    }

    private static func readSingleProcessSample(processIdentifier: pid_t) -> RawProcessSample? {
        var taskInfo = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.stride)
        let result = withUnsafeMutablePointer(to: &taskInfo) { pointer in
            proc_pidinfo(processIdentifier, PROC_PIDTASKINFO, 0, pointer, size)
        }

        guard result == size else { return nil }

        let cumulativeCPUTime = taskInfo.pti_total_user
            + taskInfo.pti_total_system
            + taskInfo.pti_threads_user
            + taskInfo.pti_threads_system

        return RawProcessSample(
            cumulativeCPUTime: TimeInterval(cumulativeCPUTime) / TimeInterval(NSEC_PER_SEC),
            residentMemoryBytes: UInt64(taskInfo.pti_resident_size),
            sampledAt: Date(),
            processCount: 1
        )
    }

    private static func descendantProcessIdentifiers(rootProcessIdentifier: pid_t) -> [pid_t] {
        let processIdentifiers = allProcessIdentifiers()
        guard !processIdentifiers.isEmpty else { return [rootProcessIdentifier] }

        var childrenByParent: [pid_t: [pid_t]] = [:]

        for processIdentifier in processIdentifiers where processIdentifier > 0 && processIdentifier != rootProcessIdentifier {
            guard let parentIdentifier = parentProcessIdentifier(for: processIdentifier) else {
                continue
            }

            childrenByParent[parentIdentifier, default: []].append(processIdentifier)
        }

        var processGroup = [rootProcessIdentifier]
        var pending = childrenByParent[rootProcessIdentifier] ?? []

        while let processIdentifier = pending.popLast() {
            processGroup.append(processIdentifier)
            pending.append(contentsOf: childrenByParent[processIdentifier] ?? [])
        }

        return processGroup
    }

    private static func allProcessIdentifiers() -> [pid_t] {
        let processIdentifierBytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, nil, 0)
        guard processIdentifierBytes > 0 else { return [] }

        let processIdentifierCount = Int(processIdentifierBytes) / MemoryLayout<pid_t>.stride
        var processIdentifiers = [pid_t](repeating: 0, count: processIdentifierCount)

        let resultBytes = processIdentifiers.withUnsafeMutableBufferPointer { buffer in
            proc_listpids(UInt32(PROC_ALL_PIDS), 0, buffer.baseAddress, processIdentifierBytes)
        }

        guard resultBytes > 0 else { return [] }

        let resultCount = min(Int(resultBytes) / MemoryLayout<pid_t>.stride, processIdentifiers.count)
        return Array(processIdentifiers.prefix(resultCount)).filter { $0 > 0 }
    }

    private static func parentProcessIdentifier(for processIdentifier: pid_t) -> pid_t? {
        var bsdInfo = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
        let result = withUnsafeMutablePointer(to: &bsdInfo) { pointer in
            proc_pidinfo(processIdentifier, PROC_PIDTBSDINFO, 0, pointer, size)
        }

        guard result == size else { return nil }
        return pid_t(bsdInfo.pbi_ppid)
    }

    private static func cpuCalculation(from previousSample: RawProcessSample?, to currentSample: RawProcessSample) -> CPUCalculation? {
        guard let previousSample else { return nil }

        let elapsedTime = currentSample.sampledAt.timeIntervalSince(previousSample.sampledAt)
        let cpuTime = currentSample.cumulativeCPUTime - previousSample.cumulativeCPUTime

        guard elapsedTime > 0, cpuTime >= 0 else { return nil }

        return CPUCalculation(
            percent: min((cpuTime / elapsedTime) * 100, 999),
            elapsedTime: elapsedTime,
            cpuTime: cpuTime
        )
    }
}
