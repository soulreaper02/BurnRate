import Foundation
import OSLog
import Observation

private let logger = Logger(subsystem: "com.amitkumar.burnrate", category: "AppState")

@Observable
@MainActor
final class AppState {
    let registry = ProviderRegistry()
    let poller: Poller
    let notifier = Notifier()
    let statusMonitor = StatusMonitor()
    private let fileWatcher = FileWatcher()

    init() {
        let registry = self.registry
        registry.register(ClaudeCodeProvider())
        self.poller = Poller(registry: registry)

        notifier.requestAuthorization()

        poller.onTick = { [weak self] snapshots in
            guard let self else { return }
            self.notifier.evaluate(latest: snapshots)
        }
        poller.start()
        statusMonitor.start()
        setupFileWatchers()
    }

    // MARK: - Private

    private func setupFileWatchers() {
        let projectsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".claude/projects")
        fileWatcher.watch(url: projectsDir) { [weak self] in
            guard let self else { return }
            Task { @MainActor [weak self] in
                await self?.poller.tickProvider(.claudeCode)
            }
        }
    }
}
