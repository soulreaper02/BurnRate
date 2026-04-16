import Foundation
import OSLog
import SwiftData

private let logger = Logger(subsystem: "com.amitkumar.ClaudeCodexWatch", category: "SnapshotStore")

@MainActor
final class SnapshotStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func append(_ snapshot: UsageSnapshot) {
        let point = HistoryPoint(snapshot: snapshot)
        context.insert(point)
        do {
            try context.save()
        } catch {
            logger.error("Failed to save history point: \(error)")
        }
    }

    func pruneOlderThan(_ date: Date) {
        let predicate = #Predicate<HistoryPoint> { $0.capturedAt < date }
        do {
            try context.delete(model: HistoryPoint.self, where: predicate)
            try context.save()
            logger.info("Pruned history older than \(date)")
        } catch {
            logger.error("Failed to prune history: \(error)")
        }
    }
}
