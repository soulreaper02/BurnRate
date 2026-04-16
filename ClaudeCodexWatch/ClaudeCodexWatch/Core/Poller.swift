import Foundation
import AppKit
import OSLog
import Observation

private let logger = Logger(subsystem: "com.amitkumar.ClaudeCodexWatch", category: "Poller")

@Observable
@MainActor
final class Poller {
    private(set) var latest: [ProviderID: UsageSnapshot] = [:]
    private var pollingTask: Task<Void, Never>?
    private var registry: ProviderRegistry

    /// Called after every tick with the fresh snapshots. More reliable than withObservationTracking.
    var onTick: (([ProviderID: UsageSnapshot]) -> Void)?

    init(registry: ProviderRegistry) {
        self.registry = registry
    }

    func start() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            await self?.tick()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(30))
                } catch {
                    break
                }
                await self?.tick()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                logger.info("Wake from sleep — polling now")
                await self?.tick()
            }
        }
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Immediately refresh a single provider (e.g. when its source file changes).
    func tickProvider(_ id: ProviderID) async {
        guard let provider = registry.providers.first(where: { $0.id == id }) else { return }
        logger.info("[\(id.rawValue, privacy: .public)] instant refresh triggered by file change")
        let snapshot = await provider.fetchSnapshot()
        latest[snapshot.providerId] = snapshot
        onTick?(latest)
    }

    /// Manual refresh — called by the refresh button in the popover.
    func refreshNow() {
        Task { await tick() }
    }

    // MARK: - Private

    private func tick() async {
        logger.info("Polling \(self.registry.providers.count) providers")
        await withTaskGroup(of: UsageSnapshot.self) { group in
            for provider in registry.providers {
                group.addTask {
                    await provider.fetchSnapshot()
                }
            }
            for await snapshot in group {
                latest[snapshot.providerId] = snapshot
                logger.info("[\(snapshot.providerId.rawValue)] session=\(snapshot.sessionUsedPercent.map { String(format: "%.1f%%", $0) } ?? "—") weekly=\(snapshot.weeklyUsedPercent.map { String(format: "%.1f%%", $0) } ?? "—")")
            }
        }
        onTick?(latest)
    }
}
