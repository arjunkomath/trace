//
//  ProcessUsageSampler.swift
//  trace
//
//  Created by Codex on 28/5/2026.
//

import Foundation
import Darwin

struct ProcessIdentity: Hashable {
    let processIdentifier: pid_t
    let startIdentifier: UInt64?
}

enum ProcessUsageSampleSource: String {
    case resourceUsage = "proc_pid_rusage"
    case taskInfo = "proc_pidinfo(PROC_PIDTASKINFO)"
}

struct ProcessUsageProcessSample {
    let identity: ProcessIdentity
    let cumulativeCPUTime: TimeInterval
    let memoryFootprintBytes: UInt64
    let source: ProcessUsageSampleSource
}

protocol ProcessUsageSampling {
    func sample(processIdentifier: pid_t) -> ProcessUsageProcessSample?
}

struct DarwinProcessUsageSampler: ProcessUsageSampling {
    private let logger = AppLogger.processUsageMonitor

    /// CPU times from `proc_pid_rusage` and `PROC_PIDTASKINFO` are reported in mach
    /// absolute-time units, not nanoseconds. On Intel the timebase is 1:1 so dividing by
    /// `NSEC_PER_SEC` worked, but on Apple Silicon a tick is ~41.67 ns, which made CPU
    /// usage read ~40x too low. Convert with the mach timebase before scaling to seconds.
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    private static func cpuSeconds(fromMachTicks ticks: UInt64) -> TimeInterval {
        let nanoseconds = Double(ticks) * Double(timebase.numer) / Double(timebase.denom)
        return nanoseconds / Double(NSEC_PER_SEC)
    }

    func sample(processIdentifier: pid_t) -> ProcessUsageProcessSample? {
        let bsdInfo = readBSDInfo(processIdentifier: processIdentifier)

        if let resourceUsageSample = readResourceUsageSample(
            processIdentifier: processIdentifier,
            bsdInfo: bsdInfo
        ) {
            return resourceUsageSample
        }

        return readTaskInfoSample(
            processIdentifier: processIdentifier,
            bsdInfo: bsdInfo
        )
    }

    private func readResourceUsageSample(
        processIdentifier: pid_t,
        bsdInfo: proc_bsdinfo?
    ) -> ProcessUsageProcessSample? {
        guard let resourceUsage = readCurrentResourceUsage(processIdentifier: processIdentifier) else { return nil }

        let cumulativeCPUTime = resourceUsage.ri_user_time + resourceUsage.ri_system_time
        let memoryFootprintBytes = resourceUsage.ri_phys_footprint > 0
            ? resourceUsage.ri_phys_footprint
            : resourceUsage.ri_resident_size

        return ProcessUsageProcessSample(
            identity: processIdentity(
                processIdentifier: processIdentifier,
                bsdInfo: bsdInfo,
                fallbackStartIdentifier: resourceUsage.ri_proc_start_abstime
            ),
            cumulativeCPUTime: Self.cpuSeconds(fromMachTicks: cumulativeCPUTime),
            memoryFootprintBytes: memoryFootprintBytes,
            source: .resourceUsage
        )
    }

    private func readTaskInfoSample(
        processIdentifier: pid_t,
        bsdInfo: proc_bsdinfo?
    ) -> ProcessUsageProcessSample? {
        var taskInfo = proc_taskinfo()
        guard readProcessInfo(
            processIdentifier: processIdentifier,
            flavor: PROC_PIDTASKINFO,
            info: &taskInfo
        ) else {
            return nil
        }

        // pti_total_* is already total CPU time; pti_threads_* is "existing threads only".
        // Adding both double-counts CPU for long-lived threads.
        let cumulativeCPUTime = taskInfo.pti_total_user + taskInfo.pti_total_system

        return ProcessUsageProcessSample(
            identity: processIdentity(
                processIdentifier: processIdentifier,
                bsdInfo: bsdInfo,
                fallbackStartIdentifier: nil
            ),
            cumulativeCPUTime: Self.cpuSeconds(fromMachTicks: cumulativeCPUTime),
            memoryFootprintBytes: UInt64(taskInfo.pti_resident_size),
            source: .taskInfo
        )
    }

    private func readBSDInfo(processIdentifier: pid_t) -> proc_bsdinfo? {
        var bsdInfo = proc_bsdinfo()
        guard readProcessInfo(
            processIdentifier: processIdentifier,
            flavor: PROC_PIDTBSDINFO,
            info: &bsdInfo
        ) else {
            return nil
        }

        return bsdInfo
    }

    private func processIdentity(
        processIdentifier: pid_t,
        bsdInfo: proc_bsdinfo?,
        fallbackStartIdentifier: UInt64?
    ) -> ProcessIdentity {
        let bsdStartIdentifier = bsdInfo.map { info in
            (info.pbi_start_tvsec * 1_000_000) + info.pbi_start_tvusec
        }

        let startIdentifier = bsdStartIdentifier
            ?? (fallbackStartIdentifier == 0 ? nil : fallbackStartIdentifier)

        return ProcessIdentity(
            processIdentifier: processIdentifier,
            startIdentifier: startIdentifier
        )
    }

    private func readCurrentResourceUsage(processIdentifier: pid_t) -> rusage_info_current? {
        var resourceUsage = rusage_info_current()
        let result = withUnsafeMutablePointer(to: &resourceUsage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { reboundPointer in
                proc_pid_rusage(processIdentifier, RUSAGE_INFO_CURRENT, reboundPointer)
            }
        }

        guard result == 0 else {
            logSamplingFailure(
                functionName: "proc_pid_rusage",
                processIdentifier: processIdentifier,
                result: result,
                expectedResult: 0
            )
            return nil
        }

        return resourceUsage
    }

    private func readProcessInfo<T>(
        processIdentifier: pid_t,
        flavor: Int32,
        info: inout T
    ) -> Bool {
        let size = Int32(MemoryLayout<T>.stride)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            proc_pidinfo(processIdentifier, flavor, 0, pointer, size)
        }

        guard result == size else {
            logSamplingFailure(
                functionName: "proc_pidinfo",
                processIdentifier: processIdentifier,
                result: result,
                expectedResult: size
            )
            return false
        }

        return true
    }

    private func logSamplingFailure(
        functionName: String,
        processIdentifier: pid_t,
        result: Int32,
        expectedResult: Int32
    ) {
        #if DEBUG
        logger.debug(
            """
            \(functionName, privacy: .public) failed \
            pid=\(processIdentifier) \
            result=\(result) \
            expected=\(expectedResult) \
            errno=\(errno)
            """
        )
        #endif
    }
}
