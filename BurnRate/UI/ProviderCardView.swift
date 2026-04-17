import SwiftUI
import AppKit

// MARK: - Font helper

private extension Font {
    static func fira(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("FiraCode-Regular", size: size)
    }
}

// MARK: - Mini progress bar

private struct MiniBar: View {
    let value: Double   // 0–100

    private var fill: Double { min(max(value, 0), 100) / 100 }
    private var color: Color {
        switch value {
        case ..<60:  return .green
        case ..<80:  return .yellow
        default:     return .red
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.2))
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geo.size.width * fill)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Card

struct ProviderCardView: View {
    let snapshot: UsageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.vertical, 10)
            if let error = snapshot.errorMessage {
                errorRow(error)
            } else {
                metrics
            }
        }
        .padding(14)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(snapshot.isHealthy ? Color.green : Color.red)
                .frame(width: 7, height: 7)

            Text("Claude Code")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            sourceLabel
        }
    }

    private var sourceLabel: some View {
        let text: String
        switch snapshot.dataSource {
        case .live:      text = "Live"
        case .stale:     text = "Stale"
        case .estimated: text = "Est."
        }
        return Text(text)
            .font(.fira(10))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
    }

    // MARK: - Metrics

    @ViewBuilder
    private var metrics: some View {
        VStack(alignment: .leading, spacing: 6) {

            // Session rate limit
            if let pct = snapshot.sessionUsedPercent {
                barRow(
                    label: "Session",
                    value: String(format: "%.0f%%", pct),
                    percent: pct
                )
            }
            if let resets = snapshot.sessionResetsAt {
                subRow("resets " + resets.formatted(.relative(presentation: .named, unitsStyle: .wide)))
            }

            // Weekly rate limit
            if let pct = snapshot.weeklyUsedPercent {
                barRow(
                    label: "Weekly",
                    value: String(format: "%.0f%%", pct),
                    percent: pct
                )
            }
            if let resets = snapshot.weeklyResetsAt {
                subRow("resets " + resets.formatted(.relative(presentation: .named, unitsStyle: .wide)))
            }

            if snapshot.sessionUsedPercent != nil || snapshot.weeklyUsedPercent != nil {
                Divider().padding(.vertical, 2)
            }

            // Context window
            if let ctx = snapshot.contextUsedPercent {
                let remaining = max(0, 100 - ctx)
                metricRow(
                    label: "Context",
                    value: String(format: "%.0f%% until auto-compact", remaining)
                )
            }

            if let model = snapshot.modelDisplayName {
                metricRow(label: "Model", value: model)
            }

            Divider().padding(.vertical, 2)

            if let cost = snapshot.sessionCostUsd {
                metricRow(label: "Session cost", value: String(format: "$%.4f", cost))
            }

            if let cost = snapshot.weeklyCostUsd {
                metricRow(label: "Weekly cost", value: String(format: "$%.2f", cost), accent: true)
            }
        }
    }

    // MARK: - Row builders

    private func barRow(label: String, value: String, percent: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.fira(11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.fira(12))
            }
            MiniBar(value: percent)
        }
    }

    private func subRow(_ text: String) -> some View {
        Text(text)
            .font(.fira(10))
            .foregroundStyle(.tertiary)
            .padding(.leading, 2)
            .padding(.bottom, 2)
    }

    private func metricRow(label: String, value: String, accent: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.fira(11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.fira(12))
                .foregroundStyle(accent ? Color.primary : .primary)
        }
    }

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.fira(11))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Card background helper

extension ProviderCardView {
    func cardStyle() -> some View {
        self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
