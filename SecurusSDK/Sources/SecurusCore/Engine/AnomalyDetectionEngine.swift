// ============================================================================
// AnomalyDetectionEngine.swift
// SecurusCore
//
// On-device Core ML anomaly detection engine. Loads a compiled .mlmodelc
// model, accepts feature vectors, and returns anomaly scores. Optimized
// for Apple's Neural Engine. Includes a statistical fallback when Core ML
// is unavailable (simulator, model missing, etc.).
// ============================================================================

import Foundation
import CoreML

// MARK: - AnomalyScore

/// The result of running a feature vector through anomaly detection.
public struct AnomalyScore: Sendable {
    /// Anomaly score in the range [0.0, 1.0]. Higher = more anomalous.
    public let score: Double
    /// Whether this score exceeds the configured threshold.
    public let isAnomalous: Bool
    /// Which engine produced the score.
    public let engine: EngineType

    public enum EngineType: String, Sendable {
        case coreML = "CoreML"
        case statisticalFallback = "StatisticalFallback"
    }

    public init(score: Double, isAnomalous: Bool, engine: EngineType) {
        self.score = score
        self.isAnomalous = isAnomalous
        self.engine = engine
    }
}

// MARK: - AnomalyDetectionEngine

/// Core ML-backed anomaly detection engine.
///
/// The engine attempts to load a compiled Core ML model
/// (`SecurusAnomalyDetector.mlmodelc`) from the SDK's resource bundle.
/// If the model is unavailable or inference fails, it transparently
/// falls back to a statistical z-score-based detector so that the SDK
/// can still function in test environments and on older hardware.
///
/// ## Neural Engine Optimization
///
/// The model configuration requests `.all` compute units, which allows
/// Core ML to schedule work on the Neural Engine (ANE) when available.
/// This minimizes CPU overhead and battery impact.
///
/// ## Thread Safety
///
/// All mutable state is protected by a serial dispatch queue. The
/// engine is safe to call from any thread.
public final class AnomalyDetectionEngine: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = AnomalyDetectionEngine()

    // MARK: - Properties

    /// The anomaly threshold above which a score is flagged as anomalous.
    public var anomalyThreshold: Double {
        get { queue.sync { _anomalyThreshold } }
        set { queue.sync { _anomalyThreshold = newValue } }
    }

    private var _anomalyThreshold: Double = 0.7
    private var mlModel: MLModel?
    private var isModelLoaded = false
    private var _baselineMean: [Double] = []
    private var _baselineStdDev: [Double] = []
    private let queue = DispatchQueue(label: "com.securus.anomalyEngine")
    private let logger = SecurusLogger.shared

    // MARK: - Init

    private init() {}

    // MARK: - Model Loading

    /// Attempts to load the Core ML model from the SDK's bundle.
    ///
    /// Call this once during SDK initialization. If the model cannot be
    /// loaded (missing, incompatible, etc.), the engine silently falls back
    /// to the statistical detector.
    ///
    /// - Throws: `SecurusError.mlModelError` if an unexpected error occurs.
    ///           Model-not-found is handled gracefully and does not throw.
    public func loadModel() throws {
        try queue.sync {
            // Look for the compiled model in the module bundle
            let bundle = Bundle.module

            guard let modelURL = bundle.url(forResource: "SecurusAnomalyDetector",
                                            withExtension: "mlmodelc") else {
                logger.info(
                    "Core ML model not found in bundle — using statistical fallback",
                    subsystem: "ML"
                )
                isModelLoaded = false
                return
            }

            do {
                let config = MLModelConfiguration()
                config.computeUnits = .all // Prefer Neural Engine
                mlModel = try MLModel(contentsOf: modelURL, configuration: config)
                isModelLoaded = true
                logger.info("Core ML model loaded successfully", subsystem: "ML")
            } catch {
                logger.warning(
                    "Failed to load Core ML model: \(error.localizedDescription) — using fallback",
                    subsystem: "ML"
                )
                isModelLoaded = false
                throw SecurusError.mlModelError(
                    reason: "Failed to load anomaly detection model",
                    underlyingError: error
                )
            }
        }
    }

    // MARK: - Scoring

    /// Scores a feature vector for anomalies.
    ///
    /// - Parameter features: An array of `Double` values representing the
    ///   observation to evaluate. The feature vector layout must match the
    ///   model's expected input (or the baseline dimensions for fallback).
    /// - Returns: An `AnomalyScore` indicating how anomalous the input is.
    public func score(features: [Double]) -> AnomalyScore {
        queue.sync {
            if isModelLoaded, let model = mlModel {
                return coreMLScore(features: features, model: model)
            } else {
                return statisticalScore(features: features)
            }
        }
    }

    // MARK: - Baseline (for statistical fallback)

    /// Updates the statistical baseline used by the fallback engine.
    ///
    /// Call this periodically during the learning phase with observed
    /// feature vectors. The engine computes a running mean and standard
    /// deviation for each feature dimension.
    ///
    /// - Parameter observations: An array of feature vectors, all of the
    ///   same dimensionality.
    public func updateBaseline(observations: [[Double]]) {
        queue.sync {
            guard let first = observations.first else { return }
            let dimensions = first.count
            guard observations.allSatisfy({ $0.count == dimensions }) else {
                logger.warning("Inconsistent feature dimensions in baseline update", subsystem: "ML")
                return
            }

            let count = Double(observations.count)

            // Compute per-dimension mean
            var mean = [Double](repeating: 0.0, count: dimensions)
            for obs in observations {
                for d in 0..<dimensions {
                    mean[d] += obs[d]
                }
            }
            mean = mean.map { $0 / count }

            // Compute per-dimension standard deviation
            var stdDev = [Double](repeating: 0.0, count: dimensions)
            for obs in observations {
                for d in 0..<dimensions {
                    let diff = obs[d] - mean[d]
                    stdDev[d] += diff * diff
                }
            }
            stdDev = stdDev.map { sqrt($0 / max(count - 1, 1)) }

            _baselineMean = mean
            _baselineStdDev = stdDev

            logger.debug(
                "Baseline updated with \(observations.count) observations (\(dimensions) dims)",
                subsystem: "ML"
            )
        }
    }

    /// Resets the engine, unloading the model and clearing the baseline.
    public func reset() {
        queue.sync {
            mlModel = nil
            isModelLoaded = false
            _baselineMean = []
            _baselineStdDev = []
            logger.info("Anomaly detection engine reset", subsystem: "ML")
        }
    }

    // MARK: - Core ML Inference

    /// Runs inference using the loaded Core ML model.
    private func coreMLScore(features: [Double], model: MLModel) -> AnomalyScore {
        do {
            // Build a multi-array input matching the model's expected shape.
            let multiArray = try MLMultiArray(shape: [NSNumber(value: features.count)],
                                              dataType: .float32)
            for (index, value) in features.enumerated() {
                multiArray[index] = NSNumber(value: Float(value))
            }

            let inputFeatureProvider = try MLDictionaryFeatureProvider(
                dictionary: ["features": MLFeatureValue(multiArray: multiArray)]
            )

            let prediction = try model.prediction(from: inputFeatureProvider)

            // Extract the anomaly score from the model output.
            // Convention: the model outputs a feature named "anomaly_score".
            if let scoreValue = prediction.featureValue(for: "anomaly_score") {
                let rawScore = scoreValue.doubleValue
                let clampedScore = min(max(rawScore, 0.0), 1.0)
                return AnomalyScore(
                    score: clampedScore,
                    isAnomalous: clampedScore >= _anomalyThreshold,
                    engine: .coreML
                )
            }

            // If output name doesn't match, fall through to fallback
            logger.warning("Core ML model output missing 'anomaly_score' — using fallback",
                           subsystem: "ML")
            return statisticalScore(features: features)
        } catch {
            logger.warning("Core ML inference failed: \(error.localizedDescription) — using fallback",
                           subsystem: "ML")
            return statisticalScore(features: features)
        }
    }

    // MARK: - Statistical Fallback (Z-Score)

    /// Computes an anomaly score using z-score distance from the learned baseline.
    ///
    /// For each feature dimension, the z-score is computed as:
    ///   `z = |x - mean| / stdDev`
    ///
    /// The overall anomaly score is the maximum z-score across all dimensions,
    /// normalized to [0, 1] using a sigmoid-like transform.
    private func statisticalScore(features: [Double]) -> AnomalyScore {
        // If no baseline is available, treat everything as mildly anomalous
        guard !_baselineMean.isEmpty,
              features.count == _baselineMean.count else {
            return AnomalyScore(score: 0.5, isAnomalous: false, engine: .statisticalFallback)
        }

        var maxZScore: Double = 0.0
        for d in 0..<features.count {
            let stdDev = _baselineStdDev[d]
            guard stdDev > 1e-10 else { continue } // Skip zero-variance dimensions
            let z = abs(features[d] - _baselineMean[d]) / stdDev
            maxZScore = max(maxZScore, z)
        }

        // Normalize z-score to [0, 1] using a sigmoid: score = 1 / (1 + e^(-k*(z-c)))
        // k=1.5, c=2.0 centers the sigmoid so that z~2 maps to ~0.5
        let normalizedScore = 1.0 / (1.0 + exp(-1.5 * (maxZScore - 2.0)))

        return AnomalyScore(
            score: normalizedScore,
            isAnomalous: normalizedScore >= _anomalyThreshold,
            engine: .statisticalFallback
        )
    }
}
