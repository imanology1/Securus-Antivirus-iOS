// ============================================================================
// Configuration.swift
// SecurusCore
//
// SDK configuration model. Provides sensible defaults while allowing
// host applications to customize behavior.
// ============================================================================

import Foundation

// MARK: - SecurusConfiguration

/// Configuration parameters for the Securus SDK.
///
/// The host application provides a configuration at initialization time via
/// `SecurusAgent.configure(configuration:)`. Sensible defaults are applied
/// for every parameter except `apiKey`, which is required.
///
/// Example:
/// ```swift
/// var config = SecurusConfiguration(apiKey: "sk_live_abc123")
/// config.enableNetworkMonitoring = true
/// config.logLevel = .debug
/// SecurusAgent.shared.configure(configuration: config)
/// ```
public struct SecurusConfiguration: Sendable {

    // MARK: - Required

    /// API key issued by the Securus dashboard. Required.
    public let apiKey: String

    // MARK: - Backend

    /// Base URL for the Securus backend API.
    public var backendURL: URL

    // MARK: - Timing

    /// Duration (in seconds) of the learning phase during which the SDK builds
    /// a network traffic baseline before switching to protection mode.
    /// Default: 7 days.
    public var learningPeriodDuration: TimeInterval

    /// Interval (in seconds) between periodic runtime integrity scans.
    /// Default: 300 seconds (5 minutes).
    public var scanInterval: TimeInterval

    // MARK: - Feature Flags

    /// Whether the network monitoring module should be active.
    public var enableNetworkMonitoring: Bool

    /// Whether the runtime protection module should be active.
    public var enableRuntimeProtection: Bool

    // MARK: - Logging

    /// Minimum log level emitted by the SDK.
    public var logLevel: LogLevel

    // MARK: - Initializer

    /// Creates a new SDK configuration.
    ///
    /// - Parameters:
    ///   - apiKey: Dashboard-issued API key. Must not be empty.
    ///   - backendURL: Backend API base URL. Defaults to `https://api.securus.dev`.
    ///   - learningPeriodDuration: Learning phase duration in seconds. Default: 7 days.
    ///   - scanInterval: Runtime scan interval in seconds. Default: 5 minutes.
    ///   - enableNetworkMonitoring: Enable network monitoring. Default: `true`.
    ///   - enableRuntimeProtection: Enable runtime integrity checks. Default: `true`.
    ///   - logLevel: Minimum log level. Default: `.warning`.
    public init(
        apiKey: String,
        backendURL: URL = URL(string: "https://api.securus.dev")!,
        learningPeriodDuration: TimeInterval = 7 * 24 * 60 * 60,
        scanInterval: TimeInterval = 300,
        enableNetworkMonitoring: Bool = true,
        enableRuntimeProtection: Bool = true,
        logLevel: LogLevel = .warning
    ) {
        self.apiKey = apiKey
        self.backendURL = backendURL
        self.learningPeriodDuration = learningPeriodDuration
        self.scanInterval = scanInterval
        self.enableNetworkMonitoring = enableNetworkMonitoring
        self.enableRuntimeProtection = enableRuntimeProtection
        self.logLevel = logLevel
    }

    // MARK: - Validation

    /// Validates the configuration and throws if it is invalid.
    public func validate() throws {
        guard !apiKey.isEmpty else {
            throw SecurusError.configurationError(reason: "API key must not be empty.")
        }
        guard apiKey.count >= 10 else {
            throw SecurusError.configurationError(
                reason: "API key appears too short. Expected at least 10 characters."
            )
        }
        guard backendURL.scheme == "https" else {
            throw SecurusError.configurationError(
                reason: "Backend URL must use HTTPS. Got: \(backendURL.scheme ?? "nil")"
            )
        }
        guard learningPeriodDuration > 0 else {
            throw SecurusError.configurationError(
                reason: "Learning period duration must be positive."
            )
        }
        guard scanInterval >= 10 else {
            throw SecurusError.configurationError(
                reason: "Scan interval must be at least 10 seconds."
            )
        }
    }
}
