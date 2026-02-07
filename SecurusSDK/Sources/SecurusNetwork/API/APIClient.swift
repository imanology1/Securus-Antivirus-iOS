// ============================================================================
// APIClient.swift
// SecurusNetwork
//
// HTTPS client for communicating with the Securus backend.
// Enforces TLS 1.3, API key authentication, retry logic with
// exponential backoff, and anonymized payloads only.
// ============================================================================

import Foundation
import SecurusCore

// MARK: - APIClient

/// Secure HTTPS client for the Securus backend API.
///
/// ## Security
///
/// - All connections require TLS 1.3 minimum.
/// - The API key is sent in the `Authorization` header as a Bearer token.
/// - No PII is ever included in request payloads.
///
/// ## Retry Logic
///
/// Failed requests are retried up to 3 times with exponential backoff
/// (1s, 2s, 4s). Only transient errors (5xx, timeout, network unreachable)
/// trigger retries.
///
/// ## Thread Safety
///
/// The client is thread-safe. Multiple concurrent requests are supported.
public final class APIClient: @unchecked Sendable {

    // MARK: - Configuration

    /// Base URL for the backend API.
    public let baseURL: URL

    /// API key for authentication.
    private let apiKey: String

    /// Maximum number of retry attempts for transient failures.
    public var maxRetries: Int = 3

    /// Base delay between retries (exponential backoff multiplier).
    public var retryBaseDelay: TimeInterval = 1.0

    /// Request timeout interval in seconds.
    public var requestTimeout: TimeInterval = 30.0

    // MARK: - Properties

    private let session: URLSession
    private let logger = SecurusLogger.shared
    private let encoder = JSONEncoder()

    // MARK: - Init

    /// Creates an API client.
    ///
    /// - Parameters:
    ///   - baseURL: The backend API base URL.
    ///   - apiKey: The dashboard-issued API key.
    public init(baseURL: URL, apiKey: String) {
        self.baseURL = baseURL
        self.apiKey = apiKey

        // Configure session for TLS 1.3
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.tlsMinimumSupportedProtocolVersion = .TLSv13
        config.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "SecurusSDK/\(ThreatEvent.currentSDKVersion) iOS"
        ]
        // Do not use URL caching for security-sensitive reports
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        self.session = URLSession(configuration: config)
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - Report Threat

    /// Reports a threat event to `POST /v1/report`.
    ///
    /// - Parameter event: The threat event to report. Must contain only
    ///   anonymized data (hashed domains, no PII).
    /// - Returns: `true` if the report was accepted (2xx response).
    /// - Throws: `SecurusError.networkError` if all retry attempts fail.
    @discardableResult
    public func reportThreat(_ event: ThreatEvent) async throws -> Bool {
        let url = baseURL.appendingPathComponent("v1/report")
        let body = try encoder.encode(event)

        return try await performRequest(url: url, method: "POST", body: body)
    }

    /// Reports a batch of threat events to `POST /v1/report/batch`.
    ///
    /// - Parameter events: The threat events to report.
    /// - Returns: `true` if the batch was accepted.
    /// - Throws: `SecurusError.networkError` if all retry attempts fail.
    @discardableResult
    public func reportBatch(_ events: [ThreatEvent]) async throws -> Bool {
        guard !events.isEmpty else { return true }

        let url = baseURL.appendingPathComponent("v1/report/batch")
        let payload = ["events": events]
        let body = try encoder.encode(payload)

        return try await performRequest(url: url, method: "POST", body: body)
    }

    // MARK: - Generic Request

    /// Performs an authenticated HTTPS request with retry logic.
    ///
    /// - Parameters:
    ///   - url: The full request URL.
    ///   - method: HTTP method (GET, POST, etc.).
    ///   - body: Optional request body data.
    /// - Returns: `true` if the server responded with a 2xx status.
    /// - Throws: `SecurusError.networkError` after exhausting retries.
    private func performRequest(url: URL, method: String, body: Data? = nil) async throws -> Bool {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                var request = URLRequest(url: url, timeoutInterval: requestTimeout)
                request.httpMethod = method
                request.httpBody = body
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")

                let (_, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw SecurusError.networkError(reason: "Invalid response type")
                }

                let statusCode = httpResponse.statusCode

                // Success
                if (200..<300).contains(statusCode) {
                    logger.debug("Request succeeded: \(method) \(url.path) (\(statusCode))",
                                 subsystem: "API")
                    return true
                }

                // Client errors (4xx) are not retryable
                if (400..<500).contains(statusCode) {
                    logger.error("Client error: \(method) \(url.path) (\(statusCode))",
                                 subsystem: "API")
                    throw SecurusError.networkError(
                        reason: "Client error \(statusCode) for \(method) \(url.path)"
                    )
                }

                // Server errors (5xx) are retryable
                logger.warning(
                    "Server error \(statusCode), attempt \(attempt + 1)/\(maxRetries)",
                    subsystem: "API"
                )
                lastError = SecurusError.networkError(
                    reason: "Server error \(statusCode)"
                )
            } catch let error as SecurusError {
                // Non-retryable SDK errors
                if case .networkError(let reason, _) = error, reason.hasPrefix("Client error") {
                    throw error
                }
                lastError = error
            } catch {
                // Network-level errors (timeout, no connection) are retryable
                logger.warning(
                    "Request failed: \(error.localizedDescription), "
                    + "attempt \(attempt + 1)/\(maxRetries)",
                    subsystem: "API"
                )
                lastError = error
            }

            // Exponential backoff before retry
            if attempt < maxRetries - 1 {
                let delay = retryBaseDelay * pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw SecurusError.networkError(
            reason: "All \(maxRetries) attempts failed for \(method) \(url.path)",
            underlyingError: lastError
        )
    }

    // MARK: - Cleanup

    /// Cancels all outstanding requests and invalidates the session.
    public func invalidate() {
        session.invalidateAndCancel()
        logger.info("API client invalidated", subsystem: "API")
    }
}
