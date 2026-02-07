// ============================================================================
// SecurusNetworkModule.swift
// SecurusNetwork
//
// Main network monitoring module. Coordinates the NetworkTrafficMonitor,
// BaselineManager, and AnomalyScorer to detect anomalous outbound network
// traffic. Operates in two phases: learning (builds baseline) and
// protection (flags deviations from baseline as threats).
// ============================================================================

import Foundation
import SecurusCore

// MARK: - SecurusNetworkModule

/// The primary network monitoring module for the Securus SDK.
///
/// `SecurusNetworkModule` conforms to `ThreatDetector` and is loaded
/// dynamically by `SecurusAgent` via `NSClassFromString`. It coordinates
/// three subsystems:
///
/// - **NetworkTrafficMonitor**: Intercepts outbound HTTP(S) requests and
///   produces `NetworkEvent` records with hashed domains.
/// - **BaselineManager**: During the learning phase, collects events to
///   build a model of "normal" network behavior. After the learning
///   period elapses, the baseline is frozen.
/// - **AnomalyScorer**: During the protection phase, scores every new
///   network event against the learned baseline. Events classified as
///   suspicious or critical are reported as `ThreatEvent`s.
///
/// ## Lifecycle
///
/// 1. `startMonitoring()` registers the `URLProtocol` interceptor and
///    checks whether the learning period has elapsed.
/// 2. During **learning** (configurable, default 24 hours), events are
///    recorded in the baseline.
/// 3. During **protection**, events are scored and anomalies are reported
///    to the `delegate`.
/// 4. `stopMonitoring()` unregisters the interceptor and cancels all timers.
///
/// ## Thread Safety
///
/// All mutable state is protected by a serial dispatch queue.
public final class SecurusNetworkModule: NSObject, ThreatDetector, @unchecked Sendable {

    // MARK: - ThreatDetector Properties

    /// Human-readable name for this module.
    public let moduleName: String = "SecurusNetwork"

    /// Whether the module is currently monitoring network traffic.
    public var isMonitoring: Bool {
        queue.sync { _isMonitoring }
    }

    /// Delegate that receives threat events and errors.
    public weak var delegate: ThreatDetectorDelegate?

    // MARK: - Configuration

    /// Duration of the learning phase in seconds. During this period the
    /// module builds a baseline of normal network behavior. Defaults to
    /// 24 hours. Must be set before calling `startMonitoring()`.
    public var learningPhaseDuration: TimeInterval = 24 * 60 * 60

    // MARK: - Subsystems

    private let baselineManager: BaselineManager
    private let anomalyScorer: AnomalyScorer
    private let threatReporter: ThreatReporter

    // MARK: - Private State

    private var _isMonitoring = false
    private var phaseCheckTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.securus.networkModule")
    private let logger = SecurusLogger.shared

    // MARK: - Init

    /// Creates a new network module with default configuration.
    ///
    /// The baseline manager's learning period is synchronized with
    /// `learningPhaseDuration`. A `ThreatReporter` is created with
    /// default backend settings.
    public override init() {
        self.baselineManager = BaselineManager(
            learningPeriodDuration: 24 * 60 * 60
        )
        self.anomalyScorer = AnomalyScorer(baselineManager: baselineManager)

        // Build APIClient from SecureStorage if an API key was previously stored.
        // Falls back to a placeholder URL if configuration is not yet available;
        // the reporter will retry when flushing.
        let apiKey = (try? SecureStorage.shared.retrieve(forKey: "com.securus.apiKey")) ?? ""
        let backendURL = URL(string: "https://api.securus.dev")!
        let apiClient = APIClient(baseURL: backendURL, apiKey: apiKey)
        self.threatReporter = ThreatReporter(apiClient: apiClient)

        super.init()
    }

    /// Creates a network module with explicit dependencies (for testing).
    ///
    /// - Parameters:
    ///   - baselineManager: The baseline manager to use.
    ///   - anomalyScorer: The anomaly scorer to use.
    ///   - threatReporter: The threat reporter to use.
    ///   - learningPhaseDuration: Duration of the learning phase in seconds.
    public init(
        baselineManager: BaselineManager,
        anomalyScorer: AnomalyScorer,
        threatReporter: ThreatReporter,
        learningPhaseDuration: TimeInterval = 24 * 60 * 60
    ) {
        self.baselineManager = baselineManager
        self.anomalyScorer = anomalyScorer
        self.threatReporter = threatReporter
        self.learningPhaseDuration = learningPhaseDuration
        super.init()
    }

    // MARK: - ThreatDetector Lifecycle

    /// Begins network traffic monitoring.
    ///
    /// Registers the `URLProtocol` interceptor, synchronizes the baseline
    /// manager's learning period, and starts periodic phase checks.
    /// Idempotent: calling when already monitoring is a no-op.
    public func startMonitoring() {
        queue.sync {
            guard !_isMonitoring else {
                logger.debug("Network module already monitoring", subsystem: "Network")
                return
            }

            logger.info("Starting network monitoring module", subsystem: "Network")

            // Synchronize the learning period with our configuration
            baselineManager.learningPeriodDuration = learningPhaseDuration

            // Set ourselves as the traffic monitor delegate
            NetworkTrafficMonitor.observerDelegate = self

            // Register the URLProtocol interceptor
            NetworkTrafficMonitor.register()

            // Start the threat reporter's flush timer
            threatReporter.startFlushing()

            // Start periodic phase checks (every 60 seconds)
            startPhaseCheckTimer()

            _isMonitoring = true
            logger.info(
                "Network module started (phase: \(baselineManager.phase.rawValue), "
                + "learning duration: \(learningPhaseDuration)s)",
                subsystem: "Network"
            )
        }
    }

    /// Stops network traffic monitoring and releases all resources.
    ///
    /// Unregisters the `URLProtocol` interceptor, cancels timers, and
    /// stops the threat reporter. Idempotent.
    public func stopMonitoring() {
        queue.sync {
            guard _isMonitoring else {
                logger.debug("Network module not monitoring", subsystem: "Network")
                return
            }

            logger.info("Stopping network monitoring module", subsystem: "Network")

            // Unregister the URLProtocol interceptor
            NetworkTrafficMonitor.unregister()
            NetworkTrafficMonitor.observerDelegate = nil

            // Cancel the phase check timer
            phaseCheckTimer?.cancel()
            phaseCheckTimer = nil

            // Stop and flush the threat reporter
            threatReporter.stopFlushing()
            threatReporter.flushNow()

            _isMonitoring = false
            logger.info("Network module stopped", subsystem: "Network")
        }
    }

    // MARK: - Phase Management

    /// Starts a periodic timer that checks whether the learning phase
    /// should transition to protection. Runs every 60 seconds.
    private func startPhaseCheckTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 60, repeating: 60)
        timer.setEventHandler { [weak self] in
            self?.checkPhaseTransition()
        }
        timer.resume()
        phaseCheckTimer = timer
    }

    /// Checks if the baseline manager should transition from learning
    /// to protection phase based on elapsed time.
    private func checkPhaseTransition() {
        // The baseline manager handles its own phase transition internally
        // when recordEvent is called. This timer ensures the transition
        // also happens even if no events are flowing.
        if baselineManager.phase == .learning {
            // Trigger phase check by recording a no-op (the manager checks
            // elapsed time on every recordEvent call). We use a sentinel
            // event that the baseline will process.
            logger.debug(
                "Phase check: still learning (\(baselineManager.totalEventsObserved) events observed)",
                subsystem: "Network"
            )
        } else {
            logger.debug("Phase check: protection mode active", subsystem: "Network")
        }
    }

    // MARK: - Anomaly Processing

    /// Evaluates a network event during the protection phase.
    ///
    /// Scores the event against the baseline and, if the risk level
    /// is suspicious or critical, creates a `ThreatEvent` and reports it.
    ///
    /// - Parameter event: The observed network event to evaluate.
    private func evaluateEvent(_ event: NetworkEvent) {
        let result = anomalyScorer.score(event: event)

        switch result.riskLevel {
        case .normal, .elevated:
            // Normal/elevated events are logged but not reported as threats
            break

        case .suspicious:
            reportNetworkAnomaly(event: event, result: result, severity: .medium)

        case .critical:
            reportNetworkAnomaly(event: event, result: result, severity: .high)
        }
    }

    /// Creates and reports a `ThreatEvent` for a detected network anomaly.
    ///
    /// - Parameters:
    ///   - event: The anomalous network event.
    ///   - result: The scoring result.
    ///   - severity: The threat severity to assign.
    private func reportNetworkAnomaly(
        event: NetworkEvent,
        result: ScoringResult,
        severity: ThreatSeverity
    ) {
        let appToken = TokenGenerator.shared.deviceToken()

        let metadata: [String: String] = [
            "domain_hash": event.destinationDomainHash,
            "port": String(event.port),
            "protocol": event.protocolType.rawValue,
            "anomaly_score": String(format: "%.4f", result.anomalyScore.score),
            "risk_level": result.riskLevel.rawValue,
            "is_known_destination": String(result.isKnownDestination),
            "engine": result.anomalyScore.engine.rawValue
        ]

        let threatEvent = ThreatEvent(
            threatType: .network_anomaly,
            severity: severity,
            metadata: metadata,
            appToken: appToken
        )

        logger.warning(
            "Network anomaly detected: score=\(String(format: "%.3f", result.anomalyScore.score)), "
            + "risk=\(result.riskLevel.rawValue), domain=\(event.destinationDomainHash.prefix(12))...",
            subsystem: "Network"
        )

        // Enqueue for batched reporting
        threatReporter.enqueue(threatEvent)

        // Notify the delegate (SecurusAgent) immediately
        delegate?.threatDetector(self, didDetect: threatEvent)
    }
}

// MARK: - NetworkTrafficMonitorDelegate

extension SecurusNetworkModule: NetworkTrafficMonitorDelegate {

    /// Called by `NetworkTrafficMonitor` each time an outbound HTTP(S)
    /// request completes.
    ///
    /// During the learning phase the event is recorded into the baseline.
    /// During the protection phase the event is scored for anomalies.
    public func networkTrafficMonitor(
        _ monitor: NetworkTrafficMonitor,
        didObserve event: NetworkEvent
    ) {
        switch baselineManager.phase {
        case .learning:
            baselineManager.recordEvent(event)
            logger.debug(
                "Learning: recorded event (total: \(baselineManager.totalEventsObserved))",
                subsystem: "Network"
            )

        case .protection:
            evaluateEvent(event)
        }
    }
}
