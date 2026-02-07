// ============================================================================
// HashGenerator.swift
// SecurusCore
//
// SHA-256 utility for anonymizing IPs, domains, and other sensitive
// identifiers before they leave the device. Part of the Privacy by
// Design architecture.
// ============================================================================

import Foundation
import CryptoKit

// MARK: - HashGenerator

/// A stateless utility that produces SHA-256 hashes of arbitrary strings.
///
/// Used throughout the SDK to anonymize potentially identifying data
/// (IP addresses, domain names, file paths) before inclusion in threat
/// reports. The hash is one-way; the original value cannot be recovered.
///
/// All methods are thread-safe and allocation-minimal.
public struct HashGenerator: Sendable {

    // MARK: - Shared Instance

    /// Convenience shared instance. Because the type is stateless, you can
    /// also instantiate it directly.
    public static let shared = HashGenerator()

    // MARK: - Init

    public init() {}

    // MARK: - Hashing API

    /// Hashes an arbitrary string using SHA-256.
    ///
    /// - Parameter input: The raw string to hash (e.g. an IP address).
    /// - Returns: A lowercase hex-encoded SHA-256 digest (64 characters).
    public func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Hashes raw data using SHA-256.
    ///
    /// - Parameter data: The data to hash.
    /// - Returns: A lowercase hex-encoded SHA-256 digest (64 characters).
    public func sha256(data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Domain Hashing

    /// Hashes a domain name for safe inclusion in threat reports.
    ///
    /// The domain is normalized to lowercase before hashing to ensure
    /// consistent results regardless of the original casing.
    ///
    /// - Parameter domain: A domain name (e.g. "api.example.com").
    /// - Returns: A hex-encoded SHA-256 hash.
    public func hashDomain(_ domain: String) -> String {
        sha256(domain.lowercased())
    }

    // MARK: - IP Hashing

    /// Hashes an IP address for safe inclusion in threat reports.
    ///
    /// - Parameter ip: An IPv4 or IPv6 address string.
    /// - Returns: A hex-encoded SHA-256 hash.
    public func hashIP(_ ip: String) -> String {
        sha256(ip)
    }

    // MARK: - URL Hashing

    /// Hashes a URL, stripping query parameters and fragments first.
    ///
    /// Only the scheme + host + path are hashed, so that unique query
    /// strings do not produce unique hashes (which could be used for
    /// fingerprinting).
    ///
    /// - Parameter url: The URL to hash.
    /// - Returns: A hex-encoded SHA-256 hash of the normalized URL.
    public func hashURL(_ url: URL) -> String {
        var components = URLComponents()
        components.scheme = url.scheme
        components.host = url.host?.lowercased()
        components.path = url.path
        let normalized = components.string ?? url.absoluteString
        return sha256(normalized)
    }

    // MARK: - Path Hashing

    /// Hashes a file path for safe inclusion in reports.
    ///
    /// - Parameter path: An absolute or relative file path.
    /// - Returns: A hex-encoded SHA-256 hash.
    public func hashPath(_ path: String) -> String {
        sha256(path)
    }

    // MARK: - HMAC

    /// Computes an HMAC-SHA256 for message authentication.
    ///
    /// - Parameters:
    ///   - message: The message to authenticate.
    ///   - key: The symmetric key (as raw bytes).
    /// - Returns: A hex-encoded HMAC-SHA256.
    public func hmacSHA256(message: String, key: Data) -> String {
        let symmetricKey = SymmetricKey(data: key)
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(message.utf8),
            using: symmetricKey
        )
        return Data(signature).map { String(format: "%02x", $0) }.joined()
    }
}
