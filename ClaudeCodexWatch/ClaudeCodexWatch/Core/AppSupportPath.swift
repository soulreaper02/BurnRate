import Foundation
import OSLog

private let logger = Logger(subsystem: "com.amitkumar.ClaudeCodexWatch", category: "AppSupportPath")

enum AppSupportPath {
    static let directoryURL: URL = {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("ClaudeCodexWatch", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                logger.error("Failed to create app support dir: \(error)")
            }
        }
        return dir
    }()

    static var claudeLatestJSON: URL {
        directoryURL.appendingPathComponent("claude_latest.json")
    }
}
