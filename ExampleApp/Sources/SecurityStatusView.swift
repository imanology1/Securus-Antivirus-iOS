// ============================================================================
// SecurityStatusView.swift
// SecurusExampleApp
//
// Dashboard-style security status card showing protection state, module
// activity indicators, AI engine status, and agent uptime.
// ============================================================================

import SwiftUI
import SecurusCore

// MARK: - SecurityStatusView

struct SecurityStatusView: View {

    @Environment(SecurusViewModel.self) private var viewModel
    @State private var shieldPulse = false
    @State private var uptimeTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var uptimeDisplay = "--:--:--"

    var body: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Text("Security Status")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                overallStatusLabel
            }

            // Shield + protection summary
            shieldSection

            // Module status rows
            VStack(spacing: 0) {
                moduleRow(
                    icon: "network",
                    title: "Network Monitoring",
                    isActive: viewModel.networkMonitoringActive
                        && viewModel.agentState == .running,
                    detail: viewModel.agentState == .running
                        ? "Learning baseline"
                        : nil
                )

                Divider().background(Color.securusBorder)

                moduleRow(
                    icon: "cpu",
                    title: "Runtime Protection",
                    isActive: viewModel.runtimeProtectionActive
                        && viewModel.agentState == .running,
                    detail: viewModel.agentState == .running
                        ? "Integrity verified"
                        : nil
                )

                Divider().background(Color.securusBorder)

                moduleRow(
                    icon: "brain.head.profile",
                    title: "AI Engine",
                    isActive: viewModel.aiEngineLoaded,
                    detail: viewModel.aiEngineLoaded
                        ? "Statistical fallback"
                        : nil
                )

                Divider().background(Color.securusBorder)

                // Uptime row
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.securusAccent)
                        .frame(width: 28)

                    Text("Agent Uptime")
                        .font(.subheadline)
                        .foregroundStyle(.white)

                    Spacer()

                    Text(uptimeDisplay)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Color.securusSecondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .padding(16)
        .background(Color.securusSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.securusBorder, lineWidth: 1)
        )
        .onReceive(uptimeTimer) { _ in
            uptimeDisplay = viewModel.formattedUptime
        }
    }

    // MARK: - Overall Status Label

    private var overallStatusLabel: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(overallColor)
                .frame(width: 6, height: 6)
            Text(overallText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(overallColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(overallColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var overallColor: Color {
        switch viewModel.agentState {
        case .running:    return .green
        case .configured: return .yellow
        case .error:      return .red
        default:          return Color.securusSecondary
        }
    }

    private var overallText: String {
        switch viewModel.agentState {
        case .running:    return "Protected"
        case .configured: return "Ready"
        case .stopped:    return "Stopped"
        case .error:      return "Error"
        case .idle:       return "Not Configured"
        }
    }

    // MARK: - Shield Section

    private var shieldSection: some View {
        HStack(spacing: 16) {
            // Animated shield icon
            ZStack {
                Circle()
                    .fill(shieldColor.opacity(0.1))
                    .frame(width: 72, height: 72)

                Circle()
                    .strokeBorder(shieldColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 72, height: 72)
                    .scaleEffect(shieldPulse ? 1.15 : 1.0)
                    .opacity(shieldPulse ? 0.0 : 0.6)

                Image(systemName: shieldIconName)
                    .font(.system(size: 30))
                    .foregroundStyle(shieldColor)
                    .symbolEffect(
                        .pulse,
                        isActive: viewModel.agentState == .running
                    )
            }
            .onAppear {
                if viewModel.agentState == .running {
                    withAnimation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                    ) {
                        shieldPulse = true
                    }
                }
            }

            // Protection summary text
            VStack(alignment: .leading, spacing: 4) {
                Text(protectionTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                Text(protectionSubtitle)
                    .font(.caption)
                    .foregroundStyle(Color.securusSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var shieldColor: Color {
        switch viewModel.agentState {
        case .running:    return .green
        case .configured: return .yellow
        case .error:      return .red
        default:          return Color.securusSecondary
        }
    }

    private var shieldIconName: String {
        switch viewModel.agentState {
        case .running:    return "shield.checkered"
        case .configured: return "shield.lefthalf.filled"
        case .error:      return "shield.slash"
        default:          return "shield"
        }
    }

    private var protectionTitle: String {
        switch viewModel.agentState {
        case .running:    return "Device Protected"
        case .configured: return "Ready to Start"
        case .stopped:    return "Protection Stopped"
        case .error:      return "Protection Error"
        case .idle:       return "Awaiting Setup"
        }
    }

    private var protectionSubtitle: String {
        switch viewModel.agentState {
        case .running:
            let count = viewModel.threatLog.count
            if count == 0 {
                return "All systems nominal. No threats detected."
            }
            return "\(count) event\(count == 1 ? "" : "s") recorded this session."
        case .configured:
            return "Agent configured. Call start() to begin monitoring."
        case .stopped:
            return "Agent stopped. Restart to resume protection."
        case .error:
            return viewModel.errors.last ?? "An error occurred during initialization."
        case .idle:
            return "Configure the SDK with an API key to begin."
        }
    }

    // MARK: - Module Row

    private func moduleRow(
        icon: String,
        title: String,
        isActive: Bool,
        detail: String?
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(isActive ? Color.securusAccent : Color.securusSecondary)
                .frame(width: 28)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.white)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isActive ? .green : Color.securusSecondary.opacity(0.5))
                        .frame(width: 6, height: 6)
                    Text(isActive ? "Active" : "Inactive")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(
                            isActive ? .green : Color.securusSecondary
                        )
                }

                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(Color.securusSecondary.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        SecurityStatusView()
            .padding()
    }
    .background(Color.securusBg)
    .environment(SecurusViewModel())
}
