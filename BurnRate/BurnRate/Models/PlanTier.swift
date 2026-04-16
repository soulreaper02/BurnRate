import Foundation

enum PlanTier: String, Codable, CaseIterable {
    case go = "go"
    case pro = "pro"
    case business = "business"
    case enterprise = "enterprise"
    case unknown = "unknown"

    var displayName: String {
        switch self {
        case .go: return "Go"
        case .pro: return "Pro"
        case .business: return "Business"
        case .enterprise: return "Enterprise"
        case .unknown: return "Unknown"
        }
    }

    init(rawString: String?) {
        guard let s = rawString else { self = .unknown; return }
        self = PlanTier(rawValue: s) ?? .unknown
    }
}
