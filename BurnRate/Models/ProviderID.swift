import Foundation

enum ProviderID: String, Codable, CaseIterable, Identifiable {
    case claudeCode = "claudeCode"

    var id: String { rawValue }
}
