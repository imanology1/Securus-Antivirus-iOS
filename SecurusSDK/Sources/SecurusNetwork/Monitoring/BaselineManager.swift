// ============================================================================
// BaselineManager.swift
// SecurusNetwork
//
// Manages the learned baseline of "normal" network behavior. During the
// learning phase, the manager collects domain/port/protocol patterns.
// After the learning period expires, the baseline is frozen and used
// for anomaly comparison.
// ============================================================================

import Foundation
import SecurusCore

// MARK: - BaselinePhase

/// The operational phase of the baseline manager.
public enum BaselinePhase: String, Codable, Sendable {
    /// Actively collecting data to build the baseline.
    case learning
    /// The baseline is frozen; new traffic is compared against it.
    case protection
}

// MARK: - BaselineEntry

/// A single entry in the learned network baseline.
///
/// Represents a "known good" combination of hashed domain, port, and
/// protocol that was observed during the learning phase.
public struct BaselineEntry: Codable, Sendable, Hashable {
    /// SHA-256 hash of the domain.
    public let domainHash: String
    /// Destination port.
    public let port: Int
    /// Protocol type.
    public let protocolType: NetworkProtocolType
    /// Number of times this pattern was observed during learning.
    public var observationCount: Int

    public init(domainHash: String, port: Int, protocolType: NetworkProtocolType, observationCount: Int = 1) {
        self.domainHash = domainHash
        self.port = port
        self.protocolType = protocolType
        self.observationCount = observationCount
    }

    // Hashable: two entries match on domain+port+protocol
    public func hash(into hasher: inout Hasher) {
        hasher.combine(domainHash)
        hasher.combine(port)
        hasher.combine(protocolType)
    }

    public static func == (lhs: BaselineEntry, rhs: BaselineEntry) -> Bool {
        lhs.domainHash == rhs.domainHash
            && lhs.port == rhs.port
            && lhs.protocolType == rhs.protocolType
    }
}

// MARK: - BaselineSnapshot

/// Serializable snapshot of the entire baseline for persistence.
struct BaselineSnapshot: Codable {
    var entries: [BaselineEntry]
    var featureVectors: [[Double]]
    var learningStartDate: Date
    var learningEndDate: Date?
    var phase: BaselinePhase
    var totalEventsObserved: Int
}

// MARK: - BaselineManager

/// Manages the network traffic baseline used for anomaly detection.
///
/// ## Learning Phase
///
/// When the SDK starts for the first time, the baseline manager enters
/// the **learning** phase. During this phase (default 7 days), all observed
/// network events are recorded to build a model of "normal" behavior.
///
/// ## Protection Phase
///
/// After the learning period elapses, the manager transitions to the
/// **protection** phase. New network events are compared against the
/// learned baseline to identify anomalies.
///
/// ## Persistence
///
/// The baseline is persisted to the Keychain via `SecureStorage` so
/// that it survives app restarts.
public final class BaselineManager: @unchecked Sendable {

    // MARK: - Storage Keys

    private static let storageKey = "com.securus.network.baseline"
    private static let phaseKey = "com.securus.network.phase"

    // MARK: - Properties

    /// Current phase of the baseline manager.
    public private(set) var phase: BaselinePhase {
        get { queue.sync { _phase } }
        set { queue.sync { _phase = newValue } }
    }

    /// The set of known-good network patterns.
    public var entries: [BaselineEntry] {
        queue.sync { Array(_entries.values) }
    }

    /// Total number of events observed since the learning phase started.
    public var totalEventsObserved: Int {
        queue.sync { _totalEventsObserved }
    }

    /// Duration of the learning period in seconds.
    public var learningPeriodDuration: TimeInterval

    private var _phase: BaselinePhase = .learning
    private var _entries: [String: BaselineEntry] = [:]  // keyed by domain+port+proto
    private var _featureVectors: [[Double]] = []
    private var _learningStartDate: Date = Date()
    private var _totalEventsObserved: Int = 0
    private let queue = DispatchQueue(label: "com.securus.baselineManager")
    private let logger = SecurusLogger.shared
    private let storage = SecureStorage.shared

    // MARK: - Init

    /// Creates a baseline manager with the specified learning period.
    ///
    /// - Parameter learningPeriodDuration: Duration in seconds. Default: 7 days.
    public init(learningPeriodDuration: TimeInterval = 7 * 24 * 60 * 60) {
        self.learningPeriodDuration = learningPeriodDuration
        loadPersistedBaseline()
    }

    // MARK: - Event Recording

    /// Records a network event.
    ///
    /// During the learning phase, the event is added to the baseline.
    /// During the protection phase, this is a no-op (events are scored
    /// by `AnomalyScorer` instead).
    ///
    /// - Parameter event: The observed network event.
    /// - Returns: `true` if the event was added to the baseline.
    @discardableResult
    public func recordEvent(_ event: NetworkEvent) -> Bool {
        queue.sync {
            _totalEventsObserved += 1

            // Check if learning period has elapsed
            if _phase == .learning {
                let elapsed = Date().timeIntervalSince(_learningStartDate)
                if elapsed >= learningPeriodDuration {
                    transitionToProtection()
                    return false
                }

                // Add to baseline
                let key = "\(event.destinationDomainHash):\(event.port):\(event.protocolType.rawValue)"
                if var existing = _entries[key] {
                    existing.observationCount += 1
                    _entries[key] = existing
                } else {
                    let entry = BaselineEntry(
                        domainHash: event.destinationDomainHash,
                        port: event.port,
                        protocolType: event.protocolType
                    )
                    _entries[key] = entry
                }

                // Store feature vector for ML baseline training
                _featureVectors.append(event.toFeatureVector())

                // Periodically persist
                if _totalEventsObserved % 50 == 0 {
                    persistBaseline()
                }

                return true
            }

            return false
        }
    }

    // MARK: - Lookup

    /// Checks whether a network event matches a known baseline entry.
    ///
    /// - Parameter event: The event to check.
    /// - Returns: `true` if the event's domain+port+protocol combination
    ///   exists in the learned baseline.
    public func isKnown(_ event: NetworkEvent) -> Bool {
        let key = "\(event.destinationDomainHash):\(event.port):\(event.protocolType.rawValue)"
        return queue.sync { _entries[key] != nil }
    }

    /// Returns the feature vectors collected during the learning phase.
    ///
    /// Used by `AnomalyScorer` to train the anomaly detection engine.
    public func learnedFeatureVectors() -> [[Double]] {
        queue.sync { _featureVectors }
    }

    // MARK: - Phase Transition

    /// Forces a transition to protection phase regardless of elapsed time.
    ///
    /// Useful for testing or when the host app determines the baseline
    /// is sufficiently trained.
    public func forceProtectionPhase() {
        queue.sync {
            transitionToProtection()
        }
    }

    /// Resets the baseline, returning to the learning phase.
    public func reset() {
        queue.sync {
            _entries.removeAll()
            _featureVectors.removeAll()
            _learningStartDate = Date()
            _totalEventsObserved = 0
            _phase = .learning
            persistBaseline()
            logger.info("Baseline reset — entering learning phase", subsystem: "Network")
        }
    }

    // MARK: - Private

    /// Transitions from learning to protection phase. Must be called on `queue`.
    private func transitionToProtection() {
        _phase = .protection

        // Train the anomaly detection engine with collected feature vectors
        if !_featureVectors.isEmpty {
            AnomalyDetectionEngine.shared.updateBaseline(observations: _featureVectors)
        }

        persistBaseline()
        logger.info(
            "Baseline learning complete — \(_entries.count) unique patterns, "
            + "\(_totalEventsObserved) total events. Entering protection phase.",
            subsystem: "Network"
        )
    }

    // MARK: - Persistence

    /// Persists the current baseline to secure storage. Must be called on `queue`.
    private func persistBaseline() {
        let snapshot = BaselineSnapshot(
            entries: Array(_entries.values),
            featureVectors: _featureVectors,
            learningStartDate: _learningStartDate,
            learningEndDate: _phase == .protection ? Date() : nil,
            phase: _phase,
            totalEventsObserved: _totalEventsObserved
        )

        do {
            try storage.storeCodable(snapshot, forKey: Self.storageKey)
            logger.debug("Baseline persisted (\(_entries.count) entries)", subsystem: "Network")
        } catch {
            logger.warning("Failed to persist baseline: \(error.localizedDescription)",
                           subsystem: "Network")
        }
    }

    /// Loads a previously persisted baseline from secure storage.
    private func loadPersistedBaseline() {
        do {
            guard let snapshot = try storage.retrieveCodable(
                BaselineSnapshot.self, forKey: Self.storageKey
            ) else {
                logger.info("No persisted baseline found — starting fresh learning phase",
                            subsystem: "Network")
                return
            }

            queue.sync {
                _phase = snapshot.phase
                _learningStartDate = snapshot.learningStartDate
                _totalEventsObserved = snapshot.totalEventsObserved
                _featureVectors = snapshot.featureVectors

                _entries.removeAll()
                for entry in snapshot.entries {
                    let key = "\(entry.domainHash):\(entry.port):\(entry.protocolType.rawValue)"
                    _entries[key] = entry
                }
            }

            logger.info(
                "Loaded persisted baseline (\(snapshot.entries.count) entries, "
                + "phase: \(snapshot.phase.rawValue))",
                subsystem: "Network"
            )

            // If in protection phase, re-train the engine
            if snapshot.phase == .protection && !snapshot.featureVectors.isEmpty {
                AnomalyDetectionEngine.shared.updateBaseline(observations: snapshot.featureVectors)
            }
        } catch {
            logger.warning(
                "Failed to load persisted baseline: \(error.localizedDescription)",
                subsystem: "Network"
            )
        }
    }
}
