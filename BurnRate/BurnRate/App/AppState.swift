import Foundation
import OSLog
import Observation
import SwiftData

private let logger = Logger(subsystem: "com.amitkumar.burnrate", category: "AppState")

@Observable
@MainActor
final class AppState {
    let registry = ProviderRegistry()
    let poller: Poller
    let notifier = Notifier()
    private(set) var store: SnapshotStore?
    private let fileWatcher = FileWatcher()

    init() {
        let registry = self.registry
        registry.register(ClaudeCodeProvider())
        self.poller = Poller(registry: registry)

        notifier.requestAuthorization()
        copySampleIfNeeded()

        // Start polling immediately — store may be nil initially, that's OK
        poller.onTick = { [weak self] snapshots in
            guard let self else { return }
            for snapshot in snapshots.values {
                self.store?.append(snapshot)
            }
            self.notifier.evaluate(latest: snapshots)
        }
        poller.start()
        setupFileWatchers()
    }

    /// Call once after the SwiftData container is ready. Safe to call multiple times.
    func configureStore(modelContext: ModelContext) {
        guard store == nil else { return }
        store = SnapshotStore(context: modelContext)
        store?.pruneOlderThan(Date.now.addingTimeInterval(-30 * 24 * 3600))
        logger.info("SnapshotStore configured")
    }

    // MARK: - Private

    private func setupFileWatchers() {
        // Watch the hook output file — fires within milliseconds of Claude Code updating it
        fileWatcher.watch(url: AppSupportPath.claudeLatestJSON) { [weak self] in
            guard let self else { return }
            Task { @MainActor [weak self] in
                await self?.poller.tickProvider(.claudeCode)
            }
        }

    }

    private func copySampleIfNeeded() {
        let dest = AppSupportPath.claudeLatestJSON
        guard !FileManager.default.fileExists(atPath: dest.path) else { return }
        guard let src = Bundle.main.url(forResource: "sample_claude_latest", withExtension: "json") else {
            logger.warning("sample_claude_latest.json not in bundle")
            return
        }
        do {
            try FileManager.default.copyItem(at: src, to: dest)
            logger.info("Copied sample_claude_latest.json to \(AppSupportPath.directoryURL.path)")
        } catch {
            logger.error("Failed to copy sample: \(error)")
        }
    }
}
