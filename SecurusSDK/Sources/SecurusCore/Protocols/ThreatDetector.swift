// ============================================================================
// ThreatDetector.swift
// SecurusCore
//
// Protocol that all detection modules (Network, Runtime) must conform to.
// Provides a uniform lifecycle and delegation pattern for threat detection.
// ============================================================================

import Foundation

// MARK: - ThreatDetectorDelegate

/// Delegate protocol for receiving threat detection events.
///
/// Conforming types (typically `SecurusAgent`) receive callbacks when
/// a threat is detected or when an error occurs during monitoring.
public protocol ThreatDetectorDelegate: AnyObject, Sendable {

    /// Called when a threat has been detected.
    ///
    /// - Parameters:
    ///   - detector: The detector that identified the threat.
    ///   - event: The threat event describing what was detected.
    func threatDetector(_ detector: any ThreatDetector, didDetect event: ThreatEvent)

    /// Called when the detector encounters a non-fatal error.
    ///
    /// The detector continues operating after reporting the error.
    ///
    /// - Parameters:
    ///   - detector: The detector that encountered the error.
    ///   - error: The error that occurred.
    func threatDetector(_ detector: any ThreatDetector, didEncounterError error: SecurusError)
}

// MARK: - ThreatDetector

/// A protocol that all Securus detection modules conform to.
///
/// Each module (SecurusNetwork, SecurusRuntime) implements this protocol
/// to provide a consistent lifecycle for starting, stopping, and reporting
/// detected threats.
///
/// ## Lifecycle
///
/// 1. The host app calls `SecurusAgent.start()`.
/// 2. The agent calls `startMonitoring()` on each enabled detector.
/// 3. Detectors run their checks and report findings via `delegate`.
/// 4. When the host app calls `SecurusAgent.stop()`, the agent calls
///    `stopMonitoring()` on each detector.
///
/// ## Thread Safety
///
/// Implementations must be thread-safe. `startMonitoring()` and
/// `stopMonitoring()` may be called from any thread.
public protocol ThreatDetector: AnyObject, Sendable {

    /// A human-readable name for this detector module.
    var moduleName: String { get }

    /// Whether this detector is currently running.
    var isMonitoring: Bool { get }

    /// Delegate to receive threat events and errors.
    var delegate: ThreatDetectorDelegate? { get set }

    /// Begin active monitoring.
    ///
    /// Implementations should perform initial checks immediately and then
    /// schedule periodic scans as appropriate. This method must be idempotent:
    /// calling it when already monitoring should be a no-op.
    func startMonitoring()

    /// Stop active monitoring and release associated resources.
    ///
    /// Must be idempotent. After returning, no further delegate callbacks
    /// should be emitted until `startMonitoring()` is called again.
    func stopMonitoring()
}
