import Foundation

enum DataSource: String, Codable {
    case live
    case stale     // hook data exists but is old; JSONL cost data is current
    case estimated // no hook data; computed from JSONL only
}

struct UsageSnapshot {
    let providerId: ProviderID
    let capturedAt: Date

    // Rate limit data — from hook (accurate) or nil if hook unavailable
    let sessionUsedPercent: Double?   // token-based, from hook
    let sessionResetsAt: Date?
    let weeklyUsedPercent: Double?    // token-based, from hook
    let weeklyResetsAt: Date?

    // Model / context — from hook
    let modelDisplayName: String?
    let contextUsedPercent: Double?

    // Costs — from JSONL history (accurate)
    let sessionCostUsd: Double?
    let weeklyCostUsd: Double?

    let dataSource: DataSource
    let isHealthy: Bool
    let errorMessage: String?
}
