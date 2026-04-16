import Foundation

enum ProviderID: String, Codable, CaseIterable, Identifiable {
    case claudeCode = "claudeCode"
    case codex = "codex"

    var id: String { rawValue }
}
