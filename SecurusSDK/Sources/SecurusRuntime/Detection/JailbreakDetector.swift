// ============================================================================
// JailbreakDetector.swift
// SecurusRuntime
//
// Multi-layered jailbreak detection using redundant checks.
// Each check targets a different jailbreak indicator so that
// bypassing any single check does not defeat the detector.
// ============================================================================

import Foundation
import SecurusCore

#if canImport(Darwin)
import Darwin
#endif

#if canImport(MachO)
import MachO
#endif

// MARK: - JailbreakConfidence

/// Confidence level of the jailbreak assessment.
public enum JailbreakConfidence: String, Sendable {
    /// Multiple independent checks confirmed jailbreak indicators.
    case high
    /// Some checks detected indicators but others did not.
    case medium
    /// A single, low-signal check detected an indicator.
    case low
}

// MARK: - JailbreakResult

/// The aggregate result of all jailbreak detection checks.
public struct JailbreakResult: Sendable {
    /// Whether the device is considered jailbroken.
    public let isJailbroken: Bool
    /// Confidence level of the assessment.
    public let confidence: JailbreakConfidence
    /// Human-readable names of the checks that detected jailbreak indicators.
    public let failedChecks: [String]
    /// Total number of checks performed.
    public let totalChecks: Int

    public init(
        isJailbroken: Bool,
        confidence: JailbreakConfidence,
        failedChecks: [String],
        totalChecks: Int
    ) {
        self.isJailbroken = isJailbroken
        self.confidence = confidence
        self.failedChecks = failedChecks
        self.totalChecks = totalChecks
    }
}

// MARK: - JailbreakDetector

/// Performs multiple redundant jailbreak detection checks.
///
/// ## Detection Layers
///
/// 1. **Known App Paths**: Checks for the presence of popular jailbreak
///    package managers (Cydia, Sileo, Zebra) at their default install
///    locations.
///
/// 2. **Suspicious File Paths**: Probes for files and directories that
///    only exist on jailbroken devices (apt, bash, sshd, etc.).
///
/// 3. **Sandbox Integrity**: Attempts to write a file outside the app's
///    sandbox (to `/private/`). On a non-jailbroken device this always
///    fails due to sandbox enforcement.
///
/// 4. **Fork Check**: Calls `fork()`, which is blocked by the sandbox
///    on non-jailbroken devices. A successful fork indicates the
///    sandbox has been compromised.
///
/// 5. **Symbolic Link Check**: Inspects system directories for symbolic
///    links that jailbreak tools commonly create.
///
/// 6. **Dyld Library Check**: Enumerates loaded dynamic libraries via
///    `_dyld_image_count()` and flags known jailbreak-related dylibs.
///
/// ## Confidence Scoring
///
/// - 3 or more checks fail -> `high` confidence
/// - 2 checks fail -> `medium` confidence
/// - 1 check fails -> `low` confidence
/// - 0 checks fail -> not jailbroken
///
/// ## Thread Safety
///
/// All methods are stateless and safe to call from any thread.
public final class JailbreakDetector: Sendable {

    // MARK: - Constants

    /// Known jailbreak app installation paths.
    private static let jailbreakAppPaths: [String] = [
        "/Applications/Cydia.app",
        "/Applications/Sileo.app",
        "/Applications/Zebra.app",
        "/Applications/Installer.app",
        "/Applications/Unc0ver.app",
        "/Applications/checkra1n.app",
        "/Applications/FlyJB.app",
        "/Applications/Substitute.app"
    ]

    /// Suspicious file paths that indicate a jailbroken environment.
    private static let suspiciousFilePaths: [String] = [
        "/private/var/lib/apt",
        "/private/var/lib/cydia",
        "/private/var/stash",
        "/private/var/mobile/Library/SBSettings/Themes",
        "/bin/bash",
        "/bin/sh",
        "/usr/sbin/sshd",
        "/usr/bin/sshd",
        "/usr/libexec/sftp-server",
        "/usr/bin/ssh",
        "/etc/apt",
        "/etc/ssh/sshd_config",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/Library/MobileSubstrate/DynamicLibraries",
        "/var/cache/apt",
        "/var/lib/apt",
        "/var/lib/cydia",
        "/usr/sbin/frida-server",
        "/usr/bin/cycript",
        "/usr/local/bin/cycript",
        "/usr/lib/libcycript.dylib",
        "/var/log/syslog",
        "/private/var/tmp/cydia.log",
        "/usr/libexec/ssh-keysign",
        "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
        "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
        "/private/etc/dpkg/origins/debian"
    ]

    /// System directory paths to check for suspicious symbolic links.
    private static let symlinkPaths: [String] = [
        "/var/lib/undecimus/apt",
        "/Applications",
        "/Library/Ringtones",
        "/Library/Wallpaper",
        "/usr/arm-apple-darwin9",
        "/usr/include",
        "/usr/libexec",
        "/usr/share"
    ]

    /// Substrings that identify known jailbreak-related dynamic libraries.
    private static let suspiciousDylibSubstrings: [String] = [
        "MobileSubstrate",
        "CydiaSubstrate",
        "SubstrateLoader",
        "SubstrateInserter",
        "TweakInject",
        "libhooker",
        "substitute",
        "Choicy",
        "Shadow",
        "FlyJB",
        "Liberty",
        "frida",
        "cycript",
        "SSLKillSwitch"
    ]

    // MARK: - Private Properties

    private let logger = SecurusLogger.shared
    private let fileManager: FileManager

    // MARK: - Init

    /// Creates a jailbreak detector.
    ///
    /// - Parameter fileManager: The file manager to use. Defaults to `.default`.
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Public API

    /// Performs all jailbreak detection checks and returns an aggregate result.
    ///
    /// - Returns: A `JailbreakResult` summarizing the assessment.
    public func performCheck() -> JailbreakResult {
        var failedChecks: [String] = []
        let totalChecks = 6

        // 1. Known App Paths
        if checkJailbreakAppPaths() {
            failedChecks.append("jailbreak_app_paths")
        }

        // 2. Suspicious File Paths
        if checkSuspiciousFilePaths() {
            failedChecks.append("suspicious_file_paths")
        }

        // 3. Sandbox Integrity
        if checkSandboxIntegrity() {
            failedChecks.append("sandbox_integrity")
        }

        // 4. Fork Check
        if checkForkAvailability() {
            failedChecks.append("fork_check")
        }

        // 5. Symbolic Links
        if checkSymbolicLinks() {
            failedChecks.append("symbolic_links")
        }

        // 6. Dyld Libraries
        if checkDyldLibraries() {
            failedChecks.append("dyld_libraries")
        }

        // Determine confidence
        let confidence: JailbreakConfidence
        switch failedChecks.count {
        case 0:
            confidence = .low
        case 1:
            confidence = .low
        case 2:
            confidence = .medium
        default:
            confidence = .high
        }

        let isJailbroken = !failedChecks.isEmpty

        if isJailbroken {
            logger.warning(
                "Jailbreak detected (\(failedChecks.count)/\(totalChecks) checks failed: "
                + "\(failedChecks.joined(separator: ", "))) "
                + "[confidence: \(confidence.rawValue)]",
                subsystem: "Runtime"
            )
        } else {
            logger.info(
                "Jailbreak check passed (0/\(totalChecks) checks failed)",
                subsystem: "Runtime"
            )
        }

        return JailbreakResult(
            isJailbroken: isJailbroken,
            confidence: confidence,
            failedChecks: failedChecks,
            totalChecks: totalChecks
        )
    }

    // MARK: - Individual Checks

    /// Check 1: Probes for known jailbreak package manager apps.
    ///
    /// - Returns: `true` if any jailbreak app is found.
    public func checkJailbreakAppPaths() -> Bool {
        for path in Self.jailbreakAppPaths {
            if fileManager.fileExists(atPath: path) {
                logger.debug("Jailbreak app found at: \(path)", subsystem: "Runtime")
                return true
            }
        }
        return false
    }

    /// Check 2: Probes for files/directories that only exist on jailbroken devices.
    ///
    /// - Returns: `true` if any suspicious file is found.
    public func checkSuspiciousFilePaths() -> Bool {
        for path in Self.suspiciousFilePaths {
            if fileManager.fileExists(atPath: path) {
                logger.debug("Suspicious file found at: \(path)", subsystem: "Runtime")
                return true
            }
        }
        return false
    }

    /// Check 3: Tests sandbox integrity by attempting to write outside the sandbox.
    ///
    /// On a non-jailbroken device, writing to `/private/jailbreak_test` is
    /// blocked by the sandbox. If the write succeeds, the sandbox has been
    /// compromised.
    ///
    /// - Returns: `true` if the sandbox appears compromised.
    public func checkSandboxIntegrity() -> Bool {
        let testPath = "/private/securus_jb_test_\(UUID().uuidString)"
        let testData = Data("jailbreak_test".utf8)

        do {
            try testData.write(to: URL(fileURLWithPath: testPath), options: .atomic)
            // If we reach here, the write succeeded — sandbox is broken
            try? fileManager.removeItem(atPath: testPath)
            logger.debug("Sandbox write succeeded — jailbreak indicator", subsystem: "Runtime")
            return true
        } catch {
            // Expected on non-jailbroken devices
            return false
        }
    }

    /// Check 4: Attempts to fork the process.
    ///
    /// On non-jailbroken iOS devices, `fork()` is blocked by the sandbox
    /// and returns -1. If it succeeds (returns >= 0), the sandbox has
    /// been compromised.
    ///
    /// - Returns: `true` if fork succeeds (jailbreak indicator).
    public func checkForkAvailability() -> Bool {
        #if targetEnvironment(simulator)
        // fork() works in the simulator; skip this check
        return false
        #else
        let result = fork()
        if result >= 0 {
            if result == 0 {
                // We are the child process — exit immediately
                _exit(0)
            }
            // Parent: fork succeeded, which should not happen on stock iOS
            logger.debug("fork() succeeded — jailbreak indicator", subsystem: "Runtime")
            return true
        }
        return false
        #endif
    }

    /// Check 5: Inspects system directories for suspicious symbolic links.
    ///
    /// Jailbreak tools often create symbolic links in system directories
    /// to reroute file access. This check identifies those links.
    ///
    /// - Returns: `true` if suspicious symlinks are found.
    public func checkSymbolicLinks() -> Bool {
        for path in Self.symlinkPaths {
            do {
                let attributes = try fileManager.attributesOfItem(atPath: path)
                if let fileType = attributes[.type] as? FileAttributeType,
                   fileType == .typeSymbolicLink {
                    logger.debug("Symbolic link found at: \(path)", subsystem: "Runtime")
                    return true
                }
            } catch {
                // Path doesn't exist or isn't accessible — not a jailbreak indicator
                continue
            }
        }
        return false
    }

    /// Check 6: Enumerates loaded dylibs and flags known jailbreak-related ones.
    ///
    /// Uses the `_dyld_image_count()` and `_dyld_get_image_name()` functions
    /// to inspect all currently loaded dynamic libraries.
    ///
    /// - Returns: `true` if a jailbreak-related dylib is found.
    public func checkDyldLibraries() -> Bool {
        #if canImport(MachO)
        let imageCount = _dyld_image_count()

        for i in 0..<imageCount {
            guard let imageNamePtr = _dyld_get_image_name(i) else { continue }
            let imageName = String(cString: imageNamePtr)

            for suspicious in Self.suspiciousDylibSubstrings {
                if imageName.localizedCaseInsensitiveContains(suspicious) {
                    logger.debug(
                        "Suspicious dylib loaded: \(imageName)",
                        subsystem: "Runtime"
                    )
                    return true
                }
            }
        }
        #endif
        return false
    }
}
