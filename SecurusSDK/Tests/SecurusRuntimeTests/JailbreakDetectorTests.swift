// ============================================================================
// JailbreakDetectorTests.swift
// SecurusRuntimeTests
//
// Unit tests for JailbreakDetector: individual detection methods,
// overall assessment logic, and confidence scoring.
// ============================================================================

import XCTest
@testable import SecurusRuntime
@testable import SecurusCore

// MARK: - MockFileManager

/// A mock file manager that allows tests to control which file paths
/// "exist" on the system, without touching the actual filesystem.
final class MockFileManager: FileManager {

    /// Set of paths that should be reported as existing.
    var existingPaths: Set<String> = []

    /// Map of path -> attributes for `attributesOfItem(atPath:)`.
    var pathAttributes: [String: [FileAttributeKey: Any]] = [:]

    override func fileExists(atPath path: String) -> Bool {
        existingPaths.contains(path)
    }

    override func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        if let attrs = pathAttributes[path] {
            return attrs
        }
        throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError)
    }
}

// MARK: - JailbreakDetectorTests

final class JailbreakDetectorTests: XCTestCase {

    private var mockFileManager: MockFileManager!
    private var detector: JailbreakDetector!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        mockFileManager = MockFileManager()
        detector = JailbreakDetector(fileManager: mockFileManager)
    }

    override func tearDown() {
        detector = nil
        mockFileManager = nil
        super.tearDown()
    }

    // MARK: - Clean Device (No Jailbreak Indicators)

    func testCleanDeviceReturnsNotJailbroken() {
        // Mock file manager has no existing paths by default
        let result = detector.performCheck()

        XCTAssertFalse(result.isJailbroken,
                       "Clean device should not be detected as jailbroken")
        XCTAssertTrue(result.failedChecks.isEmpty,
                      "No checks should fail on a clean device")
        XCTAssertEqual(result.totalChecks, 6,
                       "All 6 checks should be performed")
    }

    // MARK: - Jailbreak App Paths (Check 1)

    func testDetectsCydiaApp() {
        mockFileManager.existingPaths.insert("/Applications/Cydia.app")

        let detected = detector.checkJailbreakAppPaths()
        XCTAssertTrue(detected, "Should detect Cydia.app")
    }

    func testDetectsSileoApp() {
        mockFileManager.existingPaths.insert("/Applications/Sileo.app")

        let detected = detector.checkJailbreakAppPaths()
        XCTAssertTrue(detected, "Should detect Sileo.app")
    }

    func testDetectsZebraApp() {
        mockFileManager.existingPaths.insert("/Applications/Zebra.app")

        let detected = detector.checkJailbreakAppPaths()
        XCTAssertTrue(detected, "Should detect Zebra.app")
    }

    func testNoJailbreakAppsOnCleanDevice() {
        let detected = detector.checkJailbreakAppPaths()
        XCTAssertFalse(detected, "Should not detect jailbreak apps on clean device")
    }

    // MARK: - Suspicious File Paths (Check 2)

    func testDetectsAptDirectory() {
        mockFileManager.existingPaths.insert("/private/var/lib/apt")

        let detected = detector.checkSuspiciousFilePaths()
        XCTAssertTrue(detected, "Should detect /private/var/lib/apt")
    }

    func testDetectsBashBinary() {
        mockFileManager.existingPaths.insert("/bin/bash")

        let detected = detector.checkSuspiciousFilePaths()
        XCTAssertTrue(detected, "Should detect /bin/bash")
    }

    func testDetectsSSHDaemon() {
        mockFileManager.existingPaths.insert("/usr/sbin/sshd")

        let detected = detector.checkSuspiciousFilePaths()
        XCTAssertTrue(detected, "Should detect /usr/sbin/sshd")
    }

    func testDetectsMobileSubstrate() {
        mockFileManager.existingPaths.insert(
            "/Library/MobileSubstrate/MobileSubstrate.dylib"
        )

        let detected = detector.checkSuspiciousFilePaths()
        XCTAssertTrue(detected, "Should detect MobileSubstrate.dylib")
    }

    func testDetectsFridaServer() {
        mockFileManager.existingPaths.insert("/usr/sbin/frida-server")

        let detected = detector.checkSuspiciousFilePaths()
        XCTAssertTrue(detected, "Should detect frida-server")
    }

    func testNoSuspiciousFilesOnCleanDevice() {
        let detected = detector.checkSuspiciousFilePaths()
        XCTAssertFalse(detected, "Should not detect suspicious files on clean device")
    }

    // MARK: - Sandbox Integrity (Check 3)

    func testSandboxIntegrityOnNonJailbrokenDevice() {
        // On a non-jailbroken test environment, writing to /private/
        // should fail (sandbox enforcement), so this check should
        // return false (sandbox is intact).
        // Note: This test runs in the test host's sandbox.
        let detected = detector.checkSandboxIntegrity()

        // In most CI/test environments, writing to /private/ will fail
        // This is the expected behavior for a non-jailbroken device
        XCTAssertFalse(detected,
                       "Sandbox integrity check should pass on non-jailbroken environment")
    }

    // MARK: - Symbolic Links (Check 5)

    func testDetectsSymbolicLink() {
        // Simulate a symbolic link at /Applications
        mockFileManager.pathAttributes["/Applications"] = [
            .type: FileAttributeType.typeSymbolicLink
        ]

        let detected = detector.checkSymbolicLinks()
        XCTAssertTrue(detected, "Should detect symbolic link at /Applications")
    }

    func testNoSymlinksOnCleanDevice() {
        // No path attributes configured = no symlinks found
        let detected = detector.checkSymbolicLinks()
        XCTAssertFalse(detected, "Should not detect symlinks on clean device")
    }

    // MARK: - Dyld Libraries (Check 6)

    func testDyldCheckReturnsResult() {
        // This test verifies the dyld check runs without crashing.
        // On a test host, no jailbreak dylibs should be loaded.
        let detected = detector.checkDyldLibraries()
        XCTAssertFalse(detected,
                       "No jailbreak dylibs should be loaded in test environment")
    }

    // MARK: - Overall Assessment and Confidence

    func testSingleCheckFailGivesLowConfidence() {
        mockFileManager.existingPaths.insert("/Applications/Cydia.app")

        let result = detector.performCheck()

        XCTAssertTrue(result.isJailbroken, "Device should be detected as jailbroken")
        XCTAssertEqual(result.confidence, .low,
                       "Single check failure should give low confidence")
        XCTAssertTrue(result.failedChecks.contains("jailbreak_app_paths"))
    }

    func testTwoCheckFailsGiveMediumConfidence() {
        mockFileManager.existingPaths.insert("/Applications/Cydia.app")
        mockFileManager.existingPaths.insert("/bin/bash")

        let result = detector.performCheck()

        XCTAssertTrue(result.isJailbroken)
        XCTAssertEqual(result.confidence, .medium,
                       "Two check failures should give medium confidence")
        XCTAssertEqual(result.failedChecks.count, 2)
    }

    func testThreeOrMoreCheckFailsGiveHighConfidence() {
        mockFileManager.existingPaths.insert("/Applications/Cydia.app")
        mockFileManager.existingPaths.insert("/bin/bash")
        mockFileManager.pathAttributes["/Applications"] = [
            .type: FileAttributeType.typeSymbolicLink
        ]

        let result = detector.performCheck()

        XCTAssertTrue(result.isJailbroken)
        XCTAssertEqual(result.confidence, .high,
                       "Three or more check failures should give high confidence")
        XCTAssertGreaterThanOrEqual(result.failedChecks.count, 3)
    }

    // MARK: - Result Structure

    func testResultContainsTotalChecksCount() {
        let result = detector.performCheck()
        XCTAssertEqual(result.totalChecks, 6,
                       "Result should report total number of checks performed")
    }

    func testResultFailedChecksAreNamedCorrectly() {
        mockFileManager.existingPaths.insert("/Applications/Sileo.app")
        mockFileManager.existingPaths.insert("/usr/sbin/sshd")

        let result = detector.performCheck()

        // Verify check names are the expected identifiers
        let validNames = Set([
            "jailbreak_app_paths",
            "suspicious_file_paths",
            "sandbox_integrity",
            "fork_check",
            "symbolic_links",
            "dyld_libraries"
        ])

        for check in result.failedChecks {
            XCTAssertTrue(validNames.contains(check),
                          "Failed check '\(check)' should be a known check name")
        }
    }

    // MARK: - Edge Cases

    func testMultipleJailbreakAppsCountAsOneCheck() {
        // Even if multiple jailbreak apps exist, the app paths check
        // is a single boolean — it either passes or fails as a unit.
        mockFileManager.existingPaths.insert("/Applications/Cydia.app")
        mockFileManager.existingPaths.insert("/Applications/Sileo.app")
        mockFileManager.existingPaths.insert("/Applications/Zebra.app")

        let result = detector.performCheck()

        let appPathCount = result.failedChecks.filter { $0 == "jailbreak_app_paths" }.count
        XCTAssertEqual(appPathCount, 1,
                       "Multiple jailbreak apps should result in a single check failure")
    }
}
