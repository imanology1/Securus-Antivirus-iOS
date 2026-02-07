// ============================================================================
// AnomalyScorer.swift
// SecurusNetwork
//
// Scores network events against the learned baseline. Combines domain-level
// whitelist checks with the Core ML anomaly detection engine for
// feature-level scoring.
// ============================================================================

import Foundation
import SecurusCore

// MARK: - ScoringResult

/// The result of scoring a single network event against the baseline.
public struct ScoringResult: Sendable {
    /// The network event that was scored.
    public let event: NetworkEvent
    /// The anomaly score from the ML/statistical engine (0.0 - 1.0).
    public let anomalyScore: AnomalyScore
    /// Whether the destination is in the learned baseline.
    public let isKnownDestination: Bool
    /// The combined risk assessment.
    public let riskLevel: RiskLevel

    /// Risk classification based on combined scoring factors.
    public enum RiskLevel: String, Sendable {
        /// Event matches baseline — no action required.
        case normal
        /// Event shows minor deviations — log but do not report.
        case elevated
        /// Event shows significant deviations — report as threat.
        case suspicious
        /// Unknown destination with high anomaly score — critical report.
        case critical
    }
}

// MARK: - AnomalyScorer

/// Evaluates network events against the learned baseline to identify
/// potentially malicious or anomalous traffic.
///
/// The scorer uses a two-stage approach:
///
/// 1. **Domain Check**: Is the destination domain hash in the learned baseline?
///    Unknown domains immediately receive an elevated risk score.
///
/// 2. **Feature Scoring**: The event's feature vector (port, protocol, size,
///    response code, duration) is passed through the `AnomalyDetectionEngine`
///    for ML-based or statistical scoring.
///
/// The final risk level is a combination of both stages.
public final class AnomalyScorer: @unchecked Sendable {

    // MARK: - Properties

    /// Reference to the baseline manager for domain lookup.
    private let baselineManager: BaselineManager

    /// Reference to the anomaly detection engine.
    private let engine: AnomalyDetectionEngine

    /// Minimum anomaly score to trigger a suspicious classification.
    public var suspiciousThreshold: Double = 0.6

    /// Minimum anomaly score to trigger a critical classification.
    public var criticalThreshold: Double = 0.85

    private let logger = SecurusLogger.shared

    // MARK: - Init

    /// Creates a scorer with the given baseline and engine.
    ///
    /// - Parameters:
    ///   - baselineManager: The baseline to compare events against.
    ///   - engine: The anomaly detection engine for feature-level scoring.
    public init(baselineManager: BaselineManager,
                engine: AnomalyDetectionEngine = .shared) {
        self.baselineManager = baselineManager
        self.engine = engine
    }

    // MARK: - Scoring

    /// Scores a single network event against the baseline.
    ///
    /// - Parameter event: The network event to evaluate.
    /// - Returns: A `ScoringResult` with the anomaly assessment.
    public func score(event: NetworkEvent) -> ScoringResult {
        let isKnown = baselineManager.isKnown(event)
        let features = event.toFeatureVector()
        let anomalyScore = engine.score(features: features)

        let riskLevel = classifyRisk(isKnown: isKnown, score: anomalyScore.score)

        logger.debug(
            "Scored event \(event.id.prefix(8)): known=\(isKnown), "
            + "score=\(String(format: "%.3f", anomalyScore.score)), "
            + "risk=\(riskLevel.rawValue)",
            subsystem: "Network"
        )

        return ScoringResult(
            event: event,
            anomalyScore: anomalyScore,
            isKnownDestination: isKnown,
            riskLevel: riskLevel
        )
    }

    /// Scores a batch of events and returns only those classified as
    /// suspicious or critical.
    ///
    /// - Parameter events: The events to evaluate.
    /// - Returns: Scoring results filtered to elevated risk and above.
    public func scoreAndFilter(events: [NetworkEvent]) -> [ScoringResult] {
        events.map { score(event: $0) }
              .filter { $0.riskLevel == .suspicious || $0.riskLevel == .critical }
    }

    // MARK: - Risk Classification

    /// Determines the overall risk level from the domain check and anomaly score.
    ///
    /// | Known | Score        | Risk       |
    /// |-------|--------------|------------|
    /// | Yes   | < 0.6        | normal     |
    /// | Yes   | 0.6 - 0.85   | elevated   |
    /// | Yes   | >= 0.85      | suspicious |
    /// | No    | < 0.6        | elevated   |
    /// | No    | 0.6 - 0.85   | suspicious |
    /// | No    | >= 0.85      | critical   |
    private func classifyRisk(isKnown: Bool, score: Double) -> ScoringResult.RiskLevel {
        if isKnown {
            if score >= criticalThreshold {
                return .suspicious
            } else if score >= suspiciousThreshold {
                return .elevated
            } else {
                return .normal
            }
        } else {
            if score >= criticalThreshold {
                return .critical
            } else if score >= suspiciousThreshold {
                return .suspicious
            } else {
                return .elevated
            }
        }
    }
}
