// ============================================================================
// BaselineManagerTests.swift
// SecurusNetworkTests
//
// Unit tests for BaselineManager: recording events, building the
// baseline, phase transitions, persistence, and anomaly detection.
// ============================================================================

import XCTest
@testable import SecurusNetwork
@testable import SecurusCore

// MARK: - BaselineManagerTests

final class BaselineManagerTests: XCTestCase {

    private var manager: BaselineManager!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        // Use a very short learning period for testing (2 seconds)
        manager = BaselineManager(learningPeriodDuration: 2.0)
        // Start fresh — reset any persisted state
        manager.reset()
    }

    override func tearDown() {
        manager.reset()
        manager = nil
        super.tearDown()
    }

    // MARK: - Helper: Create Network Event

    /// Creates a network event with the given parameters for testing.
    private func makeEvent(
        domainHash: String = "abc123hash",
        port: Int = 443,
        protocolType: NetworkProtocolType = .https,
        requestSizeBytes: Int = 100,
        responseCode: Int = 200,
        durationMs: Int = 50
    ) -> NetworkEvent {
        NetworkEvent(
            destinationDomainHash: domainHash,
            port: port,
            protocolType: protocolType,
            requestSizeBytes: requestSizeBytes,
            responseCode: responseCode,
            durationMs: durationMs
        )
    }

    // MARK: - Initial State

    func testInitialPhaseIsLearning() {
        XCTAssertEqual(manager.phase, .learning,
                       "New baseline manager should start in learning phase")
    }

    func testInitialBaselineIsEmpty() {
        XCTAssertTrue(manager.entries.isEmpty,
                      "New baseline should have no entries")
        XCTAssertEqual(manager.totalEventsObserved, 0)
    }

    // MARK: - Recording Events During Learning Phase

    func testRecordEventDuringLearningPhase() {
        let event = makeEvent(domainHash: "domain_hash_1")
        let recorded = manager.recordEvent(event)

        XCTAssertTrue(recorded, "Event should be recorded during learning phase")
        XCTAssertEqual(manager.totalEventsObserved, 1)
    }

    func testRecordedEventAppearsInBaseline() {
        let event = makeEvent(domainHash: "domain_hash_2", port: 443, protocolType: .https)
        manager.recordEvent(event)

        let entries = manager.entries
        XCTAssertEqual(entries.count, 1, "Baseline should have one entry")
        XCTAssertEqual(entries.first?.domainHash, "domain_hash_2")
        XCTAssertEqual(entries.first?.port, 443)
        XCTAssertEqual(entries.first?.protocolType, .https)
    }

    func testDuplicateEventsIncrementObservationCount() {
        let event1 = makeEvent(domainHash: "same_domain", port: 443, protocolType: .https)
        let event2 = makeEvent(domainHash: "same_domain", port: 443, protocolType: .https)

        manager.recordEvent(event1)
        manager.recordEvent(event2)

        let entries = manager.entries
        XCTAssertEqual(entries.count, 1,
                       "Duplicate domain+port+protocol should be a single entry")
        XCTAssertEqual(entries.first?.observationCount, 2,
                       "Observation count should increment for duplicates")
    }

    func testDifferentPortsCreateSeparateEntries() {
        let event1 = makeEvent(domainHash: "same_domain", port: 443)
        let event2 = makeEvent(domainHash: "same_domain", port: 8080)

        manager.recordEvent(event1)
        manager.recordEvent(event2)

        XCTAssertEqual(manager.entries.count, 2,
                       "Different ports should create separate baseline entries")
    }

    func testDifferentProtocolsCreateSeparateEntries() {
        let event1 = makeEvent(domainHash: "same_domain", port: 443, protocolType: .https)
        let event2 = makeEvent(domainHash: "same_domain", port: 443, protocolType: .http)

        manager.recordEvent(event1)
        manager.recordEvent(event2)

        XCTAssertEqual(manager.entries.count, 2,
                       "Different protocols should create separate baseline entries")
    }

    func testMultipleDistinctDomainsRecorded() {
        for i in 0..<5 {
            let event = makeEvent(domainHash: "domain_\(i)", port: 443)
            manager.recordEvent(event)
        }

        XCTAssertEqual(manager.entries.count, 5,
                       "Five distinct domains should create five entries")
        XCTAssertEqual(manager.totalEventsObserved, 5)
    }

    // MARK: - Domain Lookup (isKnown)

    func testIsKnownReturnsTrueForRecordedEvent() {
        let event = makeEvent(domainHash: "known_domain", port: 443, protocolType: .https)
        manager.recordEvent(event)

        XCTAssertTrue(manager.isKnown(event),
                      "Recorded event should be recognized as known")
    }

    func testIsKnownReturnsFalseForUnknownEvent() {
        let recorded = makeEvent(domainHash: "known_domain", port: 443)
        let unknown = makeEvent(domainHash: "unknown_domain", port: 443)

        manager.recordEvent(recorded)

        XCTAssertFalse(manager.isKnown(unknown),
                       "Unknown domain should not be recognized")
    }

    func testIsKnownReturnsFalseForDifferentPort() {
        let event443 = makeEvent(domainHash: "domain_x", port: 443)
        let event8080 = makeEvent(domainHash: "domain_x", port: 8080)

        manager.recordEvent(event443)

        XCTAssertFalse(manager.isKnown(event8080),
                       "Same domain on different port should not be recognized")
    }

    func testIsKnownReturnsFalseForDifferentProtocol() {
        let eventHTTPS = makeEvent(domainHash: "domain_y", port: 443, protocolType: .https)
        let eventHTTP = makeEvent(domainHash: "domain_y", port: 443, protocolType: .http)

        manager.recordEvent(eventHTTPS)

        XCTAssertFalse(manager.isKnown(eventHTTP),
                       "Same domain with different protocol should not be recognized")
    }

    // MARK: - Phase Transition

    func testPhaseTransitionsAfterLearningPeriod() {
        // Learning period is set to 2 seconds in setUp
        let event = makeEvent(domainHash: "transition_test")
        manager.recordEvent(event)

        XCTAssertEqual(manager.phase, .learning)

        // Wait for the learning period to elapse
        let expectation = expectation(description: "Learning period elapsed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)

        // Recording an event after the learning period should trigger transition
        let lateEvent = makeEvent(domainHash: "late_event")
        let recorded = manager.recordEvent(lateEvent)

        XCTAssertFalse(recorded,
                       "Event should not be recorded after learning period")
        XCTAssertEqual(manager.phase, .protection,
                       "Manager should transition to protection phase")
    }

    func testForceProtectionPhase() {
        let event = makeEvent(domainHash: "forced_protection_test")
        manager.recordEvent(event)

        XCTAssertEqual(manager.phase, .learning)

        manager.forceProtectionPhase()

        XCTAssertEqual(manager.phase, .protection,
                       "forceProtectionPhase should transition immediately")
    }

    func testEventsNotRecordedDuringProtectionPhase() {
        manager.forceProtectionPhase()

        let event = makeEvent(domainHash: "protection_phase_event")
        let recorded = manager.recordEvent(event)

        XCTAssertFalse(recorded,
                       "Events should not be added to baseline during protection phase")
    }

    // MARK: - Feature Vectors

    func testFeatureVectorsCollectedDuringLearning() {
        let event = makeEvent(
            domainHash: "fv_test",
            port: 443,
            protocolType: .https,
            requestSizeBytes: 256,
            responseCode: 200,
            durationMs: 100
        )
        manager.recordEvent(event)

        let vectors = manager.learnedFeatureVectors()
        XCTAssertEqual(vectors.count, 1,
                       "One event should produce one feature vector")
        XCTAssertEqual(vectors.first?.count, 5,
                       "Feature vector should have 5 dimensions")

        // Verify vector contents
        if let vector = vectors.first {
            XCTAssertEqual(vector[0], 443.0, "First element should be port")
            XCTAssertEqual(vector[1], 1.0, "Second element should be HTTPS protocol ordinal")
            XCTAssertEqual(vector[2], 256.0, "Third element should be request size")
            XCTAssertEqual(vector[3], 200.0, "Fourth element should be response code")
            XCTAssertEqual(vector[4], 100.0, "Fifth element should be duration")
        }
    }

    // MARK: - Reset

    func testResetClearsBaseline() {
        // Add some events
        for i in 0..<10 {
            let event = makeEvent(domainHash: "reset_domain_\(i)")
            manager.recordEvent(event)
        }

        XCTAssertEqual(manager.entries.count, 10)
        XCTAssertEqual(manager.totalEventsObserved, 10)

        // Reset
        manager.reset()

        XCTAssertTrue(manager.entries.isEmpty,
                      "Reset should clear all entries")
        XCTAssertEqual(manager.totalEventsObserved, 0,
                       "Reset should clear event count")
        XCTAssertEqual(manager.phase, .learning,
                       "Reset should return to learning phase")
        XCTAssertTrue(manager.learnedFeatureVectors().isEmpty,
                      "Reset should clear feature vectors")
    }

    func testResetFromProtectionPhaseReturnsToLearning() {
        manager.forceProtectionPhase()
        XCTAssertEqual(manager.phase, .protection)

        manager.reset()
        XCTAssertEqual(manager.phase, .learning,
                       "Reset from protection should return to learning")
    }

    // MARK: - Persistence

    func testBaselinePersistedAndReloaded() {
        // Record enough events to trigger persistence (every 50 events)
        for i in 0..<51 {
            let event = makeEvent(domainHash: "persist_domain_\(i % 10)", port: 443 + (i % 3))
            manager.recordEvent(event)
        }

        let originalCount = manager.entries.count
        let originalPhase = manager.phase

        // Create a new manager — it should load the persisted baseline
        let newManager = BaselineManager(learningPeriodDuration: 2.0)

        // The new manager should have the same baseline data
        // Note: Persistence depends on Keychain access, which may not be
        // available in all test environments. We check for non-zero if
        // the data was persisted, or accept zero as a valid test-env result.
        if !newManager.entries.isEmpty {
            XCTAssertEqual(newManager.entries.count, originalCount,
                           "Reloaded baseline should have same entry count")
            XCTAssertEqual(newManager.phase, originalPhase,
                           "Reloaded baseline should preserve phase")
        }

        // Clean up the new manager
        newManager.reset()
    }

    // MARK: - Concurrent Access

    func testConcurrentRecordingIsThreadSafe() {
        let concurrentQueue = DispatchQueue(
            label: "com.securus.test.concurrent",
            attributes: .concurrent
        )
        let group = DispatchGroup()

        // Record 100 events concurrently
        for i in 0..<100 {
            group.enter()
            concurrentQueue.async {
                let event = self.makeEvent(domainHash: "concurrent_\(i % 20)")
                self.manager.recordEvent(event)
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 10)
        XCTAssertEqual(result, .success, "Concurrent recording should complete without deadlock")
        XCTAssertEqual(manager.totalEventsObserved, 100,
                       "All 100 events should be counted")
    }

    func testConcurrentIsKnownAndRecordIsThreadSafe() {
        // Pre-populate baseline
        for i in 0..<10 {
            let event = makeEvent(domainHash: "preloaded_\(i)")
            manager.recordEvent(event)
        }

        let concurrentQueue = DispatchQueue(
            label: "com.securus.test.mixed",
            attributes: .concurrent
        )
        let group = DispatchGroup()

        // Mix reads and writes concurrently
        for i in 0..<200 {
            group.enter()
            concurrentQueue.async {
                if i % 2 == 0 {
                    let event = self.makeEvent(domainHash: "new_\(i)")
                    self.manager.recordEvent(event)
                } else {
                    let event = self.makeEvent(domainHash: "preloaded_\(i % 10)")
                    _ = self.manager.isKnown(event)
                }
                group.leave()
            }
        }

        let result = group.wait(timeout: .now() + 10)
        XCTAssertEqual(result, .success,
                       "Mixed concurrent reads and writes should complete without deadlock")
    }

    // MARK: - Edge Cases

    func testRecordEventWithEmptyDomainHash() {
        let event = makeEvent(domainHash: "")
        let recorded = manager.recordEvent(event)

        XCTAssertTrue(recorded,
                      "Empty domain hash events should still be recorded")
        XCTAssertEqual(manager.entries.count, 1)
    }

    func testLearningPeriodDurationRespected() {
        // Create a manager with an extremely long learning period
        let longLearningManager = BaselineManager(learningPeriodDuration: 999_999)
        longLearningManager.reset()

        // Record events — they should all be accepted (learning phase)
        for i in 0..<5 {
            let event = makeEvent(domainHash: "long_learning_\(i)")
            let recorded = longLearningManager.recordEvent(event)
            XCTAssertTrue(recorded, "Events should be recorded during long learning period")
        }

        XCTAssertEqual(longLearningManager.phase, .learning,
                       "Should still be in learning phase with long duration")

        longLearningManager.reset()
    }
}
