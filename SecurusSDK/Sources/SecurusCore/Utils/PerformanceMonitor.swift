// ============================================================================
// PerformanceMonitor.swift
// SecurusCore
//
// Monitors the SDK's own resource consumption to stay within its
// performance budget: <1% CPU and <15 MB resident memory.
// ============================================================================

import Foundation

// MARK: - PerformanceBudget

/// Hard limits for the SDK's resource consumption.
public enum PerformanceBudget {
    /// Maximum CPU usage percentage the SDK should consume.
    public static let maxCPUPercent: Double = 1.0
    /// Maximum resident memory in bytes the SDK should consume.
    public static let maxMemoryBytes: UInt64 = 15 * 1024 * 1024 // 15 MB
}

// MARK: - PerformanceSnapshot

/// A point-in-time snapshot of the SDK's resource usage.
public struct PerformanceSnapshot: Sendable {
    /// Estimated CPU usage of the current thread group as a percentage (0-100).
    public let cpuUsagePercent: Double
    /// Resident memory size in bytes for the process (shared with host app).
    public let residentMemoryBytes: UInt64
    /// Whether the SDK is currently within its performance budget.
    public let withinBudget: Bool
    /// Timestamp of the measurement.
    public let timestamp: Date

    public init(cpuUsagePercent: Double, residentMemoryBytes: UInt64, timestamp: Date = Date()) {
        self.cpuUsagePercent = cpuUsagePercent
        self.residentMemoryBytes = residentMemoryBytes
        self.withinBudget = cpuUsagePercent <= PerformanceBudget.maxCPUPercent
            && residentMemoryBytes <= PerformanceBudget.maxMemoryBytes
        self.timestamp = timestamp
    }
}

// MARK: - PerformanceMonitor

/// Observes the SDK's CPU and memory footprint and provides throttling
/// guidance so that the SDK never exceeds its performance budget.
///
/// The monitor samples the process-level Mach task info and estimates
/// the SDK's share using thread-level accounting.
public final class PerformanceMonitor: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = PerformanceMonitor()

    // MARK: - Properties

    private let logger = SecurusLogger.shared
    private let queue = DispatchQueue(label: "com.securus.performanceMonitor")
    private var timer: DispatchSourceTimer?
    private var _isMonitoring = false
    private var _latestSnapshot: PerformanceSnapshot?

    /// Callback invoked when the SDK exceeds its performance budget.
    public var budgetExceededHandler: ((PerformanceSnapshot) -> Void)?

    /// The most recently captured performance snapshot.
    public var latestSnapshot: PerformanceSnapshot? {
        queue.sync { _latestSnapshot }
    }

    /// Whether monitoring is currently active.
    public var isMonitoring: Bool {
        queue.sync { _isMonitoring }
    }

    // MARK: - Init

    private init() {}

    // MARK: - Lifecycle

    /// Begin periodic performance sampling.
    /// - Parameter interval: Seconds between samples. Default is 5 seconds.
    public func startMonitoring(interval: TimeInterval = 5.0) {
        queue.async { [weak self] in
            guard let self, !self._isMonitoring else { return }
            self._isMonitoring = true
            self.logger.info("Performance monitoring started (interval: \(interval)s)",
                             subsystem: "Perf")

            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: interval)
            timer.setEventHandler { [weak self] in
                self?.sample()
            }
            timer.resume()
            self.timer = timer
        }
    }

    /// Stop periodic performance sampling.
    public func stopMonitoring() {
        queue.async { [weak self] in
            guard let self else { return }
            self.timer?.cancel()
            self.timer = nil
            self._isMonitoring = false
            self.logger.info("Performance monitoring stopped", subsystem: "Perf")
        }
    }

    /// Take a single performance sample and return it.
    @discardableResult
    public func takeSample() -> PerformanceSnapshot {
        let cpu = measureCPUUsage()
        let mem = measureResidentMemory()
        let snapshot = PerformanceSnapshot(cpuUsagePercent: cpu, residentMemoryBytes: mem)
        queue.sync { _latestSnapshot = snapshot }
        return snapshot
    }

    // MARK: - Private

    private func sample() {
        let snapshot = takeSample()

        if !snapshot.withinBudget {
            logger.warning(
                "Performance budget exceeded — CPU: \(String(format: "%.2f", snapshot.cpuUsagePercent))%, "
                + "Memory: \(snapshot.residentMemoryBytes / 1024 / 1024)MB",
                subsystem: "Perf"
            )
            budgetExceededHandler?(snapshot)
        } else {
            logger.debug(
                "Perf OK — CPU: \(String(format: "%.2f", snapshot.cpuUsagePercent))%, "
                + "Memory: \(snapshot.residentMemoryBytes / 1024 / 1024)MB",
                subsystem: "Perf"
            )
        }
    }

    // MARK: - Mach Task Info

    /// Measures total CPU usage for the current process by iterating all threads.
    /// Returns percentage (0-100). SDK-specific estimation divides by active core count.
    private func measureCPUUsage() -> Double {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0

        let result = task_threads(mach_task_self_, &threadList, &threadCount)
        guard result == KERN_SUCCESS, let threads = threadList else {
            return 0.0
        }

        var totalCPU: Double = 0.0
        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var infoCount = mach_msg_type_number_t(
                MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size
            )
            let infoResult = withUnsafeMutablePointer(to: &info) { infoPtr in
                infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) { ptr in
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), ptr, &infoCount)
                }
            }
            if infoResult == KERN_SUCCESS {
                if info.flags & TH_FLAGS_IDLE == 0 {
                    totalCPU += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
                }
            }
        }

        // Deallocate the thread list
        let size = vm_size_t(MemoryLayout<thread_t>.size) * vm_size_t(threadCount)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), size)

        return totalCPU
    }

    /// Returns the resident memory size for the current process in bytes.
    private func measureResidentMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { ptr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), ptr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(info.resident_size)
    }
}
