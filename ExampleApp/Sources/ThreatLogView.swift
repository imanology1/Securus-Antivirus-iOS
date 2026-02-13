// ============================================================================
// ThreatLogView.swift
// SecurusExampleApp
//
// Full-screen threat event log with severity badges, threat type labels,
// timestamps, and metadata detail expansion.
// ============================================================================

import SwiftUI
import SecurusCore

// MARK: - ThreatLogView

struct ThreatLogView: View {

    @Environment(SecurusViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var filterSeverity: ThreatSeverity?
    @State private var expandedEventID: String?

    private var filteredEvents: [ThreatEvent] {
        guard let severity = filterSeverity else {
            return viewModel.threatLog
        }
        return viewModel.threatLog.filter { $0.severity == severity }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.securusSurface)

                Divider()
                    .background(Color.securusBorder)

                if filteredEvents.isEmpty {
                    emptyState
                } else {
                    eventList
                }
            }
            .background(Color.securusBg)
            .navigationTitle("Threat Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.securusAccent)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Clear All", role: .destructive) {
                            viewModel.clearThreatLog()
                        }
                        Button("Add Sample Events") {
                            addSampleEvents()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Color.securusAccent)
                    }
                }
            }
            .toolbarBackground(Color.securusSurface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    isSelected: filterSeverity == nil,
                    color: Color.securusAccent
                ) {
                    filterSeverity = nil
                }

                FilterChip(
                    title: "Critical",
                    isSelected: filterSeverity == .critical,
                    color: .red
                ) {
                    filterSeverity = .critical
                }

                FilterChip(
                    title: "High",
                    isSelected: filterSeverity == .high,
                    color: .orange
                ) {
                    filterSeverity = .high
                }

                FilterChip(
                    title: "Medium",
                    isSelected: filterSeverity == .medium,
                    color: .yellow
                ) {
                    filterSeverity = .medium
                }

                FilterChip(
                    title: "Low",
                    isSelected: filterSeverity == .low,
                    color: Color.securusAccent
                ) {
                    filterSeverity = .low
                }
            }
        }
    }

    // MARK: - Event List

    private var eventList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(filteredEvents) { event in
                    ThreatDetailCard(
                        event: event,
                        isExpanded: expandedEventID == event.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if expandedEventID == event.id {
                                expandedEventID = nil
                            } else {
                                expandedEventID = event.id
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "shield.checkered")
                .font(.system(size: 48))
                .foregroundStyle(Color.securusSecondary.opacity(0.5))
            Text("No events to display")
                .font(.headline)
                .foregroundStyle(Color.securusSecondary)
            if filterSeverity != nil {
                Text("Try changing the filter or run a scan.")
                    .font(.subheadline)
                    .foregroundStyle(Color.securusSecondary.opacity(0.7))
            } else {
                Text("Run a security scan to generate sample events.")
                    .font(.subheadline)
                    .foregroundStyle(Color.securusSecondary.opacity(0.7))
            }
            Spacer()
        }
    }

    // MARK: - Sample Data

    private func addSampleEvents() {
        let samples: [(ThreatType, ThreatSeverity, [String: String])] = [
            (.jailbreak_detected, .critical, [
                "method": "cydia_file_check",
                "path": "/Applications/Cydia.app"
            ]),
            (.network_anomaly, .high, [
                "destination_hash": "sha256:e4f5a6b7...",
                "anomaly_score": "0.87",
                "method": "ml_inference"
            ]),
            (.debugger_attached, .medium, [
                "method": "sysctl_check",
                "pid": "12345"
            ]),
            (.app_repackaged, .critical, [
                "method": "codesign_verify",
                "expected_team": "ABCDEF1234",
                "actual_team": "UNKNOWN"
            ]),
            (.network_anomaly, .low, [
                "destination_hash": "sha256:1a2b3c4d...",
                "anomaly_score": "0.21",
                "method": "statistical_baseline"
            ])
        ]

        for (type, severity, metadata) in samples {
            let event = ThreatEvent(
                threatType: type,
                severity: severity,
                metadata: metadata,
                appToken: "demo_token_\(UUID().uuidString.prefix(8))"
            )
            viewModel.threatLog.insert(event, at: 0)
        }
    }
}

// MARK: - FilterChip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? .white : color)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    isSelected
                        ? color.opacity(0.3)
                        : Color.securusBg
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? color : color.opacity(0.3),
                            lineWidth: 1
                        )
                )
        }
    }
}

// MARK: - ThreatDetailCard

struct ThreatDetailCard: View {
    let event: ThreatEvent
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button(action: onTap) {
                HStack(spacing: 12) {
                    severityIcon

                    VStack(alignment: .leading, spacing: 2) {
                        Text(threatDisplayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        Text(formattedTimestamp)
                            .font(.caption2)
                            .foregroundStyle(Color.securusSecondary)
                    }

                    Spacer()

                    severityBadge

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.securusSecondary)
                }
                .padding(14)
            }

            // Expanded detail section
            if isExpanded {
                Divider()
                    .background(Color.securusBorder)

                VStack(alignment: .leading, spacing: 8) {
                    detailRow(label: "Threat ID", value: event.threat_id)
                    detailRow(label: "SDK Version", value: event.sdk_version)
                    detailRow(label: "OS Version", value: event.os_version)

                    if !event.metadata.isEmpty {
                        Text("Metadata")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.securusSecondary)
                            .padding(.top, 4)

                        ForEach(
                            event.metadata.sorted(by: { $0.key < $1.key }),
                            id: \.key
                        ) { key, value in
                            detailRow(label: key, value: value)
                        }
                    }
                }
                .padding(14)
            }
        }
        .background(Color.securusSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(severityColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Subviews

    private var severityIcon: some View {
        ZStack {
            Circle()
                .fill(severityColor.opacity(0.15))
                .frame(width: 36, height: 36)
            Image(systemName: threatIcon)
                .font(.system(size: 16))
                .foregroundStyle(severityColor)
        }
    }

    private var severityBadge: some View {
        Text(event.severity.rawValue.uppercased())
            .font(.caption2.weight(.bold))
            .foregroundStyle(severityColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(severityColor.opacity(0.15))
            .clipShape(Capsule())
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.securusSecondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.caption2.monospaced())
                .foregroundStyle(.white.opacity(0.85))
                .textSelection(.enabled)
        }
    }

    // MARK: - Helpers

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

    private var threatIcon: String {
        switch event.threat_type {
        case .network_anomaly:    return "network.badge.shield.half.filled"
        case .jailbreak_detected: return "lock.trianglebadge.exclamationmark"
        case .debugger_attached:  return "ant.fill"
        case .app_repackaged:     return "shippingbox.fill"
        }
    }

    private var formattedTimestamp: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: event.timestamp) {
            let display = DateFormatter()
            display.dateFormat = "MMM d, yyyy 'at' HH:mm:ss"
            return display.string(from: date)
        }
        return event.timestamp
    }
}

// MARK: - Preview

#Preview {
    ThreatLogView()
        .environment(SecurusViewModel())
}
