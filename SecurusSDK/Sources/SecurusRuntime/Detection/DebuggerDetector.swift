// ============================================================================
// DebuggerDetector.swift
// SecurusRuntime
//
// Detects the presence of an attached debugger (LLDB, dtrace, Frida, etc.)
// using multiple independent techniques. Detection is designed to resist
// single-point bypass by an attacker.
// ============================================================================

import Foundation
import SecurusCore

#if canImport(Darwin)
import Darwin
#endif

// MARK: - DebuggerResult

/// The result of a debugger detection scan.
public struct DebuggerResult: Sendable {
    /// Whether a debugger appears to be attached.
    public let isDebuggerAttached: Bool
    /// The detection method that triggered the alert.
    public let detectionMethod: String
    /// Human-readable details about what was detected.
    public let details: String

    public init(isDebuggerAttached: Bool, detectionMethod: String, details: String) {
        self.isDebuggerAttached = isDebuggerAttached
        self.detectionMethod = detectionMethod
        self.details = details
    }
}

// MARK: - DebuggerDetector

/// Detects whether a debugger is attached to the running process.
///
/// ## Detection Techniques
///
/// 1. **sysctl P_TRACED**: Queries the kernel via `sysctl()` with
///    `CTL_KERN / KERN_PROC / KERN_PROC_PID` and checks the `kp_proc.p_flag`
///    for the `P_TRACED` bit, which is set when a debugger is attached.
///
/// 2. **DYLD_INSERT_LIBRARIES**: Checks whether the
///    `DYLD_INSERT_LIBRARIES` environment variable is set. Tools like
///    Frida and Cycript use library injection, which requires this variable.
///
/// 3. **Timing Analysis**: Measures the execution time of a calibrated
///    CPU-bound workload. When a debugger is attached, the workload takes
///    significantly longer due to breakpoint handling and single-stepping
///    overhead.
///
/// 4. **Debugger Port Check**: Inspects common debugger service ports
///    (e.g. Frida's default port 27042) for active listeners using
///    `getaddrinfo` + `connect`.
///
/// ## Thread Safety
///
/// All methods are stateless and safe to call from any thread.
public final class DebuggerDetector: Sendable {

    // MARK: - Constants

    /// Common ports used by debugging tools.
    ///
    /// - 27042: Frida default listener port
    /// - 27043: Frida secondary port
    /// - 4242: Common reverse-engineering tool port
    private static let debuggerPorts: [UInt16] = [27042, 27043, 4242]

    /// Maximum duration (in seconds) the calibrated workload should take
    /// on a non-debugged process. If actual time exceeds this by the
    /// `timingMultiplier`, debugger attachment is suspected.
    private static let baselineTimingThreshold: TimeInterval = 0.1

    /// Factor by which timing must exceed the baseline to flag debugger.
    /// Set conservatively to avoid false positives on slow devices.
    private static let timingMultiplier: Double = 10.0

    // MARK: - Properties

    private let logger = SecurusLogger.shared

    // MARK: - Init

    /// Creates a debugger detector.
    public init() {}

    // MARK: - Public API

    /// Performs all debugger detection checks and returns the first
    /// positive result found. If no debugger is detected, returns a
    /// clean result.
    ///
    /// Checks are ordered from most reliable to least reliable.
    ///
    /// - Returns: A `DebuggerResult` describing the detection outcome.
    public func performCheck() -> DebuggerResult {
        // 1. sysctl P_TRACED check (most reliable)
        if let result = checkSysctl() {
            return result
        }

        // 2. DYLD_INSERT_LIBRARIES check
        if let result = checkDyldEnvironment() {
            return result
        }

        // 3. Timing-based detection
        if let result = checkTimingAnomaly() {
            return result
        }

        // 4. Debugger port check
        if let result = checkDebuggerPorts() {
            return result
        }

        return DebuggerResult(
            isDebuggerAttached: false,
            detectionMethod: "none",
            details: "No debugger indicators detected"
        )
    }

    // MARK: - Individual Checks

    /// Check 1: Uses `sysctl()` to query the kernel for the `P_TRACED` flag.
    ///
    /// The `P_TRACED` flag is set on a process's `p_flag` when a debugger
    /// (e.g. LLDB, dtrace) is attached via `ptrace(PT_ATTACH, ...)`.
    ///
    /// - Returns: A `DebuggerResult` if a debugger is detected, or `nil`.
    public func checkSysctl() -> DebuggerResult? {
        #if canImport(Darwin)
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]

        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)

        guard result == 0 else {
            logger.debug("sysctl call failed with errno \(errno)", subsystem: "Runtime")
            return nil
        }

        let flags = info.kp_proc.p_flag
        let isTraced = (flags & P_TRACED) != 0

        if isTraced {
            logger.debug("P_TRACED flag detected via sysctl", subsystem: "Runtime")
            return DebuggerResult(
                isDebuggerAttached: true,
                detectionMethod: "sysctl_p_traced",
                details: "Process has P_TRACED flag set (p_flag: \(flags))"
            )
        }
        #endif

        return nil
    }

    /// Check 2: Inspects the `DYLD_INSERT_LIBRARIES` environment variable.
    ///
    /// Dynamic library injection tools (Frida, Cycript, Substrate) typically
    /// require `DYLD_INSERT_LIBRARIES` to be set. On a stock iOS device this
    /// variable is never present.
    ///
    /// - Returns: A `DebuggerResult` if the variable is set, or `nil`.
    public func checkDyldEnvironment() -> DebuggerResult? {
        if let value = getenv("DYLD_INSERT_LIBRARIES") {
            let libraries = String(cString: value)
            logger.debug(
                "DYLD_INSERT_LIBRARIES is set: \(libraries)",
                subsystem: "Runtime"
            )
            return DebuggerResult(
                isDebuggerAttached: true,
                detectionMethod: "dyld_insert_libraries",
                details: "DYLD_INSERT_LIBRARIES is set: \(libraries)"
            )
        }
        return nil
    }

    /// Check 3: Timing-based detection.
    ///
    /// Executes a calibrated workload and measures wall-clock time.
    /// Debugger breakpoint handling and single-stepping add significant
    /// overhead (typically 10x or more) to tight computational loops.
    ///
    /// - Returns: A `DebuggerResult` if anomalous timing is detected, or `nil`.
    public func checkTimingAnomaly() -> DebuggerResult? {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Calibrated workload: lightweight computation loop.
        // On a modern iOS device this completes in ~1-5ms without a debugger.
        var accumulator: Double = 0
        for i in 0..<100_000 {
            accumulator += sin(Double(i) * 0.001)
        }

        // Prevent compiler from optimizing away the loop
        if accumulator == .infinity { logger.debug("unreachable", subsystem: "Runtime") }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let threshold = Self.baselineTimingThreshold * Self.timingMultiplier

        if elapsed > threshold {
            logger.debug(
                "Timing anomaly: workload took \(String(format: "%.3f", elapsed))s "
                + "(threshold: \(String(format: "%.3f", threshold))s)",
                subsystem: "Runtime"
            )
            return DebuggerResult(
                isDebuggerAttached: true,
                detectionMethod: "timing_analysis",
                details: "Execution time \(String(format: "%.3f", elapsed))s "
                + "exceeds threshold \(String(format: "%.3f", threshold))s"
            )
        }

        return nil
    }

    /// Check 4: Probes common debugger ports for active listeners.
    ///
    /// Attempts a non-blocking TCP connection to known debugger ports
    /// (e.g. Frida's 27042). If the connection succeeds, a debugging
    /// tool is likely listening.
    ///
    /// - Returns: A `DebuggerResult` if an active debugger port is found, or `nil`.
    public func checkDebuggerPorts() -> DebuggerResult? {
        for port in Self.debuggerPorts {
            if isPortOpen(port: port) {
                logger.debug(
                    "Debugger port \(port) is open",
                    subsystem: "Runtime"
                )
                return DebuggerResult(
                    isDebuggerAttached: true,
                    detectionMethod: "debugger_port",
                    details: "Active listener detected on port \(port)"
                )
            }
        }
        return nil
    }

    // MARK: - Private Helpers

    /// Attempts a quick TCP connection to localhost on the given port.
    ///
    /// Uses a non-blocking connect with a 100ms timeout to avoid stalling
    /// the scan if the port is filtered (not just closed).
    ///
    /// - Parameter port: The port number to probe.
    /// - Returns: `true` if a TCP connection was established.
    private func isPortOpen(port: UInt16) -> Bool {
        #if canImport(Darwin)
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }

        defer { close(sock) }

        // Set non-blocking mode
        var flags = fcntl(sock, F_GETFL, 0)
        flags |= O_NONBLOCK
        fcntl(sock, F_SETFL, flags)

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.connect(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        if connectResult == 0 {
            return true
        }

        // Non-blocking connect returns -1 with EINPROGRESS if in progress.
        // Use select/poll with a short timeout to check completion.
        if errno == EINPROGRESS {
            var pollFd = pollfd(fd: sock, events: Int16(POLLOUT), revents: 0)
            let pollResult = poll(&pollFd, 1, 100) // 100ms timeout
            if pollResult > 0 && (pollFd.revents & Int16(POLLOUT)) != 0 {
                // Check if connection actually succeeded
                var optError: Int32 = 0
                var optLen = socklen_t(MemoryLayout<Int32>.size)
                getsockopt(sock, SOL_SOCKET, SO_ERROR, &optError, &optLen)
                return optError == 0
            }
        }
        #endif

        return false
    }
}
