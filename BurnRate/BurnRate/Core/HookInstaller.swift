import Foundation
import OSLog

private let logger = Logger(subsystem: "com.amitkumar.burnrate", category: "HookInstaller")

enum InstallMode {
    case fresh
    case replace
    case chain(existing: String)
}

struct StatuslineConfig {
    let command: String
}

enum HookInstallerError: LocalizedError {
    case settingsFileCorrupt
    case backupFailed(Error)
    case writeFailed(Error)
    case hookScriptMissing

    var errorDescription: String? {
        switch self {
        case .settingsFileCorrupt: return "settings.json could not be parsed as JSON"
        case .backupFailed(let e): return "Backup failed: \(e.localizedDescription)"
        case .writeFailed(let e): return "Write failed: \(e.localizedDescription)"
        case .hookScriptMissing: return "statusline-hook.sh not found in app bundle"
        }
    }
}

struct HookInstaller {
    private static let settingsURL: URL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".claude/settings.json")

    // Installed next to settings.json — no spaces in path, shell-safe
    private static let installedHookURL: URL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".claude/ccw-hook.sh")

    // MARK: - Public API

    func currentStatuslineConfig() -> StatuslineConfig? {
        guard let data = try? Data(contentsOf: Self.settingsURL),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cmd = obj["statusLine"] as? String else { return nil }
        return StatuslineConfig(command: cmd)
    }

    /// Returns a preview of what settings.json will look like after install.
    func previewDiff(mode: InstallMode) -> (before: String, after: String) {
        let current = (try? String(contentsOf: Self.settingsURL)) ?? "{}"
        let hookCmd = hookCommand(mode: mode)
        var obj = (try? JSONSerialization.jsonObject(with: Data(current.utf8)) as? [String: Any]) ?? [:]
        obj["statusLine"] = hookCmd
        let afterData = (try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])) ?? Data()
        let after = String(data: afterData, encoding: .utf8) ?? "{}"
        return (before: current, after: after)
    }

    func install(mode: InstallMode) throws {
        try copyHookScriptIfNeeded()
        try backupSettings()
        try writeSettings(mode: mode)
    }

    func uninstall() throws {
        guard FileManager.default.fileExists(atPath: Self.settingsURL.path) else { return }
        try backupSettings()

        let data = try Data(contentsOf: Self.settingsURL)
        guard var obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HookInstallerError.settingsFileCorrupt
        }

        // If we chained, restore the original command
        let existing = obj["statusLine"] as? String ?? ""
        if existing.contains("CCW_CHAIN_CMD=") {
            // Extract chain target from: CCW_CHAIN_CMD='...' /path/to/hook.sh
            // Format: CCW_CHAIN_CMD='<original>' <hookpath>
            if let chainMatch = existing.range(of: #"CCW_CHAIN_CMD='([^']+)'"#, options: .regularExpression) {
                let inner = String(existing[chainMatch])
                let original = inner
                    .replacingOccurrences(of: "CCW_CHAIN_CMD='", with: "")
                    .replacingOccurrences(of: "'", with: "")
                obj["statusLine"] = original
            } else {
                obj.removeValue(forKey: "statusLine")
            }
        } else {
            obj.removeValue(forKey: "statusLine")
        }

        try writeJSON(obj, to: Self.settingsURL)
        logger.info("Uninstalled hook from settings.json")
    }

    // MARK: - Private

    private func hookCommand(mode: InstallMode) -> String {
        let hookPath = Self.installedHookURL.path
        switch mode {
        case .fresh, .replace:
            return hookPath
        case .chain(let existing):
            let escaped = existing.replacingOccurrences(of: "'", with: "'\\''")
            return "CCW_CHAIN_CMD='\(escaped)' \(hookPath)"
        }
    }

    private func copyHookScriptIfNeeded() throws {
        let fm = FileManager.default
        let dest = Self.installedHookURL
        if fm.fileExists(atPath: dest.path) {
            // Always update to latest version
            try? fm.removeItem(at: dest)
        }
        guard let src = Bundle.main.url(forResource: "statusline-hook", withExtension: "sh") else {
            throw HookInstallerError.hookScriptMissing
        }
        try fm.copyItem(at: src, to: dest)
        // Make executable
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)
        logger.info("Installed hook script to \(dest.path)")
    }

    private func backupSettings() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: Self.settingsURL.path) else { return }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let ts = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backup = Self.settingsURL.deletingLastPathComponent()
            .appendingPathComponent("settings.json.ccw-backup-\(ts)")
        do {
            try fm.copyItem(at: Self.settingsURL, to: backup)
            logger.info("Backed up settings.json to \(backup.lastPathComponent)")
        } catch {
            throw HookInstallerError.backupFailed(error)
        }
    }

    private func writeSettings(mode: InstallMode) throws {
        let fm = FileManager.default
        var obj: [String: Any] = [:]

        if fm.fileExists(atPath: Self.settingsURL.path) {
            let data = try Data(contentsOf: Self.settingsURL)
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw HookInstallerError.settingsFileCorrupt
            }
            obj = parsed
        }

        obj["statusLine"] = hookCommand(mode: mode)
        try writeJSON(obj, to: Self.settingsURL)
        logger.info("Wrote settings.json with statusLine key")
    }

    private func writeJSON(_ obj: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
        let tmp = url.deletingLastPathComponent().appendingPathComponent(".settings.tmp.\(ProcessInfo.processInfo.processIdentifier)")
        do {
            try data.write(to: tmp, options: .atomic)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
        } catch {
            try? FileManager.default.removeItem(at: tmp)
            throw HookInstallerError.writeFailed(error)
        }
    }
}
