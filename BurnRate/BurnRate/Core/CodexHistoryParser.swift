import Foundation
import OSLog

private let logger = Logger(subsystem: "com.amitkumar.burnrate", category: "CodexHistoryParser")

struct CodexReading {
    let weeklyUsedPercent: Double?
    let weeklyResetsAt: Date?
    let planTier: PlanTier
    let totalInputTokens: Int?
    let totalOutputTokens: Int?
}

struct CodexHistoryParser {
    private static let codexHome: URL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".codex")
    static var sessionsRoot: URL { codexHome.appendingPathComponent("sessions") }

    func parse() -> CodexReading? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: Self.sessionsRoot.path) else {
            logger.info("~/.codex/sessions not found")
            return nil
        }

        guard let mostRecent = findMostRecentJSONL() else {
            logger.info("No rollout-*.jsonl files found in ~/.codex/sessions")
            return nil
        }

        logger.info("Parsing \(mostRecent.lastPathComponent)")
        return extractLastTokenCount(from: mostRecent)
    }

    // MARK: - Private

    private func findMostRecentJSONL() -> URL? {
        let fm = FileManager.default
        var candidates: [(url: URL, date: Date)] = []

        guard let enumerator = fm.enumerator(
            at: Self.sessionsRoot,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for case let url as URL in enumerator {
            guard url.lastPathComponent.hasPrefix("rollout-"),
                  url.pathExtension == "jsonl" else { continue }
            if let date = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                candidates.append((url, date))
            }
        }

        return candidates.max(by: { $0.date < $1.date })?.url
    }

    private func extractLastTokenCount(from url: URL) -> CodexReading? {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            logger.error("Failed to read \(url.lastPathComponent)")
            return nil
        }

        var lastEntry: RawTokenCount?
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let lineData = line.data(using: .utf8),
                  let event = try? JSONDecoder().decode(RawEventMsg.self, from: lineData),
                  event.type == "event_msg",
                  let payload = event.payload,
                  payload.type == "token_count" else { continue }
            lastEntry = payload
        }

        guard let entry = lastEntry else {
            logger.info("No token_count events found in \(url.lastPathComponent)")
            return nil
        }

        let primary = entry.rateLimits?.primary
        let usedPct = primary?.usedPercent
        let resetsAt = primary?.resetsAt.map { Date(timeIntervalSince1970: $0) }
        let plan = PlanTier(rawString: entry.rateLimits?.planType)
        let usage = entry.info?.totalTokenUsage

        logger.info("Codex: weekly=\(usedPct ?? -1, privacy: .public)% plan=\(plan.rawValue, privacy: .public)")

        return CodexReading(
            weeklyUsedPercent: usedPct,
            weeklyResetsAt: resetsAt ?? nil,
            planTier: plan,
            totalInputTokens: usage?.inputTokens,
            totalOutputTokens: usage?.outputTokens
        )
    }
}

// MARK: - Decodable schema

private struct RawEventMsg: Decodable {
    let type: String
    let payload: RawTokenCount?
}

private struct RawTokenCount: Decodable {
    let type: String
    let info: RawTokenInfo?
    let rateLimits: RawRateLimits?

    enum CodingKeys: String, CodingKey {
        case type
        case info
        case rateLimits = "rate_limits"
    }
}

private struct RawTokenInfo: Decodable {
    let totalTokenUsage: RawTotalUsage?
    enum CodingKeys: String, CodingKey {
        case totalTokenUsage = "total_token_usage"
    }
}

private struct RawTotalUsage: Decodable {
    let inputTokens: Int?
    let outputTokens: Int?
    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

private struct RawRateLimits: Decodable {
    let primary: RawRateWindow?
    let planType: String?
    enum CodingKeys: String, CodingKey {
        case primary
        case planType = "plan_type"
    }
}

private struct RawRateWindow: Decodable {
    let usedPercent: Double?
    let resetsAt: Double?
    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case resetsAt = "resets_at"
    }
}
