import Foundation
import OSLog

private let logger = Logger(subsystem: "com.amitkumar.burnrate", category: "CodexProvider")

struct CodexProvider: UsageProvider {
    let id: ProviderID = .codex
    let displayName: String = "Codex CLI"

    private static let codexHome: URL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".codex")

    func fetchSnapshot() async -> UsageSnapshot {
        let fm = FileManager.default
        guard fm.fileExists(atPath: Self.codexHome.path) else {
            logger.info("~/.codex not found")
            return .unhealthy(
                providerId: .codex,
                errorMessage: "Codex CLI not detected.",
                sourceNote: nil
            )
        }

        let parser = CodexHistoryParser()
        guard let reading = parser.parse() else {
            return .unhealthy(
                providerId: .codex,
                errorMessage: "No Codex sessions found yet.",
                sourceNote: "Estimated from local session files"
            )
        }

        logger.info("Codex snapshot: weekly=\(reading.weeklyUsedPercent ?? -1, privacy: .public)%")

        return UsageSnapshot(
            providerId: .codex,
            capturedAt: Date(),
            sessionUsedPercent: nil,
            sessionResetsAt: nil,
            weeklyUsedPercent: reading.weeklyUsedPercent,
            weeklyResetsAt: reading.weeklyResetsAt,
            modelDisplayName: nil,
            contextUsedPercent: nil,
            sessionCostUsd: nil,
            dataSource: .estimated,
            sourceNote: "Estimated from local session files — for authoritative numbers open Codex",
            isHealthy: true,
            errorMessage: nil
        )
    }
}
