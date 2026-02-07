// ============================================================================
// MetricsCollector.swift
// SecurusRuntime
//
// Collects and aggregates runtime metrics for the Securus SDK:
// scan counts, threat detections by type, false positive reports,
// scan durations, and uptime statistics.
// ============================================================================

import Foundation
import SecurusCore

// MARK: - MetricsCollector

/// Thread-safe collector for SDK runtime metrics.
///
/// `MetricsCollector` accumulates operational statistics that can be
/// reported to the backend for quality-of-service monitoring or
/// surfaced to the host app for dashboard display.
///
/// ## Tracked Metrics
///
/// - **Total scans performed**: Count of full runtime integrity scans.
/// - **Threats detected (by type)**: Per-`ThreatType` detection counts.
/// - **False positives reported**: Count of events the host app has
///   marked as false positives via `reportFalsePositive()`.
/// - **Scan duration**: Running average and last scan duration.
/// - **SDK uptime**: Wall-clock time since the collector was initialized
///   or last reset.
///
/// ## Thread Safety
///
/// All mutable state is protected by a serial dispatch queue.
/// Methods may be called from any thread.
public final class MetricsCollector: @unchecked Sendable {

    // MARK: - Singleton

    /// Shared metrics collector instance.
    public static let shared = MetricsCollector()

    // MARK: - Private State

    private var _totalScans: Int = 0
    private var _threatCounts: [ThreatType: Int] = [:]
    private var _falsePositives: Int = 0
    private var _totalScanDuration: TimeInterval = 0
    private var _lastScanDuration: TimeInterval = 0
    private var _lastScanTime: Date?
    private var _startTime: Date
    private let queue = DispatchQueue(label: "com.securus.metricsCollector")
    private let logger = SecurusLogger.shared

    // MARK: - Init

    /// Creates a new metrics collector. The SDK uptime clock starts
    /// from the moment of initialization.
    public init() {
        self._startTime = Date()
    }

    // MARK: - Recording

    /// Records the completion of a full runtime integrity scan.
    ///
    /// - Parameter duration: The wall-clock duration of the scan in seconds.
    public func recordScan(duration: TimeInterval) {
        queue.sync {
            _totalScans += 1
            _totalScanDuration += duration
            _lastScanDuration = duration
            _lastScanTime = Date()
        }

        logger.debug(
            "Recorded scan #\(totalScans) (duration: \(String(format: "%.3f", duration))s)",
            subsystem: "Metrics"
        )
    }

    /// Records a detected threat of the given type.
    ///
    /// - Parameter type: The category of threat that was detected.
    public func recordThreat(type: ThreatType) {
        queue.sync {
            _threatCounts[type, default: 0] += 1
        }

        logger.debug(
            "Recorded threat: \(type.rawValue) (total: \(threatCount(for: type)))",
            subsystem: "Metrics"
        )
    }

    /// Records a false positive report from the host application.
    ///
    /// Host apps can call this when a user or automated system determines
    /// that a reported threat was a false alarm. This metric helps improve
    /// the detection model over time.
    public func reportFalsePositive() {
        queue.sync {
            _falsePositives += 1
        }

        logger.debug(
            "Recorded false positive (total: \(falsePositives))",
            subsystem: "Metrics"
        )
    }

    // MARK: - Accessors

    /// Total number of scans performed since initialization or last reset.
    public var totalScans: Int {
        queue.sync { _totalScans }
    }

    /// Number of threats detected for a specific threat type.
    ///
    /// - Parameter type: The threat type to query.
    /// - Returns: The count of detections for that type.
    public func threatCount(for type: ThreatType) -> Int {
        queue.sync { _threatCounts[type, default: 0] }
    }

    /// Total number of threats detected across all types.
    public var totalThreats: Int {
        queue.sync { _threatCounts.values.reduce(0, +) }
    }

    /// Number of false positives reported by the host application.
    public var falsePositives: Int {
        queue.sync { _falsePositives }
    }

    /// Average scan duration in seconds, or 0 if no scans have been performed.
    public var averageScanDuration: TimeInterval {
        queue.sync {
            guard _totalScans > 0 else { return 0 }
            return _totalScanDuration / TimeInterval(_totalScans)
        }
    }

    /// Duration of the most recent scan in seconds, or 0 if no scans yet.
    public var lastScanDuration: TimeInterval {
        queue.sync { _lastScanDuration }
    }

    /// Timestamp of the most recent scan, or `nil` if no scans yet.
    public var lastScanTime: Date? {
        queue.sync { _lastScanTime }
    }

    /// Wall-clock uptime of the SDK in seconds since collector initialization.
    public var uptime: TimeInterval {
        queue.sync { Date().timeIntervalSince(_startTime) }
    }

    // MARK: - Summary

    /// Returns a dictionary summary of all collected metrics.
    ///
    /// The dictionary is suitable for JSON serialization and can be
    /// sent to the backend or displayed in a diagnostic view.
    ///
    /// ## Keys
    ///
    /// - `total_scans` (Int)
    /// - `total_threats` (Int)
    /// - `threats_by_type` ([String: Int])
    /// - `false_positives` (Int)
    /// - `average_scan_duration_ms` (Double)
    /// - `last_scan_duration_ms` (Double)
    /// - `last_scan_time` (String, ISO 8601, or "never")
    /// - `uptime_seconds` (Double)
    /// - `sdk_version` (String)
    ///
    /// - Returns: A `[String: Any]` dictionary of aggregated metrics.
    public func summary() -> [String: Any] {
        queue.sync {
            let threatsByType: [String: Int] = Dictionary(
                uniqueKeysWithValues: _threatCounts.map { ($0.key.rawValue, $0.value) }
            )

            let lastScanTimeString: String
            if let time = _lastScanTime {
                lastScanTimeString = ISO8601DateFormatter().string(from: time)
            } else {
                lastScanTimeString = "never"
            }

            return [
                "total_scans": _totalScans,
                "total_threats": _threatCounts.values.reduce(0, +),
                "threats_by_type": threatsByType,
                "false_positives": _falsePositives,
                "average_scan_duration_ms": _totalScans > 0
                    ? (_totalScanDuration / TimeInterval(_totalScans)) * 1000
                    : 0,
                "last_scan_duration_ms": _lastScanDuration * 1000,
                "last_scan_time": lastScanTimeString,
                "uptime_seconds": Date().timeIntervalSince(_startTime),
                "sdk_version": ThreatEvent.currentSDKVersion
            ]
        }
    }

    // MARK: - Reset

    /// Resets all collected metrics and restarts the uptime clock.
    ///
    /// Intended for testing or when the host application wants a clean
    /// metrics slate (e.g. after user logout).
    public func reset() {
        queue.sync {
            _totalScans = 0
            _threatCounts.removeAll()
            _falsePositives = 0
            _totalScanDuration = 0
            _lastScanDuration = 0
            _lastScanTime = nil
            _startTime = Date()
        }

        logger.info("Metrics collector reset", subsystem: "Metrics")
    }
}
