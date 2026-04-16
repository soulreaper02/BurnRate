import SwiftUI
import SwiftData
import Charts

struct InlineHistoryView: View {
    let providerId: ProviderID

    @State private var selectedRange: TimeRange = .day
    @Query private var allPoints: [HistoryPoint]

    // Claude tracks the 5h session window; Codex tracks the 7d weekly window
    private var metricLabel: String {
        providerId == .claudeCode ? "5-hour session limit" : "7-day weekly limit"
    }

    private var points: [HistoryPoint] {
        let cutoff = selectedRange.cutoff
        return allPoints
            .filter { $0.providerIdRaw == providerId.rawValue && $0.capturedAt >= cutoff }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    private var values: [Double] {
        points.compactMap { providerId == .claudeCode ? $0.sessionUsedPercent : $0.weeklyUsedPercent }
    }

    private var currentValue: Double? { values.last }
    private var peakValue: Double? { values.max() }

    private func lineColor(_ pct: Double) -> Color {
        switch pct {
        case ..<80: return .green
        case ..<95: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header: what this graph shows
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Usage over time")
                        .font(.caption.bold())
                    Text(metricLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Picker("Range", selection: $selectedRange) {
                    ForEach(TimeRange.allCases) { r in
                        Text(r.rawValue).tag(r)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 130)
                .controlSize(.mini)
            }

            if points.count < 2 {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(.tertiary)
                        Text("Not enough data yet")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("Data is recorded every 30 seconds while the app runs.")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .frame(height: 100)
            } else {
                // Chart
                Chart {
                    // Green zone (safe)
                    RectangleMark(
                        xStart: nil, xEnd: nil,
                        yStart: .value("", 0),
                        yEnd: .value("", 80)
                    )
                    .foregroundStyle(Color.green.opacity(0.04))

                    // Yellow zone (warning)
                    RectangleMark(
                        xStart: nil, xEnd: nil,
                        yStart: .value("", 80),
                        yEnd: .value("", 95)
                    )
                    .foregroundStyle(Color.orange.opacity(0.07))

                    // Red zone (critical)
                    RectangleMark(
                        xStart: nil, xEnd: nil,
                        yStart: .value("", 95),
                        yEnd: .value("", 100)
                    )
                    .foregroundStyle(Color.red.opacity(0.1))

                    // 80% threshold line
                    RuleMark(y: .value("Warning", 80))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(Color.orange.opacity(0.7))
                        .annotation(position: .trailing, alignment: .center) {
                            Text("80%")
                                .font(.system(size: 8))
                                .foregroundStyle(.orange)
                        }

                    // 95% threshold line
                    RuleMark(y: .value("Critical", 95))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(Color.red.opacity(0.7))
                        .annotation(position: .trailing, alignment: .center) {
                            Text("95%")
                                .font(.system(size: 8))
                                .foregroundStyle(.red)
                        }

                    // Area fill
                    ForEach(points) { point in
                        if let pct = providerId == .claudeCode ? point.sessionUsedPercent : point.weeklyUsedPercent {
                            AreaMark(
                                x: .value("Time", point.capturedAt),
                                yStart: .value("Base", 0),
                                yEnd: .value("Usage", pct)
                            )
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [.accentColor.opacity(0.2), .accentColor.opacity(0)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                        }
                    }

                    // Usage line
                    ForEach(points) { point in
                        if let pct = providerId == .claudeCode ? point.sessionUsedPercent : point.weeklyUsedPercent {
                            LineMark(
                                x: .value("Time", point.capturedAt),
                                y: .value("Usage", pct)
                            )
                            .foregroundStyle(currentValue.map { lineColor($0) } ?? .accentColor)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                            .foregroundStyle(.secondary.opacity(0.3))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(xLabel(date))
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { v in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                            .foregroundStyle(.secondary.opacity(0.3))
                        AxisValueLabel {
                            Text("\(v.as(Int.self) ?? 0)%")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: 110)

                // Legend
                HStack(spacing: 12) {
                    legendDot(.green, "Safe (<80%)")
                    legendDot(.orange, "Warning (80–95%)")
                    legendDot(.red, "Critical (>95%)")
                }
                .padding(.top, 2)

                // Stats row: current + peak
                HStack(spacing: 8) {
                    statPill(
                        label: "Now",
                        value: currentValue.map { String(format: "%.1f%%", $0) } ?? "—",
                        color: currentValue.map { lineColor($0) } ?? .secondary
                    )
                    statPill(
                        label: "Peak",
                        value: peakValue.map { String(format: "%.1f%%", $0) } ?? "—",
                        color: peakValue.map { lineColor($0) } ?? .secondary
                    )
                    Spacer()
                    Text("\(points.count) readings")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
                .padding(.top, 4)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func xLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        switch selectedRange {
        case .day:
            fmt.dateFormat = "h a"   // "9 AM"
        case .week:
            fmt.dateFormat = "EEE"   // "Mon"
        case .month:
            fmt.dateFormat = "MMM d" // "Apr 12"
        }
        return fmt.string(from: date)
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }

    private func statPill(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption2.bold().monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.quaternary, in: Capsule())
    }
}
