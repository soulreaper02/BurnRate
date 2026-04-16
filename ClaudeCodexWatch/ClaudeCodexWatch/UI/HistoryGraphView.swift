import SwiftUI
import SwiftData
import Charts

enum TimeRange: String, CaseIterable, Identifiable {
    case day = "24h"
    case week = "7d"
    case month = "30d"

    var id: String { rawValue }

    var cutoff: Date {
        let secs: TimeInterval
        switch self {
        case .day:   secs = 24 * 3600
        case .week:  secs = 7 * 24 * 3600
        case .month: secs = 30 * 24 * 3600
        }
        return Date.now.addingTimeInterval(-secs)
    }
}

struct HistoryGraphView: View {
    let providerId: ProviderID

    @State private var selectedRange: TimeRange = .day
    @Query private var allPoints: [HistoryPoint]

    private var filteredPoints: [HistoryPoint] {
        let cutoff = selectedRange.cutoff
        return allPoints
            .filter { $0.providerIdRaw == providerId.rawValue && $0.capturedAt >= cutoff }
            .sorted { $0.capturedAt < $1.capturedAt }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(providerId == .claudeCode ? "Claude Code History" : "Codex CLI History")
                    .font(.title2.bold())
                Spacer()
                Picker("Range", selection: $selectedRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            if filteredPoints.count < 2 {
                Spacer()
                ContentUnavailableView(
                    "Not enough data yet",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Check back after the app has been running for a while.")
                )
                .accessibilityLabel("Not enough data yet")
                Spacer()
            } else {
                chart
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 300)
    }

    private var chart: some View {
        Chart(filteredPoints) { point in
            if let pct = providerId == .claudeCode
                ? point.sessionUsedPercent
                : point.weeklyUsedPercent {
                LineMark(
                    x: .value("Time", point.capturedAt),
                    y: .value("Usage %", pct)
                )
                .foregroundStyle(by: .value("Metric", providerId == .claudeCode ? "Session" : "Weekly"))

                AreaMark(
                    x: .value("Time", point.capturedAt),
                    yStart: .value("Base", 0),
                    yEnd: .value("Usage %", pct)
                )
                .foregroundStyle(.linearGradient(
                    colors: [.accentColor.opacity(0.3), .accentColor.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
            }
        }
        .chartYScale(domain: 0...100)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 5)) }
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisGridLine()
                AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
            }
        }
        .chartLegend(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
