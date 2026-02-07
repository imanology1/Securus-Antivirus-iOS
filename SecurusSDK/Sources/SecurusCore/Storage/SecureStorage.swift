// ============================================================================
// SecureStorage.swift
// SecurusCore
//
// Keychain-backed persistent storage for sensitive SDK data: API keys,
// learned network baselines, anonymous tokens. Uses the iOS Keychain
// Services API directly (no third-party wrappers).
// ============================================================================

import Foundation
import Security

// MARK: - SecureStorage

/// Thread-safe Keychain wrapper for the Securus SDK.
///
/// All data is stored under the `com.securus.sdk` access group with
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` protection, which
/// keeps data available in the background while binding it to the device.
///
/// Usage:
/// ```swift
/// try SecureStorage.shared.store("my_api_key", forKey: "apiKey")
/// let key = try SecureStorage.shared.retrieve(forKey: "apiKey")
/// ```
public final class SecureStorage: @unchecked Sendable {

    // MARK: - Singleton

    /// Shared storage instance.
    public static let shared = SecureStorage()

    // MARK: - Constants

    /// Keychain service identifier scoped to the SDK.
    private let service = "com.securus.sdk.storage"

    /// Serial queue for thread-safe Keychain access.
    private let queue = DispatchQueue(label: "com.securus.secureStorage")

    /// Logger
    private let logger = SecurusLogger.shared

    // MARK: - Init

    private init() {}

    // MARK: - Store

    /// Stores a string value in the Keychain.
    ///
    /// If an entry with the same key already exists it is updated in place.
    ///
    /// - Parameters:
    ///   - value: The UTF-8 string to store.
    ///   - key: A unique key identifying the entry.
    /// - Throws: `SecurusError.storageError` if the Keychain operation fails.
    public func store(_ value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw SecurusError.storageError(reason: "Failed to encode value as UTF-8 for key: \(key)")
        }
        try storeData(data, forKey: key)
    }

    /// Stores raw data in the Keychain.
    ///
    /// - Parameters:
    ///   - data: The data to store.
    ///   - key: A unique key identifying the entry.
    /// - Throws: `SecurusError.storageError` if the Keychain operation fails.
    public func storeData(_ data: Data, forKey key: String) throws {
        try queue.sync {
            let query: [String: Any] = [
                kSecClass as String:            kSecClassGenericPassword,
                kSecAttrService as String:      service,
                kSecAttrAccount as String:      key,
                kSecValueData as String:        data,
                kSecAttrAccessible as String:   kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ]

            // Attempt to add; if duplicate, update instead
            var status = SecItemAdd(query as CFDictionary, nil)

            if status == errSecDuplicateItem {
                let searchQuery: [String: Any] = [
                    kSecClass as String:       kSecClassGenericPassword,
                    kSecAttrService as String:  service,
                    kSecAttrAccount as String:  key
                ]
                let updateAttributes: [String: Any] = [
                    kSecValueData as String: data
                ]
                status = SecItemUpdate(searchQuery as CFDictionary,
                                       updateAttributes as CFDictionary)
            }

            guard status == errSecSuccess else {
                logger.error("Keychain store failed for key '\(key)' with status \(status)",
                             subsystem: "Storage")
                throw SecurusError.storageError(
                    reason: "Failed to store value for key: \(key)",
                    statusCode: status
                )
            }

            logger.debug("Stored value for key '\(key)'", subsystem: "Storage")
        }
    }

    // MARK: - Retrieve

    /// Retrieves a string value from the Keychain.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The stored UTF-8 string, or `nil` if no entry exists.
    /// - Throws: `SecurusError.storageError` on Keychain failure (other than "not found").
    public func retrieve(forKey key: String) throws -> String? {
        guard let data = try retrieveData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Retrieves raw data from the Keychain.
    ///
    /// - Parameter key: The key to look up.
    /// - Returns: The stored data, or `nil` if no entry exists.
    /// - Throws: `SecurusError.storageError` on Keychain failure (other than "not found").
    public func retrieveData(forKey key: String) throws -> Data? {
        try queue.sync {
            let query: [String: Any] = [
                kSecClass as String:       kSecClassGenericPassword,
                kSecAttrService as String:  service,
                kSecAttrAccount as String:  key,
                kSecReturnData as String:   true,
                kSecMatchLimit as String:   kSecMatchLimitOne
            ]

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)

            if status == errSecItemNotFound {
                return nil
            }

            guard status == errSecSuccess, let data = result as? Data else {
                logger.error("Keychain retrieve failed for key '\(key)' with status \(status)",
                             subsystem: "Storage")
                throw SecurusError.storageError(
                    reason: "Failed to retrieve value for key: \(key)",
                    statusCode: status
                )
            }

            return data
        }
    }

    // MARK: - Delete

    /// Deletes an entry from the Keychain.
    ///
    /// - Parameter key: The key to delete.
    /// - Throws: `SecurusError.storageError` if the deletion fails (not-found is not an error).
    public func delete(forKey key: String) throws {
        try queue.sync {
            let query: [String: Any] = [
                kSecClass as String:       kSecClassGenericPassword,
                kSecAttrService as String:  service,
                kSecAttrAccount as String:  key
            ]

            let status = SecItemDelete(query as CFDictionary)

            guard status == errSecSuccess || status == errSecItemNotFound else {
                logger.error("Keychain delete failed for key '\(key)' with status \(status)",
                             subsystem: "Storage")
                throw SecurusError.storageError(
                    reason: "Failed to delete value for key: \(key)",
                    statusCode: status
                )
            }

            logger.debug("Deleted value for key '\(key)'", subsystem: "Storage")
        }
    }

    // MARK: - Existence Check

    /// Returns whether an entry exists for the given key.
    ///
    /// - Parameter key: The key to check.
    /// - Returns: `true` if a value is stored under the key.
    public func exists(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String:  service,
            kSecAttrAccount as String:  key,
            kSecReturnData as String:   false
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Clear All

    /// Removes all Securus SDK entries from the Keychain.
    ///
    /// Use with caution. This is primarily intended for testing and
    /// SDK reset flows.
    public func clearAll() throws {
        try queue.sync {
            let query: [String: Any] = [
                kSecClass as String:       kSecClassGenericPassword,
                kSecAttrService as String:  service
            ]
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw SecurusError.storageError(
                    reason: "Failed to clear all Keychain entries",
                    statusCode: status
                )
            }
            logger.info("All Keychain entries cleared", subsystem: "Storage")
        }
    }

    // MARK: - Codable Convenience

    /// Stores a `Codable` value in the Keychain as JSON.
    ///
    /// - Parameters:
    ///   - value: The `Codable` value to encode and store.
    ///   - key: The Keychain key.
    /// - Throws: `SecurusError.storageError` on encoding or Keychain failure.
    public func storeCodable<T: Codable>(_ value: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(value)
        try storeData(data, forKey: key)
    }

    /// Retrieves and decodes a `Codable` value from the Keychain.
    ///
    /// - Parameters:
    ///   - type: The type to decode.
    ///   - key: The Keychain key.
    /// - Returns: The decoded value, or `nil` if not found.
    /// - Throws: `SecurusError.storageError` on decoding or Keychain failure.
    public func retrieveCodable<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = try retrieveData(forKey: key) else { return nil }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
