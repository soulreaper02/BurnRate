import Foundation
import SwiftData

@Model
final class HistoryPoint {
    var providerIdRaw: String
    var capturedAt: Date
    var sessionUsedPercent: Double?
    var sessionResetsAt: Date?
    var weeklyUsedPercent: Double?
    var weeklyResetsAt: Date?
    var modelDisplayName: String?
    var contextUsedPercent: Double?
    var sessionCostUsd: Double?
    var dataSourceRaw: String
    var sourceNote: String?
    var isHealthy: Bool
    var errorMessage: String?

    init(snapshot: UsageSnapshot) {
        self.providerIdRaw = snapshot.providerId.rawValue
        self.capturedAt = snapshot.capturedAt
        self.sessionUsedPercent = snapshot.sessionUsedPercent
        self.sessionResetsAt = snapshot.sessionResetsAt
        self.weeklyUsedPercent = snapshot.weeklyUsedPercent
        self.weeklyResetsAt = snapshot.weeklyResetsAt
        self.modelDisplayName = snapshot.modelDisplayName
        self.contextUsedPercent = snapshot.contextUsedPercent
        self.sessionCostUsd = snapshot.sessionCostUsd
        self.dataSourceRaw = snapshot.dataSource.rawValue
        self.sourceNote = snapshot.sourceNote
        self.isHealthy = snapshot.isHealthy
        self.errorMessage = snapshot.errorMessage
    }
}
