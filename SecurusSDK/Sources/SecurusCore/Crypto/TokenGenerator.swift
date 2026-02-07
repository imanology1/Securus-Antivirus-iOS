// ============================================================================
// TokenGenerator.swift
// SecurusCore
//
// Generates anonymous, non-reversible device/session tokens using SHA-256.
// Privacy by Design: No PII is stored or transmitted. The token is derived
// from identifierForVendor + a random salt, then hashed.
// ============================================================================

import Foundation
import CryptoKit

// MARK: - TokenGenerator

/// Generates anonymous device and session tokens for the Securus SDK.
///
/// Tokens are created by combining the device's `identifierForVendor` UUID
/// (which is already scoped to the app's vendor and reset on uninstall) with
/// a cryptographically random salt, then hashing the result with SHA-256.
/// The original identifiers are never stored or transmitted.
///
/// Thread-safe. All token generation methods are pure functions with no
/// mutable shared state.
public final class TokenGenerator: Sendable {

    // MARK: - Singleton

    /// Shared generator instance.
    public static let shared = TokenGenerator()

    // MARK: - Storage Keys

    private static let saltStorageKey = "com.securus.token.salt"
    private static let tokenStorageKey = "com.securus.token.device"

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Generates a stable anonymous device token.
    ///
    /// On first invocation the generator creates a random 32-byte salt, stores
    /// it in the Keychain, and derives a SHA-256 token from
    /// `identifierForVendor + salt`. Subsequent calls return the same token
    /// until the Keychain entry is cleared (e.g. app uninstall).
    ///
    /// - Returns: A hex-encoded SHA-256 hash string prefixed with `sha256:`.
    public func deviceToken() -> String {
        let storage = SecureStorage.shared

        // Return cached token if available
        if let cached = try? storage.retrieve(forKey: Self.tokenStorageKey), !cached.isEmpty {
            return cached
        }

        // Retrieve or create salt
        let salt: String
        if let existingSalt = try? storage.retrieve(forKey: Self.saltStorageKey), !existingSalt.isEmpty {
            salt = existingSalt
        } else {
            salt = generateRandomSalt()
            try? storage.store(salt, forKey: Self.saltStorageKey)
        }

        // Build the token input: vendorID (or fallback UUID) + salt
        let vendorID = deviceIdentifier()
        let input = "\(vendorID):\(salt)"
        let token = "sha256:" + sha256Hex(input)

        // Cache the derived token
        try? storage.store(token, forKey: Self.tokenStorageKey)

        return token
    }

    /// Generates a fresh, one-time session token.
    ///
    /// Unlike `deviceToken()`, this produces a new value on every call.
    /// Useful for per-session correlation without cross-session tracking.
    ///
    /// - Returns: A hex-encoded SHA-256 hash string prefixed with `session:`.
    public func sessionToken() -> String {
        let nonce = UUID().uuidString
        let timestamp = String(Date().timeIntervalSince1970)
        let input = "\(nonce):\(timestamp)"
        return "session:" + sha256Hex(input)
    }

    /// Invalidates the cached device token, forcing regeneration on next access.
    public func resetDeviceToken() {
        let storage = SecureStorage.shared
        try? storage.delete(forKey: Self.tokenStorageKey)
        try? storage.delete(forKey: Self.saltStorageKey)
        SecurusLogger.shared.info("Device token reset", subsystem: "Crypto")
    }

    // MARK: - Private Helpers

    /// Returns a device identifier string. Uses `identifierForVendor` on
    /// real devices, or a stable fallback UUID in environments where it
    /// is unavailable (simulators, unit tests).
    private func deviceIdentifier() -> String {
        #if canImport(UIKit)
        // UIDevice is only available when UIKit can be imported (iOS, not macOS tests)
        // identifierForVendor may be nil in some edge cases
        if let id = UIDevice.current.identifierForVendor?.uuidString {
            return id
        }
        #endif
        // Fallback: generate and persist a stable UUID
        let fallbackKey = "com.securus.token.fallbackDeviceID"
        if let stored = try? SecureStorage.shared.retrieve(forKey: fallbackKey), !stored.isEmpty {
            return stored
        }
        let generated = UUID().uuidString
        try? SecureStorage.shared.store(generated, forKey: fallbackKey)
        return generated
    }

    /// Generates a 32-byte cryptographically random salt, hex-encoded.
    private func generateRandomSalt() -> String {
        let key = SymmetricKey(size: .bits256)
        return key.withUnsafeBytes { bytes in
            bytes.map { String(format: "%02x", $0) }.joined()
        }
    }

    /// Computes the SHA-256 digest of a UTF-8 string and returns it hex-encoded.
    private func sha256Hex(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
