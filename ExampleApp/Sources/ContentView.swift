// ============================================================================
// ContentView.swift
// SecurusExampleApp
//
// Main demo screen for the Securus SDK example app. Displays agent status,
// security dashboard, action buttons, and a real-time threat log.
// ============================================================================

import SwiftUI
import SecurusCore

// MARK: - Theme Colors

extension Color {
    /// Dark background matching the Securus dashboard (#0a0e17).
    static let securusBg = Color(red: 10 / 255, green: 14 / 255, blue: 23 / 255)
    /// Slightly lighter surface for cards (#111827).
    static let securusSurface = Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255)
    /// Accent border color (#1e293b).
    static let securusBorder = Color(red: 30 / 255, green: 41 / 255, blue: 59 / 255)
    /// Soft text color for secondary labels.
    static let securusSecondary = Color(red: 148 / 255, green: 163 / 255, blue: 184 / 255)
    /// Securus brand accent (cyan-ish).
    static let securusAccent = Color(red: 56 / 255, green: 189 / 255, blue: 248 / 255)
}

// MARK: - SecurusViewModel

/// Observable view model that bridges the delegate-based SecurusAgent API
/// to SwiftUI. Receives real-time callbacks for state changes, threat
/// detections, and errors, then publishes them as observable properties.
@Observable
final class SecurusViewModel: @unchecked Sendable {

    // MARK: Published State

    var agentState: SecurusAgentState = .idle
    var threatLog: [ThreatEvent] = []
    var errors: [String] = []
    var startTime: Date?
    var isScanning: Bool = false
    var lastScanDate: Date?
    var networkMonitoringActive: Bool = false
    var runtimeProtectionActive: Bool = false
    var aiEngineLoaded: Bool = false

    // MARK: Init

    init() {
        // Sync initial state from the agent
        agentState = SecurusAgent.shared.state

        // Register as delegate
        SecurusAgent.shared.delegate = self

        // Read feature flags from configuration
        if let config = SecurusAgent.shared.configuration {
            networkMonitoringActive = config.enableNetworkMonitoring
            runtimeProtectionActive = config.enableRuntimeProtection
        }

        // The AI engine always loads (either ML or statistical fallback)
        aiEngineLoaded = true

        if agentState == .running {
            startTime = Date()
        }
    }

    // MARK: - Actions

    /// Simulates running a security scan. In a real integration the SDK
    /// performs scans automatically; this demonstrates the concept.
    func runSecurityScan() {
        guard !isScanning else { return }
        isScanning = true
        lastScanDate = Date()

        // Simulate a brief scan duration, then inject a demo event
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) { [weak self] in
            let sampleEvent = ThreatEvent(
                threatType: .network_anomaly,
                severity: .low,
                metadata: [
                    "method": "demo_scan",
                    "destination_hash": "sha256:a1b2c3d4...",
                    "anomaly_score": "0.32"
                ],
                appToken: "demo_token_\(UUID().uuidString.prefix(8))"
            )

            DispatchQueue.main.async {
                self?.threatLog.insert(sampleEvent, at: 0)
                self?.isScanning = false
            }
        }
    }

    /// Simulates a runtime integrity check.
    func checkRuntimeIntegrity() {
        guard !isScanning else { return }
        isScanning = true

        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            // On the simulator, none of the real checks trigger, so we
            // generate a sample "all clear" or a low-severity event.
            let sampleEvent = ThreatEvent(
                threatType: .debugger_attached,
                severity: .medium,
                metadata: [
                    "method": "ptrace_check",
                    "environment": "simulator"
                ],
                appToken: "demo_token_\(UUID().uuidString.prefix(8))"
            )

            DispatchQueue.main.async {
                self?.threatLog.insert(sampleEvent, at: 0)
                self?.isScanning = false
            }
        }
    }

    /// Clears the local threat log.
    func clearThreatLog() {
        threatLog.removeAll()
    }

    // MARK: - Formatted Uptime

    var formattedUptime: String {
        guard let start = startTime else { return "--:--:--" }
        let interval = Date().timeIntervalSince(start)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - SecurusAgentDelegate

extension SecurusViewModel: SecurusAgentDelegate {

    func securusAgent(_ agent: SecurusAgent, didDetectThreat event: ThreatEvent) {
        DispatchQueue.main.async {
            self.threatLog.insert(event, at: 0)
        }
    }

    func securusAgent(_ agent: SecurusAgent, didChangeState newState: SecurusAgentState) {
        DispatchQueue.main.async {
            self.agentState = newState
            if newState == .running {
                self.startTime = Date()
            }
            if let config = SecurusAgent.shared.configuration {
                self.networkMonitoringActive = config.enableNetworkMonitoring
                self.runtimeProtectionActive = config.enableRuntimeProtection
            }
        }
    }

    func securusAgent(_ agent: SecurusAgent, didEncounterError error: SecurusError) {
        DispatchQueue.main.async {
            self.errors.append(error.errorDescription ?? "Unknown error")
        }
    }
}

// MARK: - ContentView

struct ContentView: View {

    @Environment(SecurusViewModel.self) private var viewModel
    @State private var showThreatLog = false
    @State private var uptimeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var uptimeString = "--:--:--"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    statusBadge
                    SecurityStatusView()
                    actionButtons
                    recentThreatsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color.securusBg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "shield.checkered")
                            .foregroundStyle(Color.securusAccent)
                        Text("Securus Demo")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                }
            }
            .toolbarBackground(Color.securusSurface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(isPresented: $showThreatLog) {
                ThreatLogView()
                    .environment(viewModel)
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(uptimeTimer) { _ in
            uptimeString = viewModel.formattedUptime
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.securusAccent, Color.cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 16)

            Text("Securus Security SDK")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("v\(ThreatEvent.currentSDKVersion)")
                .font(.caption)
                .foregroundStyle(Color.securusSecondary)
        }
    }

    // MARK: - Agent State Badge

    private var statusBadge: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(stateColor)
                .frame(width: 10, height: 10)
                .shadow(color: stateColor.opacity(0.6), radius: 4)

            Text("Agent: \(viewModel.agentState.rawValue.capitalized)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)

            Spacer()

            if viewModel.agentState == .running {
                Label(uptimeString, systemImage: "clock")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.securusSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.securusSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.securusBorder, lineWidth: 1)
        )
    }

    private var stateColor: Color {
        switch viewModel.agentState {
        case .running:    return .green
        case .configured: return .yellow
        case .stopped:    return .orange
        case .error:      return .red
        case .idle:       return Color.securusSecondary
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Text("Actions")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                ActionButton(
                    title: "Security Scan",
                    icon: "magnifyingglass.circle.fill",
                    color: .securusAccent,
                    isLoading: viewModel.isScanning
                ) {
                    viewModel.runSecurityScan()
                }

                ActionButton(
                    title: "Integrity Check",
                    icon: "checkmark.shield.fill",
                    color: .green
                ) {
                    viewModel.checkRuntimeIntegrity()
                }
            }

            HStack(spacing: 12) {
                ActionButton(
                    title: "View Threat Log",
                    icon: "list.bullet.rectangle.fill",
                    color: .orange
                ) {
                    showThreatLog = true
                }

                ActionButton(
                    title: "Clear Log",
                    icon: "trash.fill",
                    color: .red
                ) {
                    viewModel.clearThreatLog()
                }
            }
        }
    }

    // MARK: - Recent Threats

    private var recentThreatsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Recent Events")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if !viewModel.threatLog.isEmpty {
                    Text("\(viewModel.threatLog.count) total")
                        .font(.caption)
                        .foregroundStyle(Color.securusSecondary)
                }
            }

            if viewModel.threatLog.isEmpty {
                emptyStateCard
            } else {
                // Show the 5 most recent threats inline
                ForEach(viewModel.threatLog.prefix(5)) { event in
                    ThreatEventRow(event: event)
                }

                if viewModel.threatLog.count > 5 {
                    Button {
                        showThreatLog = true
                    } label: {
                        Text("View all \(viewModel.threatLog.count) events")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.securusAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundStyle(.green.opacity(0.7))
            Text("No threats detected")
                .font(.subheadline)
                .foregroundStyle(Color.securusSecondary)
            Text("Run a scan or wait for real-time detections")
                .font(.caption)
                .foregroundStyle(Color.securusSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.securusSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.securusBorder, lineWidth: 1)
        )
    }
}

// MARK: - ActionButton

/// A reusable action button with icon, title, and optional loading spinner.
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(height: 24)
                } else {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.securusSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }
}

// MARK: - ThreatEventRow

/// A compact row displaying a single threat event with severity badge.
struct ThreatEventRow: View {
    let event: ThreatEvent

    var body: some View {
        HStack(spacing: 12) {
            // Severity indicator
            Circle()
                .fill(severityColor)
                .frame(width: 8, height: 8)
                .shadow(color: severityColor.opacity(0.5), radius: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(threatDisplayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)

                Text(formattedTimestamp)
                    .font(.caption2)
                    .foregroundStyle(Color.securusSecondary)
            }

            Spacer()

            Text(event.severity.rawValue.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(severityColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(severityColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.securusSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.securusBorder, lineWidth: 1)
        )
    }

    private var severityColor: Color {
        switch event.severity {
        case .critical: return .red
        case .high:     return .orange
        case .medium:   return .yellow
        case .low:      return Color.securusAccent
        }
    }

    private var threatDisplayName: String {
        switch event.threat_type {
        case .network_anomaly:    return "Network Anomaly"
        case .jailbreak_detected: return "Jailbreak Detected"
        case .debugger_attached:  return "Debugger Attached"
        case .app_repackaged:     return "App Repackaged"
        }
    }

    private var formattedTimestamp: String {
        // Parse ISO 8601 and display in a friendly format
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: event.timestamp) {
            let display = DateFormatter()
            display.dateStyle = .none
            display.timeStyle = .medium
            return display.string(from: date)
        }
        return event.timestamp
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(SecurusViewModel())
}
