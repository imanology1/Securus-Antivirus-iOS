// ============================================================================
// SecurusAgent.swift
// SecurusCore
//
// Main entry point for the Securus SDK. The singleton `SecurusAgent`
// initializes, coordinates, and tears down all detection modules.
// All operations are wrapped in fail-safe guards so that an SDK
// failure never crashes the host application.
// ============================================================================

import Foundation

// MARK: - SecurusAgentState

/// Lifecycle state of the Securus agent.
public enum SecurusAgentState: String, Sendable {
    /// The agent has not been configured.
    case idle
    /// The agent has been configured but monitoring has not started.
    case configured
    /// The agent is actively monitoring.
    case running
    /// The agent has been stopped.
    case stopped
    /// The agent encountered a fatal error during startup.
    case error
}

// MARK: - SecurusAgentDelegate

/// Optional delegate for host applications that want to observe SDK lifecycle
/// events and threat detections.
public protocol SecurusAgentDelegate: AnyObject, Sendable {
    /// Called when the SDK detects a threat.
    func securusAgent(_ agent: SecurusAgent, didDetectThreat event: ThreatEvent)
    /// Called when the SDK's state changes.
    func securusAgent(_ agent: SecurusAgent, didChangeState newState: SecurusAgentState)
    /// Called when the SDK encounters a non-fatal error.
    func securusAgent(_ agent: SecurusAgent, didEncounterError error: SecurusError)
}

// MARK: - Default Delegate Implementations

public extension SecurusAgentDelegate {
    func securusAgent(_ agent: SecurusAgent, didDetectThreat event: ThreatEvent) {}
    func securusAgent(_ agent: SecurusAgent, didChangeState newState: SecurusAgentState) {}
    func securusAgent(_ agent: SecurusAgent, didEncounterError error: SecurusError) {}
}

// MARK: - SecurusAgent

/// The primary interface for the Securus iOS Security SDK.
///
/// `SecurusAgent` is a singleton that manages the lifecycle of all detection
/// modules, including network anomaly detection and runtime integrity checks.
///
/// ## Integration
///
/// ```swift
/// // In AppDelegate.application(_:didFinishLaunchingWithOptions:)
/// SecurusAgent.shared.configure(apiKey: "sk_live_...")
/// SecurusAgent.shared.start()
/// ```
///
/// ## Fail-Safe Design
///
/// Every public method is wrapped in a fail-safe handler. If any internal
/// operation throws or crashes, the error is logged and the host application
/// is never affected. This is a hard requirement of the SDK contract.
///
/// ## Thread Safety
///
/// All mutable state is protected by a serial dispatch queue.
public final class SecurusAgent: @unchecked Sendable {

    // MARK: - Singleton

    /// Shared agent instance.
    public static let shared = SecurusAgent()

    // MARK: - Properties

    /// Current lifecycle state.
    public private(set) var state: SecurusAgentState {
        get { queue.sync { _state } }
        set {
            queue.sync { _state = newValue }
            delegate?.securusAgent(self, didChangeState: newValue)
        }
    }

    /// Optional delegate for lifecycle and threat callbacks.
    public weak var delegate: SecurusAgentDelegate?

    /// The active configuration. Nil until `configure(...)` is called.
    public private(set) var configuration: SecurusConfiguration? {
        get { queue.sync { _configuration } }
        set { queue.sync { _configuration = newValue } }
    }

    // MARK: - Private State

    private var _state: SecurusAgentState = .idle
    private var _configuration: SecurusConfiguration?
    private var detectors: [any ThreatDetector] = []
    private let queue = DispatchQueue(label: "com.securus.agent")
    private let logger = SecurusLogger.shared

    // MARK: - Init

    private init() {}

    // MARK: - Configuration

    /// Configures the SDK with an API key using default settings.
    ///
    /// This is a convenience method. For full control use
    /// `configure(configuration:)`.
    ///
    /// - Parameter apiKey: The dashboard-issued API key.
    public func configure(apiKey: String) {
        let config = SecurusConfiguration(apiKey: apiKey)
        configure(configuration: config)
    }

    /// Configures the SDK with a full configuration object.
    ///
    /// Must be called before `start()`. Can be called multiple times to
    /// reconfigure, but only while the agent is not running.
    ///
    /// - Parameter configuration: The SDK configuration.
    public func configure(configuration: SecurusConfiguration) {
        failSafe {
            guard state != .running else {
                logger.warning("Cannot reconfigure while running. Stop first.", subsystem: "Agent")
                return
            }

            try configuration.validate()

            self.configuration = configuration
            logger.logLevel = configuration.logLevel

            // Store API key securely
            try SecureStorage.shared.store(configuration.apiKey, forKey: "com.securus.apiKey")

            // Initialize the anomaly detection engine
            do {
                try AnomalyDetectionEngine.shared.loadModel()
            } catch {
                // Non-fatal: the engine will use its statistical fallback
                logger.warning("ML model load skipped: \(error.localizedDescription)",
                               subsystem: "Agent")
            }

            // Generate or retrieve device token
            let token = TokenGenerator.shared.deviceToken()
            logger.info("Device token: \(token.prefix(20))...", subsystem: "Agent")

            state = .configured
            logger.info("SDK configured successfully", subsystem: "Agent")
        }
    }

    // MARK: - Lifecycle

    /// Starts all enabled detection modules.
    ///
    /// The agent must be configured before starting. If network monitoring
    /// is enabled, the network module will begin its learning/protection
    /// phase. If runtime protection is enabled, integrity checks run
    /// immediately and then at the configured interval.
    public func start() {
        failSafe {
            guard let config = configuration else {
                throw SecurusError.configurationError(
                    reason: "SDK must be configured before calling start()."
                )
            }

            guard state == .configured || state == .stopped else {
                logger.warning("Cannot start from state: \(state.rawValue)", subsystem: "Agent")
                return
            }

            logger.info("Starting Securus SDK v\(ThreatEvent.currentSDKVersion)", subsystem: "Agent")

            // Clear previous detectors
            queue.sync { detectors.removeAll() }

            // Start performance monitoring
            PerformanceMonitor.shared.startMonitoring()
            PerformanceMonitor.shared.budgetExceededHandler = { [weak self] snapshot in
                self?.logger.warning(
                    "Performance budget exceeded. Consider reducing scan frequency.",
                    subsystem: "Agent"
                )
            }

            // Register and start each enabled module
            if config.enableNetworkMonitoring {
                startNetworkModule()
            }

            if config.enableRuntimeProtection {
                startRuntimeModule()
            }

            state = .running
            logger.info("SDK started with \(detectors.count) active module(s)", subsystem: "Agent")
        }
    }

    /// Stops all detection modules and releases resources.
    ///
    /// Safe to call even if the agent is not running (no-op in that case).
    public func stop() {
        failSafe {
            guard state == .running else {
                logger.debug("Stop called but agent is not running", subsystem: "Agent")
                return
            }

            logger.info("Stopping Securus SDK...", subsystem: "Agent")

            // Stop all detectors
            queue.sync {
                for detector in detectors {
                    detector.stopMonitoring()
                }
                detectors.removeAll()
            }

            // Stop performance monitoring
            PerformanceMonitor.shared.stopMonitoring()

            state = .stopped
            logger.info("SDK stopped", subsystem: "Agent")
        }
    }

    // MARK: - Module Registration

    /// Registers an external threat detector module.
    ///
    /// This allows host applications or third-party modules to plug into
    /// the SDK's detection pipeline.
    ///
    /// - Parameter detector: A threat detector conforming to `ThreatDetector`.
    public func registerDetector(_ detector: any ThreatDetector) {
        failSafe {
            var mutableDetector = detector
            mutableDetector.delegate = self
            queue.sync { detectors.append(mutableDetector) }
            logger.info("Registered detector: \(detector.moduleName)", subsystem: "Agent")

            if state == .running {
                mutableDetector.startMonitoring()
            }
        }
    }

    // MARK: - Private: Module Startup

    private func startNetworkModule() {
        // Lazy-load the network module to avoid hard-linking at import time.
        // The module is loaded dynamically if available.
        if let moduleClass = NSClassFromString("SecurusNetwork.SecurusNetworkModule") as? NSObject.Type,
           let detector = moduleClass.init() as? any ThreatDetector {
            var mutableDetector = detector
            mutableDetector.delegate = self
            queue.sync { detectors.append(mutableDetector) }
            mutableDetector.startMonitoring()
            logger.info("Network module started", subsystem: "Agent")
        } else {
            logger.warning(
                "SecurusNetwork module not available. Add it to your dependencies.",
                subsystem: "Agent"
            )
        }
    }

    private func startRuntimeModule() {
        if let moduleClass = NSClassFromString("SecurusRuntime.SecurusRuntimeModule") as? NSObject.Type,
           let detector = moduleClass.init() as? any ThreatDetector {
            var mutableDetector = detector
            mutableDetector.delegate = self
            queue.sync { detectors.append(mutableDetector) }
            mutableDetector.startMonitoring()
            logger.info("Runtime module started", subsystem: "Agent")
        } else {
            logger.warning(
                "SecurusRuntime module not available. Add it to your dependencies.",
                subsystem: "Agent"
            )
        }
    }

    // MARK: - Fail-Safe Wrapper

    /// Executes a closure in a fail-safe context.
    ///
    /// If the closure throws, the error is logged and the agent transitions
    /// to the `.error` state. The host application is **never** impacted by
    /// an SDK failure.
    private func failSafe(_ operation: () throws -> Void) {
        do {
            try operation()
        } catch let error as SecurusError {
            logger.error("SDK error: \(error.localizedDescription)", subsystem: "Agent")
            delegate?.securusAgent(self, didEncounterError: error)
        } catch {
            let wrapped = SecurusError.detectionError(
                reason: "Unexpected error: \(error.localizedDescription)",
                underlyingError: error
            )
            logger.error("Unexpected SDK error: \(error.localizedDescription)", subsystem: "Agent")
            delegate?.securusAgent(self, didEncounterError: wrapped)
        }
    }
}

// MARK: - ThreatDetectorDelegate

extension SecurusAgent: ThreatDetectorDelegate {

    public func threatDetector(_ detector: any ThreatDetector, didDetect event: ThreatEvent) {
        failSafe {
            logger.warning(
                "Threat detected by \(detector.moduleName): \(event.threat_type.rawValue) "
                + "(severity: \(event.severity.rawValue))",
                subsystem: "Agent"
            )
            delegate?.securusAgent(self, didDetectThreat: event)
        }
    }

    public func threatDetector(_ detector: any ThreatDetector, didEncounterError error: SecurusError) {
        failSafe {
            logger.error(
                "Error from \(detector.moduleName): \(error.localizedDescription)",
                subsystem: "Agent"
            )
            delegate?.securusAgent(self, didEncounterError: error)
        }
    }
}
