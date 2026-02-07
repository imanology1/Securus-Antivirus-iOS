// ============================================================================
// NetworkEvent.swift
// SecurusNetwork
//
// Model for observed network events. All identifying data (domains, IPs)
// is stored in hashed form to comply with the Privacy by Design mandate.
// ============================================================================

import Foundation

// MARK: - NetworkProtocolType

/// The transport-layer protocol observed for a network event.
public enum NetworkProtocolType: String, Codable, Sendable {
    case http
    case https
    case tcp
    case udp
    case unknown
}

// MARK: - NetworkEvent

/// An immutable record of a single observed network request.
///
/// Network events are captured by `NetworkTrafficMonitor` and analyzed by
/// `AnomalyScorer`. All domain names and IP addresses are SHA-256 hashed
/// before being stored in this model.
///
/// This struct is `Codable` for persistence in the learned baseline and
/// for inclusion in batched threat reports.
public struct NetworkEvent: Codable, Sendable, Identifiable {

    // MARK: - Properties

    /// Unique identifier for this event.
    public let id: String

    /// SHA-256 hash of the destination domain (e.g. hash of "api.example.com").
    public let destinationDomainHash: String

    /// Destination port number (e.g. 443, 80, 8080).
    public let port: Int

    /// Transport/application protocol used.
    public let protocolType: NetworkProtocolType

    /// ISO 8601 timestamp of when the request was observed.
    public let timestamp: String

    /// Size of the outgoing request body in bytes (0 for GET requests).
    public let requestSizeBytes: Int

    /// HTTP response status code, or -1 if the response was not received.
    public let responseCode: Int

    /// Duration of the request in milliseconds, or -1 if incomplete.
    public let durationMs: Int

    // MARK: - Initializer

    /// Creates a new network event with pre-hashed values.
    ///
    /// - Parameters:
    ///   - destinationDomainHash: SHA-256 hash of the domain.
    ///   - port: Destination port number.
    ///   - protocolType: Transport protocol.
    ///   - requestSizeBytes: Outgoing request body size.
    ///   - responseCode: HTTP response code.
    ///   - durationMs: Request duration in milliseconds.
    public init(
        destinationDomainHash: String,
        port: Int,
        protocolType: NetworkProtocolType,
        requestSizeBytes: Int = 0,
        responseCode: Int = -1,
        durationMs: Int = -1
    ) {
        self.id = UUID().uuidString
        self.destinationDomainHash = destinationDomainHash
        self.port = port
        self.protocolType = protocolType
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.requestSizeBytes = requestSizeBytes
        self.responseCode = responseCode
        self.durationMs = durationMs
    }

    // MARK: - Feature Vector

    /// Converts this event into a numeric feature vector suitable for
    /// anomaly detection scoring.
    ///
    /// The vector layout is:
    /// `[port, protocolOrdinal, requestSizeBytes, responseCode, durationMs]`
    ///
    /// Note: The domain hash is not included numerically; it is used
    /// separately for domain-level baseline matching.
    public func toFeatureVector() -> [Double] {
        let protocolOrdinal: Double
        switch protocolType {
        case .http:     protocolOrdinal = 0
        case .https:    protocolOrdinal = 1
        case .tcp:      protocolOrdinal = 2
        case .udp:      protocolOrdinal = 3
        case .unknown:  protocolOrdinal = 4
        }

        return [
            Double(port),
            protocolOrdinal,
            Double(requestSizeBytes),
            Double(responseCode),
            Double(durationMs)
        ]
    }
}

// MARK: - CustomStringConvertible

extension NetworkEvent: CustomStringConvertible {
    public var description: String {
        "NetworkEvent(domain: \(destinationDomainHash.prefix(12))..., "
        + "port: \(port), proto: \(protocolType.rawValue), "
        + "status: \(responseCode), duration: \(durationMs)ms)"
    }
}
