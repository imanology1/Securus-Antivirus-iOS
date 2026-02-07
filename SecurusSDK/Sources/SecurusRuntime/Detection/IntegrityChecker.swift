// ============================================================================
// IntegrityChecker.swift
// SecurusRuntime
//
// Verifies the integrity of the running application binary, bundle
// metadata, and provisioning profile. Detects re-signing, repackaging,
// and sideloading.
// ============================================================================

import Foundation
import SecurusCore

#if canImport(Security)
import Security
#endif

// MARK: - IntegrityResult

/// The result of an app integrity verification scan.
public struct IntegrityResult: Sendable {
    /// Whether the application appears intact (not tampered with).
    public let isIntact: Bool
    /// Human-readable names of the checks that detected integrity violations.
    public let failedChecks: [String]
    /// Detailed description of what was found.
    public let details: String

    public init(isIntact: Bool, failedChecks: [String], details: String) {
        self.isIntact = isIntact
        self.failedChecks = failedChecks
        self.details = details
    }
}

// MARK: - IntegrityChecker

/// Verifies the integrity of the application binary and bundle.
///
/// ## Verification Checks
///
/// 1. **Provisioning Profile**: Ensures `embedded.mobileprovision` exists
///    in the app bundle. This file is present in all properly signed iOS
///    apps distributed via the App Store or enterprise distribution.
///
/// 2. **Code Signature**: Uses the Security framework's
///    `SecStaticCodeCheckValidity` to verify the app's code signature
///    has not been altered.
///
/// 3. **Bundle ID Verification**: Compares the running app's bundle
///    identifier against an expected value to detect re-signing with
///    a different identity.
///
/// 4. **Execution Location**: Checks whether the app is running from
///    its expected location (the standard iOS app container) rather
///    than a sideloaded or re-signed location.
///
/// ## Thread Safety
///
/// All methods are stateless and safe to call from any thread.
public final class IntegrityChecker: Sendable {

    // MARK: - Configuration

    /// The expected bundle identifier. If set, the checker verifies that
    /// the running app's bundle ID matches. If `nil`, the bundle ID check
    /// is skipped.
    ///
    /// Typically set during SDK configuration.
    public let expectedBundleIdentifier: String?

    // MARK: - Properties

    private let logger = SecurusLogger.shared
    private let fileManager: FileManager

    // MARK: - Init

    /// Creates an integrity checker.
    ///
    /// - Parameters:
    ///   - expectedBundleIdentifier: Optional expected bundle ID for
    ///     re-signing detection. Pass `nil` to skip this check.
    ///   - fileManager: The file manager to use. Defaults to `.default`.
    public init(
        expectedBundleIdentifier: String? = nil,
        fileManager: FileManager = .default
    ) {
        self.expectedBundleIdentifier = expectedBundleIdentifier
        self.fileManager = fileManager
    }

    // MARK: - Public API

    /// Performs all integrity checks and returns an aggregate result.
    ///
    /// - Returns: An `IntegrityResult` summarizing the assessment.
    public func performCheck() -> IntegrityResult {
        var failedChecks: [String] = []
        var detailParts: [String] = []

        // 1. Provisioning profile check
        if !checkProvisioningProfile() {
            failedChecks.append("provisioning_profile")
            detailParts.append("embedded.mobileprovision missing or inaccessible")
        }

        // 2. Code signature check
        if !checkCodeSignature() {
            failedChecks.append("code_signature")
            detailParts.append("Code signature validation failed")
        }

        // 3. Bundle ID verification
        if let expectedID = expectedBundleIdentifier {
            if !checkBundleIdentifier(expected: expectedID) {
                failedChecks.append("bundle_identifier")
                let actual = Bundle.main.bundleIdentifier ?? "<nil>"
                detailParts.append("Bundle ID mismatch: expected '\(expectedID)', got '\(actual)'")
            }
        }

        // 4. Execution location check
        if !checkExecutionLocation() {
            failedChecks.append("execution_location")
            detailParts.append("App running from unexpected location")
        }

        let isIntact = failedChecks.isEmpty
        let details = detailParts.isEmpty ? "All integrity checks passed" : detailParts.joined(separator: "; ")

        if isIntact {
            logger.info("App integrity check passed", subsystem: "Runtime")
        } else {
            logger.warning(
                "App integrity violations: \(failedChecks.joined(separator: ", ")) - \(details)",
                subsystem: "Runtime"
            )
        }

        return IntegrityResult(
            isIntact: isIntact,
            failedChecks: failedChecks,
            details: details
        )
    }

    // MARK: - Individual Checks

    /// Check 1: Verifies that `embedded.mobileprovision` exists in the app bundle.
    ///
    /// All properly distributed iOS apps (App Store, enterprise, TestFlight)
    /// contain this file. Its absence suggests the app has been stripped
    /// and re-signed.
    ///
    /// - Returns: `true` if the provisioning profile is present.
    public func checkProvisioningProfile() -> Bool {
        guard let bundlePath = Bundle.main.bundlePath as String? else {
            return false
        }

        let provisionPath = (bundlePath as NSString)
            .appendingPathComponent("embedded.mobileprovision")

        let exists = fileManager.fileExists(atPath: provisionPath)

        if !exists {
            // On simulator or during development, the profile may not be present.
            // In release builds, absence is a strong indicator of repackaging.
            #if targetEnvironment(simulator)
            logger.debug(
                "embedded.mobileprovision not found (expected on simulator)",
                subsystem: "Runtime"
            )
            return true // Not a meaningful signal on simulator
            #else
            logger.debug(
                "embedded.mobileprovision not found at: \(provisionPath)",
                subsystem: "Runtime"
            )
            #endif
        }

        return exists
    }

    /// Check 2: Validates the app's code signature using the Security framework.
    ///
    /// Uses `SecStaticCodeCheckValidity` to verify that the Mach-O binary
    /// and all bundled resources match the code signature. A failure
    /// indicates the binary has been modified after signing.
    ///
    /// - Returns: `true` if the code signature is valid.
    public func checkCodeSignature() -> Bool {
        #if targetEnvironment(simulator)
        // Code signature checks behave differently on the simulator
        return true
        #else
        guard let executableURL = Bundle.main.executableURL else {
            logger.debug("Could not determine executable URL", subsystem: "Runtime")
            return false
        }

        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(
            executableURL as CFURL,
            SecCSFlags(),
            &staticCode
        )

        guard createStatus == errSecSuccess, let code = staticCode else {
            logger.debug(
                "SecStaticCodeCreateWithPath failed: \(createStatus)",
                subsystem: "Runtime"
            )
            return false
        }

        // Validate the signature against the embedded requirements
        let checkStatus = SecStaticCodeCheckValidity(
            code,
            SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode),
            nil // Use embedded designated requirement
        )

        if checkStatus != errSecSuccess {
            logger.debug(
                "SecStaticCodeCheckValidity failed: \(checkStatus)",
                subsystem: "Runtime"
            )
            return false
        }

        return true
        #endif
    }

    /// Check 3: Compares the running bundle identifier against an expected value.
    ///
    /// When an attacker re-signs an app, they typically use their own
    /// development identity, which changes the bundle identifier. This
    /// check detects that substitution.
    ///
    /// - Parameter expected: The expected bundle identifier.
    /// - Returns: `true` if the bundle identifier matches.
    public func checkBundleIdentifier(expected: String) -> Bool {
        guard let actual = Bundle.main.bundleIdentifier else {
            logger.debug("Bundle identifier is nil", subsystem: "Runtime")
            return false
        }

        let matches = actual == expected
        if !matches {
            logger.debug(
                "Bundle ID mismatch: expected '\(expected)', actual '\(actual)'",
                subsystem: "Runtime"
            )
        }
        return matches
    }

    /// Check 4: Verifies the app is running from an expected iOS container location.
    ///
    /// Properly installed iOS apps run from a path like:
    ///   `/var/containers/Bundle/Application/<UUID>/<AppName>.app`
    ///
    /// Sideloaded or injected apps may run from unusual locations such as
    /// `/private/var/mobile/` or locations associated with third-party
    /// signing services.
    ///
    /// - Returns: `true` if the app is running from an expected location.
    public func checkExecutionLocation() -> Bool {
        #if targetEnvironment(simulator)
        // Simulator paths differ from device paths; skip this check
        return true
        #else
        let bundlePath = Bundle.main.bundlePath

        // Standard iOS app container paths
        let validPrefixes = [
            "/var/containers/Bundle/Application/",
            "/private/var/containers/Bundle/Application/"
        ]

        let isValidLocation = validPrefixes.contains { prefix in
            bundlePath.hasPrefix(prefix)
        }

        if !isValidLocation {
            logger.debug(
                "App running from unexpected location: \(bundlePath)",
                subsystem: "Runtime"
            )
        }

        return isValidLocation
        #endif
    }

    // MARK: - Provisioning Profile Parsing

    /// Extracts key-value information from the embedded provisioning profile.
    ///
    /// The provisioning profile is a CMS-signed plist. This method extracts
    /// the plist payload (without verifying the CMS signature, which is
    /// handled by the code signature check).
    ///
    /// - Returns: A dictionary of provisioning profile fields, or `nil`
    ///   if the profile cannot be read or parsed.
    public func provisioningProfileInfo() -> [String: Any]? {
        guard let bundlePath = Bundle.main.bundlePath as String? else {
            return nil
        }

        let provisionPath = (bundlePath as NSString)
            .appendingPathComponent("embedded.mobileprovision")

        guard let data = fileManager.contents(atPath: provisionPath) else {
            return nil
        }

        // The provisioning profile is a CMS signed message.
        // The plist is embedded between the XML markers.
        guard let dataString = String(data: data, encoding: .ascii) else {
            return nil
        }

        guard let plistStart = dataString.range(of: "<?xml"),
              let plistEnd = dataString.range(of: "</plist>") else {
            return nil
        }

        let plistRange = plistStart.lowerBound..<plistEnd.upperBound
        let plistString = String(dataString[plistRange])

        guard let plistData = plistString.data(using: .utf8) else {
            return nil
        }

        do {
            let plist = try PropertyListSerialization.propertyList(
                from: plistData,
                options: [],
                format: nil
            )
            return plist as? [String: Any]
        } catch {
            logger.debug(
                "Failed to parse provisioning profile plist: \(error.localizedDescription)",
                subsystem: "Runtime"
            )
            return nil
        }
    }
}
