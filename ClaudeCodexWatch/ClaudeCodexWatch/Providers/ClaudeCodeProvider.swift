import Foundation
import OSLog

private let logger = Logger(subsystem: "com.amitkumar.ClaudeCodexWatch", category: "ClaudeCodeProvider")

struct ClaudeCodeProvider: UsageProvider {
    let id: ProviderID = .claudeCode
    let displayName: String = "Claude Code"

    private static let staleThreshold: TimeInterval = 15 * 60

    func fetchSnapshot() async -> UsageSnapshot {
        let url = AppSupportPath.claudeLatestJSON
        let fm = FileManager.default

        guard fm.fileExists(atPath: url.path) else {
            logger.info("claude_latest.json not found")
            return .unhealthy(
                providerId: .claudeCode,
                errorMessage: "No data yet — install the statusline hook from Settings.",
                sourceNote: "Claude Code statusline"
            )
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            logger.error("Failed to read claude_latest.json: \(error)")
            return .unhealthy(providerId: .claudeCode, errorMessage: "Failed to read cache file: \(error.localizedDescription)")
        }

        let isStale: Bool
        if let attrs = try? fm.attributesOfItem(atPath: url.path),
           let modified = attrs[.modificationDate] as? Date {
            isStale = Date().timeIntervalSince(modified) > Self.staleThreshold
        } else {
            isStale = false
        }

        let raw: RawClaudeStatus
        do {
            raw = try JSONDecoder().decode(RawClaudeStatus.self, from: data)
        } catch {
            logger.error("Failed to decode claude_latest.json: \(error)")
            return .unhealthy(providerId: .claudeCode, errorMessage: "Failed to parse data: \(error.localizedDescription)")
        }

        let sessionPct = raw.rateLimits?.fiveHour?.usedPercentage
        let weeklyPct = raw.rateLimits?.sevenDay?.usedPercentage
        let sessionResets = raw.rateLimits?.fiveHour?.resetsAt.map { Date(timeIntervalSince1970: $0) }
        let weeklyResets = raw.rateLimits?.sevenDay?.resetsAt.map { Date(timeIntervalSince1970: $0) }

        // Staleness is informational only — data is still valid, Claude Code just isn't actively running
        let sourceNote = isStale ? "Claude Code statusline · data may be from a previous session" : "Claude Code statusline"

        logger.info("Parsed Claude snapshot: session=\(sessionPct ?? -1, privacy: .public)% weekly=\(weeklyPct ?? -1, privacy: .public)% stale=\(isStale, privacy: .public)")

        return UsageSnapshot(
            providerId: .claudeCode,
            capturedAt: Date(),
            sessionUsedPercent: sessionPct,
            sessionResetsAt: sessionResets ?? nil,
            weeklyUsedPercent: weeklyPct,
            weeklyResetsAt: weeklyResets ?? nil,
            modelDisplayName: raw.model?.displayName,
            contextUsedPercent: raw.contextWindow?.usedPercentage,
            sessionCostUsd: raw.cost?.totalCostUsd,
            dataSource: .live,
            sourceNote: sourceNote,
            isHealthy: true,
            errorMessage: nil
        )
    }
}

// MARK: - Decodable schema

private struct RawClaudeStatus: Decodable {
    let model: RawModel?
    let cost: RawCost?
    let contextWindow: RawContextWindow?
    let rateLimits: RawRateLimits?

    enum CodingKeys: String, CodingKey {
        case model
        case cost
        case contextWindow = "context_window"
        case rateLimits = "rate_limits"
    }
}

private struct RawModel: Decodable {
    let id: String?
    let displayName: String?
    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

private struct RawCost: Decodable {
    let totalCostUsd: Double?
    enum CodingKeys: String, CodingKey {
        case totalCostUsd = "total_cost_usd"
    }
}

private struct RawContextWindow: Decodable {
    let usedPercentage: Double?
    enum CodingKeys: String, CodingKey {
        case usedPercentage = "used_percentage"
    }
}

private struct RawRateLimits: Decodable {
    let fiveHour: RawWindow?
    let sevenDay: RawWindow?
    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

private struct RawWindow: Decodable {
    let usedPercentage: Double?
    let resetsAt: Double?
    enum CodingKeys: String, CodingKey {
        case usedPercentage = "used_percentage"
        case resetsAt = "resets_at"
    }
}
