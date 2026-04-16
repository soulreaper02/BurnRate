import SwiftUI
import AppKit

struct ProviderCardView: View {
    let snapshot: UsageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            Divider()
            if let error = snapshot.errorMessage {
                errorView(error)
            } else {
                metricsView
            }
            if let note = snapshot.sourceNote {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack {
            Circle()
                .fill(snapshot.isHealthy ? Color.green : Color.red)
                .frame(width: 8, height: 8)
                .accessibilityLabel(snapshot.isHealthy ? "Healthy" : "Unhealthy")

            Text(snapshot.providerId == .claudeCode ? "Claude Code" : "Codex CLI")
                .font(.headline)

            Spacer()

            Text(snapshot.dataSource == .live ? "Live" : "Estimated")
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var metricsView: some View {
        // Session usage (Claude only — Codex has no session limit)
        if let pct = snapshot.sessionUsedPercent {
            usageRow(
                label: "Session (5h)",
                percent: pct,
                resetsAt: snapshot.sessionResetsAt
            )
        }

        // Weekly usage
        if let pct = snapshot.weeklyUsedPercent {
            usageRow(
                label: "Weekly (7d)",
                percent: pct,
                resetsAt: snapshot.weeklyResetsAt
            )
        }

        // Claude-specific extras
        if snapshot.providerId == .claudeCode {
            if let model = snapshot.modelDisplayName {
                labeledRow("Model", value: model)
            }
            if let cost = snapshot.sessionCostUsd {
                labeledRow("Session cost", value: String(format: "$%.4f", cost))
            }
            if let ctx = snapshot.contextUsedPercent {
                labeledRow("Context", value: String(format: "%.0f%%", ctx))
            }
        }
    }

    private func usageRow(label: String, percent: Double, resetsAt: Date?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 0) {
                    Text(String(format: "%.0f%%", percent))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(barColor(percent))
                    Text(" ")
                    SegmentBar(percent: percent, color: barColor(percent))
                }
                .accessibilityLabel("\(label): \(Int(percent.rounded()))%")
            }
            if let date = resetsAt {
                Text("Resets \(date, style: .relative)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func labeledRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.yellow)
                .accessibilityLabel("Warning")
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func barColor(_ pct: Double) -> Color {
        switch pct {
        case ..<50: return .green
        case ..<80: return .yellow
        default:    return .red
        }
    }
}


// MARK: - Segment bar

private struct SegmentBar: View {
    let percent: Double
    let color: Color
    private let total = 10

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<total, id: \.self) { i in
                let threshold = Double(i + 1) * (100.0 / Double(total))
                RoundedRectangle(cornerRadius: 1.5)
                    .frame(width: 4, height: 12)
                    .foregroundStyle(percent >= threshold ? color : color.opacity(0.15))
            }
        }
    }
}

// MARK: - History button wrapper

struct ProviderCardWithHistoryButton: View {
    let snapshot: UsageSnapshot
    @State private var showHistory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProviderCardView(snapshot: snapshot)

            // History toggle row — always visible inside the card
            Divider().padding(.horizontal, 12)
            HStack {
                Spacer()
                Button(showHistory ? "Hide History" : "History") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showHistory.toggle()
                    }
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel(showHistory ? "Hide history" : "View history for \(snapshot.providerId == .claudeCode ? "Claude Code" : "Codex CLI")")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if showHistory {
                Divider().padding(.horizontal, 12)
                InlineHistoryView(providerId: snapshot.providerId)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
