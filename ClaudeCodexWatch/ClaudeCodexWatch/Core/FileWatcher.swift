import Foundation
import OSLog

private let logger = Logger(subsystem: "com.amitkumar.ClaudeCodexWatch", category: "FileWatcher")

/// Watches files and directories for changes using kqueue via DispatchSource.
/// Much lower latency than polling — picks up changes within milliseconds.
final class FileWatcher {
    private struct Entry {
        let source: DispatchSourceFileSystemObject
        let fd: Int32
    }

    private var entries: [Entry] = []

    /// Watch a file or directory at `url`. Calls `handler` on the main queue
    /// whenever a write, rename, or delete event is detected.
    /// If the path doesn't exist yet, the watch is silently skipped.
    func watch(url: URL, handler: @escaping () -> Void) {
        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else {
            logger.warning("FileWatcher: cannot open \(url.path, privacy: .public) (path may not exist yet)")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        source.setEventHandler {
            logger.info("FileWatcher: change detected in \(url.lastPathComponent, privacy: .public)")
            handler()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        entries.append(Entry(source: source, fd: fd))
        logger.info("FileWatcher: watching \(url.path, privacy: .public)")
    }

    func stopAll() {
        entries.forEach { $0.source.cancel() }
        entries.removeAll()
    }
}
