// ============================================================================
// SecurusError.swift
// SecurusCore
//
// Defines all error types used throughout the Securus SDK.
// ============================================================================

import Foundation

// MARK: - SecurusError

/// Comprehensive error type for the Securus SDK.
///
/// All errors thrown or returned by any Securus module are represented by this
/// enum. Each case carries an associated human-readable message and, where
/// appropriate, an underlying system error for diagnostic purposes.
public enum SecurusError: LocalizedError, Sendable {

    // MARK: Configuration Errors

    /// The SDK has not been configured, or configuration is invalid.
    case configurationError(reason: String)

    // MARK: Network Errors

    /// A network operation failed (reporting, baseline sync, etc.).
    case networkError(reason: String, underlyingError: Error? = nil)

    // MARK: Detection Errors

    /// A threat detection operation failed.
    case detectionError(reason: String, underlyingError: Error? = nil)

    // MARK: Storage Errors

    /// A Keychain or persistent storage operation failed.
    case storageError(reason: String, statusCode: OSStatus? = nil)

    // MARK: Core ML Errors

    /// The Core ML model could not be loaded or evaluated.
    case mlModelError(reason: String, underlyingError: Error? = nil)

    // MARK: - LocalizedError Conformance

    public var errorDescription: String? {
        switch self {
        case .configurationError(let reason):
            return "[Securus] Configuration error: \(reason)"
        case .networkError(let reason, let underlying):
            let base = "[Securus] Network error: \(reason)"
            if let underlying {
                return "\(base) — \(underlying.localizedDescription)"
            }
            return base
        case .detectionError(let reason, let underlying):
            let base = "[Securus] Detection error: \(reason)"
            if let underlying {
                return "\(base) — \(underlying.localizedDescription)"
            }
            return base
        case .storageError(let reason, let statusCode):
            let base = "[Securus] Storage error: \(reason)"
            if let code = statusCode {
                return "\(base) (OSStatus: \(code))"
            }
            return base
        case .mlModelError(let reason, let underlying):
            let base = "[Securus] ML model error: \(reason)"
            if let underlying {
                return "\(base) — \(underlying.localizedDescription)"
            }
            return base
        }
    }

    public var failureReason: String? {
        errorDescription
    }
}

// MARK: - Equatable (for testing)

extension SecurusError: Equatable {
    public static func == (lhs: SecurusError, rhs: SecurusError) -> Bool {
        switch (lhs, rhs) {
        case (.configurationError(let a), .configurationError(let b)):
            return a == b
        case (.networkError(let a, _), .networkError(let b, _)):
            return a == b
        case (.detectionError(let a, _), .detectionError(let b, _)):
            return a == b
        case (.storageError(let a, let codeA), .storageError(let b, let codeB)):
            return a == b && codeA == codeB
        case (.mlModelError(let a, _), .mlModelError(let b, _)):
            return a == b
        default:
            return false
        }
    }
}
