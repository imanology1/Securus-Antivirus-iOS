// ============================================================================
// ThreatEvent.swift
// SecurusCore
//
// Core threat event model that matches the backend payload contract.
// All reported data is anonymized before transmission.
// ============================================================================

import Foundation

// MARK: - ThreatType

/// The category of threat detected by the SDK.
public enum ThreatType: String, Codable, Sendable, CaseIterable {
    /// An outbound network request deviated significantly from the learned baseline.
    case network_anomaly
    /// The device appears to be jailbroken.
    case jailbreak_detected
    /// A debugger (LLDB, dtrace, etc.) is attached to the process.
    case debugger_attached
    /// The application binary has been tampered with or re-signed.
    case app_repackaged
}

// MARK: - ThreatSeverity

/// Severity classification of a threat event.
public enum ThreatSeverity: String, Codable, Sendable, Comparable {
    case critical
    case high
    case medium
    case low

    // MARK: Comparable

    private var rank: Int {
        switch self {
        case .critical: return 4
        case .high:     return 3
        case .medium:   return 2
        case .low:      return 1
        }
    }

    public static func < (lhs: ThreatSeverity, rhs: ThreatSeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

// MARK: - ThreatEvent

/// An immutable, Codable record of a single threat detection event.
///
/// This model is serialized directly to the backend `POST /v1/report`
/// payload. All personally identifiable information must be stripped
/// or hashed before populating fields.
///
/// Example JSON:
/// ```json
/// {
///   "threat_id": "550e8400-e29b-41d4-a716-446655440000",
///   "threat_type": "jailbreak_detected",
///   "severity": "critical",
///   "metadata": { "method": "cydia_file_check" },
///   "app_token": "sha256:abcdef...",
///   "sdk_version": "1.0.0",
///   "os_version": "17.4",
///   "timestamp": "2025-05-01T12:00:00Z"
/// }
/// ```
public struct ThreatEvent: Codable, Sendable, Identifiable {

    // MARK: - Properties

    /// Unique identifier for this threat event (UUID v4).
    public let threat_id: String

    /// The category of detected threat.
    public let threat_type: ThreatType

    /// Severity of the detected threat.
    public let severity: ThreatSeverity

    /// Arbitrary key-value metadata specific to the threat type.
    /// Values must be anonymized (hashed IPs, no PII).
    public let metadata: [String: String]

    /// Anonymous device/session token generated via `TokenGenerator`.
    public let app_token: String

    /// Securus SDK version string.
    public let sdk_version: String

    /// iOS version the device is running.
    public let os_version: String

    /// ISO 8601 timestamp of when the threat was detected.
    public let timestamp: String

    // MARK: - Identifiable

    public var id: String { threat_id }

    // MARK: - Initializer

    /// Creates a new threat event.
    ///
    /// - Parameters:
    ///   - threatType: Category of the detected threat.
    ///   - severity: Severity classification.
    ///   - metadata: Anonymized key-value data about the threat.
    ///   - appToken: Anonymous session/device token.
    ///   - sdkVersion: Current SDK version string.
    public init(
        threatType: ThreatType,
        severity: ThreatSeverity,
        metadata: [String: String] = [:],
        appToken: String,
        sdkVersion: String = ThreatEvent.currentSDKVersion
    ) {
        self.threat_id = UUID().uuidString
        self.threat_type = threatType
        self.severity = severity
        self.metadata = metadata
        self.app_token = appToken
        self.sdk_version = sdkVersion
        self.os_version = ProcessInfo.processInfo.operatingSystemVersionString
        self.timestamp = ISO8601DateFormatter().string(from: Date())
    }

    // MARK: - Constants

    /// The current version of the Securus SDK.
    public static let currentSDKVersion = "1.0.0"
}

// MARK: - CustomStringConvertible

extension ThreatEvent: CustomStringConvertible {
    public var description: String {
        "ThreatEvent(\(threat_type.rawValue), severity: \(severity.rawValue), id: \(threat_id))"
    }
}
