// ============================================================================
// SecurusRuntimeModule.swift
// SecurusRuntime
//
// Main runtime integrity module. Coordinates jailbreak detection,
// debugger detection, and app integrity checks. On start, runs all
// checks immediately, then schedules periodic re-checks at randomized
// intervals to resist timing-based evasion.
// ============================================================================

import Foundation
import SecurusCore

// MARK: - SecurusRuntimeModule

/// The primary runtime integrity module for the Securus SDK.
///
/// `SecurusRuntimeModule` conforms to `ThreatDetector` and is loaded
/// dynamically by `SecurusAgent` via `NSClassFromString`. It coordinates
/// three detection subsystems:
///
/// - **JailbreakDetector**: Multiple redundant checks for jailbreak indicators.
/// - **DebuggerDetector**: Detects attached debuggers via sysctl, environment
///   variables, and timing analysis.
/// - **IntegrityChecker**: Verifies the app bundle's code signature,
///   provisioning profile, and runtime location.
///
/// ## Scheduling
///
/// On start, all checks run immediately. Subsequent checks are scheduled
/// at **randomized** intervals between 5 and 15 minutes. Randomization
/// prevents an attacker from predicting scan timing and temporarily
/// hiding indicators.
///
/// ## Thread Safety
///
/// All mutable state is protected by a serial dispatch queue.
public final class SecurusRuntimeModule: NSObject, ThreatDetector, @unchecked Sendable {

    // MARK: - ThreatDetector Properties

    /// Human-readable name for this module.
    public let moduleName: String = "SecurusRuntime"

    /// Whether the module is currently running periodic checks.
    public var isMonitoring: Bool {
        queue.sync { _isMonitoring }
    }

    /// Delegate that receives threat events and errors.
    public weak var delegate: ThreatDetectorDelegate?

    // MARK: - Configuration

    /// Minimum interval between periodic scans, in seconds. Default: 5 minutes.
    public var minimumScanInterval: TimeInterval = 5 * 60

    /// Maximum interval between periodic scans, in seconds. Default: 15 minutes.
    public var maximumScanInterval: TimeInterval = 15 * 60

    // MARK: - Subsystems

    private let jailbreakDetector: JailbreakDetector
    private let debuggerDetector: DebuggerDetector
    private let integrityChecker: IntegrityChecker
    private let metricsCollector: MetricsCollector

    // MARK: - Private State

    private var _isMonitoring = false
    private var scanTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.securus.runtimeModule")
    private let scanQueue = DispatchQueue(
        label: "com.securus.runtimeModule.scan",
        qos: .utility
    )
    private let logger = SecurusLogger.shared

    // MARK: - Init

    /// Creates a new runtime module with default detectors.
    public override init() {
        self.jailbreakDetector = JailbreakDetector()
        self.debuggerDetector = DebuggerDetector()
        self.integrityChecker = IntegrityChecker()
        self.metricsCollector = MetricsCollector.shared
        super.init()
    }

    /// Creates a runtime module with explicit dependencies (for testing).
    ///
    /// - Parameters:
    ///   - jailbreakDetector: The jailbreak detector to use.
    ///   - debuggerDetector: The debugger detector to use.
    ///   - integrityChecker: The integrity checker to use.
    ///   - metricsCollector: The metrics collector to use.
    public init(
        jailbreakDetector: JailbreakDetector,
        debuggerDetector: DebuggerDetector,
        integrityChecker: IntegrityChecker,
        metricsCollector: MetricsCollector = .shared
    ) {
        self.jailbreakDetector = jailbreakDetector
        self.debuggerDetector = debuggerDetector
        self.integrityChecker = integrityChecker
        self.metricsCollector = metricsCollector
        super.init()
    }

    // MARK: - ThreatDetector Lifecycle

    /// Starts runtime integrity monitoring.
    ///
    /// Runs all checks immediately on a background queue, then schedules
    /// periodic re-checks at randomized intervals. Idempotent.
    public func startMonitoring() {
        queue.sync {
            guard !_isMonitoring else {
                logger.debug("Runtime module already monitoring", subsystem: "Runtime")
                return
            }

            logger.info("Starting runtime integrity module", subsystem: "Runtime")
            _isMonitoring = true

            // Run initial scan immediately on a background queue
            scanQueue.async { [weak self] in
                self?.performFullScan()
            }

            // Schedule periodic scans with randomized intervals
            scheduleNextScan()
        }
    }

    /// Stops runtime integrity monitoring and cancels all timers.
    ///
    /// Idempotent. After returning, no further delegate callbacks will
    /// be emitted until `startMonitoring()` is called again.
    public func stopMonitoring() {
        queue.sync {
            guard _isMonitoring else {
                logger.debug("Runtime module not monitoring", subsystem: "Runtime")
                return
            }

            logger.info("Stopping runtime integrity module", subsystem: "Runtime")

            scanTimer?.cancel()
            scanTimer = nil
            _isMonitoring = false

            logger.info("Runtime module stopped", subsystem: "Runtime")
        }
    }

    // MARK: - Scanning

    /// Runs all detection checks and reports any threats found.
    ///
    /// Called on `scanQueue` (background, utility QoS) to minimize
    /// impact on the host app's main thread.
    private func performFullScan() {
        let scanStart = CFAbsoluteTimeGetCurrent()

        logger.info("Beginning full runtime integrity scan", subsystem: "Runtime")

        // --- Jailbreak Detection ---
        let jailbreakResult = jailbreakDetector.performCheck()
        if jailbreakResult.isJailbroken {
            reportJailbreak(result: jailbreakResult)
        }

        // --- Debugger Detection ---
        let debuggerResult = debuggerDetector.performCheck()
        if debuggerResult.isDebuggerAttached {
            reportDebugger(result: debuggerResult)
        }

        // --- Integrity Check ---
        let integrityResult = integrityChecker.performCheck()
        if !integrityResult.isIntact {
            reportIntegrityViolation(result: integrityResult)
        }

        // --- Metrics ---
        let scanDuration = CFAbsoluteTimeGetCurrent() - scanStart
        metricsCollector.recordScan(duration: scanDuration)

        if jailbreakResult.isJailbroken {
            metricsCollector.recordThreat(type: .jailbreak_detected)
        }
        if debuggerResult.isDebuggerAttached {
            metricsCollector.recordThreat(type: .debugger_attached)
        }
        if !integrityResult.isIntact {
            metricsCollector.recordThreat(type: .app_repackaged)
        }

        logger.info(
            "Runtime scan complete in \(String(format: "%.1f", scanDuration * 1000))ms "
            + "(jailbreak: \(jailbreakResult.isJailbroken), "
            + "debugger: \(debuggerResult.isDebuggerAttached), "
            + "integrity: \(integrityResult.isIntact))",
            subsystem: "Runtime"
        )
    }

    // MARK: - Scheduling

    /// Schedules the next periodic scan at a random interval between
    /// `minimumScanInterval` and `maximumScanInterval`.
    private func scheduleNextScan() {
        let interval = TimeInterval.random(in: minimumScanInterval...maximumScanInterval)

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }

            // Ensure we are still monitoring
            guard self.queue.sync(execute: { self._isMonitoring }) else { return }

            // Run scan on the background queue
            self.scanQueue.async {
                self.performFullScan()
            }

            // Schedule the next scan
            self.queue.async {
                guard self._isMonitoring else { return }
                self.scheduleNextScan()
            }
        }
        timer.resume()

        // Cancel previous timer and store the new one
        scanTimer?.cancel()
        scanTimer = timer

        logger.debug(
            "Next runtime scan scheduled in \(String(format: "%.0f", interval))s",
            subsystem: "Runtime"
        )
    }

    // MARK: - Threat Reporting

    /// Reports a jailbreak detection to the delegate.
    private func reportJailbreak(result: JailbreakResult) {
        let appToken = TokenGenerator.shared.deviceToken()

        var metadata: [String: String] = [
            "method": result.failedChecks.joined(separator: ",")
        ]
        metadata["confidence"] = result.confidence.rawValue

        let event = ThreatEvent(
            threatType: .jailbreak_detected,
            severity: .critical,
            metadata: metadata,
            appToken: appToken
        )

        logger.warning(
            "Jailbreak detected: \(result.failedChecks.joined(separator: ", "))",
            subsystem: "Runtime"
        )

        delegate?.threatDetector(self, didDetect: event)
    }

    /// Reports a debugger attachment to the delegate.
    private func reportDebugger(result: DebuggerResult) {
        let appToken = TokenGenerator.shared.deviceToken()

        let metadata: [String: String] = [
            "method": result.detectionMethod,
            "details": result.details
        ]

        let event = ThreatEvent(
            threatType: .debugger_attached,
            severity: .high,
            metadata: metadata,
            appToken: appToken
        )

        logger.warning(
            "Debugger detected via \(result.detectionMethod): \(result.details)",
            subsystem: "Runtime"
        )

        delegate?.threatDetector(self, didDetect: event)
    }

    /// Reports an app integrity violation to the delegate.
    private func reportIntegrityViolation(result: IntegrityResult) {
        let appToken = TokenGenerator.shared.deviceToken()

        let metadata: [String: String] = [
            "failed_checks": result.failedChecks.joined(separator: ","),
            "details": result.details
        ]

        let event = ThreatEvent(
            threatType: .app_repackaged,
            severity: .critical,
            metadata: metadata,
            appToken: appToken
        )

        logger.warning(
            "App integrity violation: \(result.failedChecks.joined(separator: ", "))",
            subsystem: "Runtime"
        )

        delegate?.threatDetector(self, didDetect: event)
    }
}
