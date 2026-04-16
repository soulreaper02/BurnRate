import Foundation

enum DataSource: String, Codable {
    case live
    case estimated
}

struct UsageSnapshot {
    let providerId: ProviderID
    let capturedAt: Date
    let sessionUsedPercent: Double?
    let sessionResetsAt: Date?
    let weeklyUsedPercent: Double?
    let weeklyResetsAt: Date?
    let modelDisplayName: String?
    let contextUsedPercent: Double?
    let sessionCostUsd: Double?
    let dataSource: DataSource
    let sourceNote: String?
    let isHealthy: Bool
    let errorMessage: String?

    static func unhealthy(
        providerId: ProviderID,
        errorMessage: String,
        sourceNote: String? = nil
    ) -> UsageSnapshot {
        UsageSnapshot(
            providerId: providerId,
            capturedAt: Date(),
            sessionUsedPercent: nil,
            sessionResetsAt: nil,
            weeklyUsedPercent: nil,
            weeklyResetsAt: nil,
            modelDisplayName: nil,
            contextUsedPercent: nil,
            sessionCostUsd: nil,
            dataSource: .estimated,
            sourceNote: sourceNote,
            isHealthy: false,
            errorMessage: errorMessage
        )
    }
}
