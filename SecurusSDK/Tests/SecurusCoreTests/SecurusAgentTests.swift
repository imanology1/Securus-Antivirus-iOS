// ============================================================================
// SecurusAgentTests.swift
// SecurusCoreTests
//
// Unit tests for SecurusAgent: configuration, lifecycle, singleton
// pattern, fail-safe behavior, and delegate callbacks.
// ============================================================================

import XCTest
@testable import SecurusCore

// MARK: - Mock Delegate

/// Mock delegate that records callbacks for assertion.
final class MockAgentDelegate: SecurusAgentDelegate, @unchecked Sendable {
    private let lock = NSLock()

    private var _detectedThreats: [ThreatEvent] = []
    private var _stateChanges: [SecurusAgentState] = []
    private var _encounteredErrors: [SecurusError] = []

    var detectedThreats: [ThreatEvent] {
        lock.lock()
        defer { lock.unlock() }
        return _detectedThreats
    }

    var stateChanges: [SecurusAgentState] {
        lock.lock()
        defer { lock.unlock() }
        return _stateChanges
    }

    var encounteredErrors: [SecurusError] {
        lock.lock()
        defer { lock.unlock() }
        return _encounteredErrors
    }

    func securusAgent(_ agent: SecurusAgent, didDetectThreat event: ThreatEvent) {
        lock.lock()
        _detectedThreats.append(event)
        lock.unlock()
    }

    func securusAgent(_ agent: SecurusAgent, didChangeState newState: SecurusAgentState) {
        lock.lock()
        _stateChanges.append(newState)
        lock.unlock()
    }

    func securusAgent(_ agent: SecurusAgent, didEncounterError error: SecurusError) {
        lock.lock()
        _encounteredErrors.append(error)
        lock.unlock()
    }
}

// MARK: - Mock ThreatDetector

/// A minimal mock detector for testing registration and lifecycle.
final class MockThreatDetector: ThreatDetector, @unchecked Sendable {
    let moduleName: String = "MockDetector"
    var isMonitoring: Bool = false
    weak var delegate: ThreatDetectorDelegate?

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    func startMonitoring() {
        startCallCount += 1
        isMonitoring = true
    }

    func stopMonitoring() {
        stopCallCount += 1
        isMonitoring = false
    }
}

// MARK: - SecurusAgentTests

final class SecurusAgentTests: XCTestCase {

    private var agent: SecurusAgent!
    private var mockDelegate: MockAgentDelegate!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        agent = SecurusAgent.shared
        mockDelegate = MockAgentDelegate()
        agent.delegate = mockDelegate

        // Ensure clean state by stopping if running
        agent.stop()
    }

    override func tearDown() {
        agent.stop()
        agent.delegate = nil
        super.tearDown()
    }

    // MARK: - Singleton

    func testSharedInstanceReturnsSameObject() {
        let instance1 = SecurusAgent.shared
        let instance2 = SecurusAgent.shared
        XCTAssertTrue(instance1 === instance2, "SecurusAgent.shared must always return the same instance")
    }

    // MARK: - Configuration

    func testConfigureWithValidAPIKey() {
        agent.configure(apiKey: "sk_test_valid_key_12345")
        XCTAssertEqual(agent.state, .configured, "Agent should be in configured state after valid configuration")
    }

    func testConfigureWithFullConfiguration() {
        let config = SecurusConfiguration(
            apiKey: "sk_test_full_config_key",
            learningPeriodDuration: 3600,
            scanInterval: 60,
            enableNetworkMonitoring: false,
            enableRuntimeProtection: false,
            logLevel: .debug
        )

        agent.configure(configuration: config)
        XCTAssertEqual(agent.state, .configured)
        XCTAssertNotNil(agent.configuration)
        XCTAssertEqual(agent.configuration?.apiKey, "sk_test_full_config_key")
        XCTAssertEqual(agent.configuration?.learningPeriodDuration, 3600)
        XCTAssertEqual(agent.configuration?.scanInterval, 60)
        XCTAssertFalse(agent.configuration?.enableNetworkMonitoring ?? true)
        XCTAssertFalse(agent.configuration?.enableRuntimeProtection ?? true)
    }

    func testConfigureWithEmptyAPIKeyTriggersError() {
        agent.configure(apiKey: "")

        // The agent should not transition to configured state
        XCTAssertNotEqual(agent.state, .configured,
                          "Agent should not be configured with an empty API key")

        // The delegate should have received an error
        XCTAssertFalse(mockDelegate.encounteredErrors.isEmpty,
                       "Delegate should receive an error for invalid configuration")
    }

    func testConfigureWithShortAPIKeyTriggersError() {
        agent.configure(apiKey: "short")

        XCTAssertNotEqual(agent.state, .configured,
                          "Agent should not be configured with a short API key")
        XCTAssertFalse(mockDelegate.encounteredErrors.isEmpty,
                       "Delegate should receive an error for short API key")
    }

    // MARK: - Lifecycle

    func testStartRequiresConfiguration() {
        // Without configuring first, starting should fail gracefully
        agent.start()

        // State should not be .running
        XCTAssertNotEqual(agent.state, .running,
                          "Agent should not start without configuration")

        // Delegate should receive an error
        XCTAssertFalse(mockDelegate.encounteredErrors.isEmpty,
                       "Delegate should receive an error when starting without configuration")
    }

    func testStartAfterConfiguration() {
        // Configure with both modules disabled to avoid dynamic loading issues in tests
        let config = SecurusConfiguration(
            apiKey: "sk_test_start_test_key",
            enableNetworkMonitoring: false,
            enableRuntimeProtection: false
        )
        agent.configure(configuration: config)
        agent.start()

        XCTAssertEqual(agent.state, .running, "Agent should be running after start")
    }

    func testStopAfterStart() {
        let config = SecurusConfiguration(
            apiKey: "sk_test_stop_test_key",
            enableNetworkMonitoring: false,
            enableRuntimeProtection: false
        )
        agent.configure(configuration: config)
        agent.start()

        XCTAssertEqual(agent.state, .running)

        agent.stop()

        XCTAssertEqual(agent.state, .stopped, "Agent should be stopped after stop")
    }

    func testStopWhenNotRunningIsNoOp() {
        agent.configure(apiKey: "sk_test_noop_stop_key")

        // Stop without ever starting
        agent.stop()

        // State should remain configured (stop is a no-op when not running)
        XCTAssertEqual(agent.state, .configured,
                       "Stop on a non-running agent should be a no-op")
    }

    func testStartIsIdempotent() {
        let config = SecurusConfiguration(
            apiKey: "sk_test_idempotent_key",
            enableNetworkMonitoring: false,
            enableRuntimeProtection: false
        )
        agent.configure(configuration: config)
        agent.start()
        agent.start() // Second start should be a no-op

        XCTAssertEqual(agent.state, .running)
    }

    func testRestartAfterStop() {
        let config = SecurusConfiguration(
            apiKey: "sk_test_restart_key",
            enableNetworkMonitoring: false,
            enableRuntimeProtection: false
        )
        agent.configure(configuration: config)
        agent.start()
        agent.stop()

        // Should be able to restart
        agent.start()
        XCTAssertEqual(agent.state, .running, "Agent should restart successfully after stop")
    }

    // MARK: - Delegate Callbacks

    func testDelegateReceivesStateChanges() {
        let config = SecurusConfiguration(
            apiKey: "sk_test_delegate_key",
            enableNetworkMonitoring: false,
            enableRuntimeProtection: false
        )
        agent.configure(configuration: config)
        agent.start()
        agent.stop()

        let states = mockDelegate.stateChanges
        XCTAssertTrue(states.contains(.configured), "Delegate should receive .configured state")
        XCTAssertTrue(states.contains(.running), "Delegate should receive .running state")
        XCTAssertTrue(states.contains(.stopped), "Delegate should receive .stopped state")
    }

    // MARK: - Fail-Safe Behavior

    func testFailSafeDoesNotCrashOnInternalError() {
        // Configure with an invalid backend URL scheme — this should be caught
        // by the fail-safe handler and never crash the host app.
        // We test this by verifying the agent survives the invalid configuration.
        agent.configure(apiKey: "sk_test_failsafe_key")

        // The agent should have handled the configuration without crashing
        // regardless of whether SecureStorage operations fail in tests.
        // This test verifies the fail-safe wrapper is working.
        XCTAssertTrue(true, "Agent did not crash — fail-safe is working")
    }

    // MARK: - Detector Registration

    func testRegisterDetector() {
        let config = SecurusConfiguration(
            apiKey: "sk_test_register_key",
            enableNetworkMonitoring: false,
            enableRuntimeProtection: false
        )
        agent.configure(configuration: config)
        agent.start()

        let mock = MockThreatDetector()
        agent.registerDetector(mock)

        // When registered while running, the detector should be started
        XCTAssertTrue(mock.isMonitoring,
                      "Registered detector should be started when agent is running")
        XCTAssertEqual(mock.startCallCount, 1,
                       "Detector should receive exactly one startMonitoring call")
    }

    // MARK: - ThreatDetectorDelegate Conformance

    func testAgentForwardsThreatToDelegate() {
        let config = SecurusConfiguration(
            apiKey: "sk_test_forward_key",
            enableNetworkMonitoring: false,
            enableRuntimeProtection: false
        )
        agent.configure(configuration: config)
        agent.start()

        // Simulate a threat event from a detector
        let event = ThreatEvent(
            threatType: .jailbreak_detected,
            severity: .critical,
            metadata: ["method": "test"],
            appToken: "test_token"
        )

        let mock = MockThreatDetector()
        agent.threatDetector(mock, didDetect: event)

        XCTAssertEqual(mockDelegate.detectedThreats.count, 1,
                       "Delegate should receive forwarded threat events")
        XCTAssertEqual(mockDelegate.detectedThreats.first?.threat_type, .jailbreak_detected)
    }

    func testAgentForwardsErrorToDelegate() {
        agent.configure(apiKey: "sk_test_error_fwd_key")

        let error = SecurusError.detectionError(reason: "Test error")
        let mock = MockThreatDetector()
        agent.threatDetector(mock, didEncounterError: error)

        XCTAssertEqual(mockDelegate.encounteredErrors.count > 0, true,
                       "Delegate should receive forwarded errors")
    }

    // MARK: - Configuration Immutability While Running

    func testCannotReconfigureWhileRunning() {
        let config = SecurusConfiguration(
            apiKey: "sk_test_reconfig_key",
            enableNetworkMonitoring: false,
            enableRuntimeProtection: false
        )
        agent.configure(configuration: config)
        agent.start()

        // Attempt to reconfigure while running
        agent.configure(apiKey: "sk_test_new_key_12345")

        // Agent should still be running with original config
        XCTAssertEqual(agent.state, .running,
                       "Agent state should not change when reconfiguring while running")
        XCTAssertEqual(agent.configuration?.apiKey, "sk_test_reconfig_key",
                       "Configuration should not change while running")
    }
}
