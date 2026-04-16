import Foundation
import UserNotifications
import OSLog

private let logger = Logger(subsystem: "com.amitkumar.burnrate", category: "Notifier")

@MainActor
final class Notifier {
    private var previous: [ProviderID: UsageSnapshot] = [:]
    private let thresholds: [Double] = [80, 95]

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error { logger.error("Notification auth error: \(error)") }
            logger.info("Notification authorization granted: \(granted)")
        }
    }

    func evaluate(latest: [ProviderID: UsageSnapshot]) {
        for (id, snapshot) in latest {
            guard snapshot.isHealthy else { continue }
            let prev = previous[id]

            checkThresholds(snapshot: snapshot, previous: prev, metric: "session",
                            current: snapshot.sessionUsedPercent,
                            previousValue: prev?.sessionUsedPercent,
                            windowStart: snapshot.sessionResetsAt)

            checkThresholds(snapshot: snapshot, previous: prev, metric: "weekly",
                            current: snapshot.weeklyUsedPercent,
                            previousValue: prev?.weeklyUsedPercent,
                            windowStart: snapshot.weeklyResetsAt)

            checkReset(snapshot: snapshot, previous: prev)
        }
        previous = latest
    }

    // MARK: - Private

    private func checkThresholds(
        snapshot: UsageSnapshot,
        previous: UsageSnapshot?,
        metric: String,
        current: Double?,
        previousValue: Double?,
        windowStart: Date?
    ) {
        guard let current, isEnabled(provider: snapshot.providerId, metric: metric) else { return }

        let windowKey = windowStart.map { ISO8601DateFormatter().string(from: $0) } ?? "unknown"

        for threshold in thresholds {
            guard isThresholdEnabled(provider: snapshot.providerId, metric: metric, threshold: threshold) else { continue }
            let wasBelow = (previousValue ?? 0) < threshold
            let isNowAbove = current >= threshold
            guard wasBelow && isNowAbove else { continue }

            let providerName = snapshot.providerId == .claudeCode ? "Claude Code" : "Codex CLI"
            let metricLabel = metric == "session" ? "5h session" : "weekly"
            let notifId = "\(snapshot.providerId.rawValue)-\(metric)-\(Int(threshold))-\(windowKey)"

            fire(
                id: notifId,
                title: "\(providerName): \(Int(threshold))% of \(metricLabel) limit",
                body: String(format: "%.1f%% used — consider wrapping up soon.", current)
            )
        }
    }

    private func checkReset(snapshot: UsageSnapshot, previous: UsageSnapshot?) {
        guard isEnabled(provider: snapshot.providerId, metric: "reset") else { return }
        guard let prevResets = previous?.sessionResetsAt,
              let currentResets = snapshot.sessionResetsAt,
              prevResets < Date.now && currentResets > Date.now else { return }

        let providerName = snapshot.providerId == .claudeCode ? "Claude Code" : "Codex CLI"
        fire(
            id: "\(snapshot.providerId.rawValue)-reset-\(ISO8601DateFormatter().string(from: Date()))",
            title: "\(providerName): window reset",
            body: "Full capacity restored."
        )
    }

    private func fire(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { logger.error("Failed to fire notification '\(id)': \(error)") }
            else { logger.info("Fired notification: \(id)") }
        }
    }

    // MARK: - UserDefaults toggles

    private func isEnabled(provider: ProviderID, metric: String) -> Bool {
        let key = "notify.\(provider.rawValue).\(metric).enabled"
        let stored = UserDefaults.standard.object(forKey: key)
        // Default: all enabled except "reset" which defaults off
        if stored == nil { return metric != "reset" }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func isThresholdEnabled(provider: ProviderID, metric: String, threshold: Double) -> Bool {
        let key = "notify.\(provider.rawValue).\(metric).\(Int(threshold)).enabled"
        let stored = UserDefaults.standard.object(forKey: key)
        if stored == nil { return true }
        return UserDefaults.standard.bool(forKey: key)
    }
}
