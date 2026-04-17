import Foundation
import OSLog
import Observation

// MARK: - Models

enum StatusIndicator: String, Decodable {
    case none       = "none"
    case minor      = "minor"
    case major      = "major"
    case critical   = "critical"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = StatusIndicator(rawValue: raw) ?? .unknown
    }
}

struct ClaudeIncident: Identifiable, Decodable {
    let id: String
    let name: String
    let status: String          // resolved / monitoring / identified / investigating
    let impact: String          // none / minor / major / critical
    let createdAt: Date
    let updatedAt: Date
    let incidentUpdates: [IncidentUpdate]

    var latestUpdate: IncidentUpdate? { incidentUpdates.first }

    enum CodingKeys: String, CodingKey {
        case id, name, status, impact
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case incidentUpdates = "incident_updates"
    }

    struct IncidentUpdate: Decodable {
        let body: String
        let status: String
        let createdAt: Date
        enum CodingKeys: String, CodingKey {
            case body, status
            case createdAt = "created_at"
        }
    }
}

// MARK: - Monitor

private let logger = Logger(subsystem: "com.amitkumar.burnrate", category: "StatusMonitor")

@Observable
@MainActor
final class StatusMonitor {
    private(set) var indicator: StatusIndicator = .none
    private(set) var statusDescription: String = "Checking…"
    private(set) var incidents: [ClaudeIncident] = []
    private(set) var lastFetchedAt: Date? = nil

    private var task: Task<Void, Never>?

    private static let statusURL    = URL(string: "https://status.claude.com/api/v2/status.json")!
    private static let incidentsURL = URL(string: "https://status.claude.com/api/v2/incidents.json")!
    private static let pollInterval: Duration = .seconds(5 * 60) // every 5 min

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func start() {
        task?.cancel()
        task = Task { [weak self] in
            await self?.fetch()
            while !Task.isCancelled {
                do { try await Task.sleep(for: Self.pollInterval) } catch { break }
                await self?.fetch()
            }
        }
    }

    func fetchNow() {
        Task { await fetch() }
    }

    // MARK: - Private

    private func fetch() async {
        async let statusData   = Self.get(Self.statusURL)
        async let incidentData = Self.get(Self.incidentsURL)

        let (sd, id) = await (statusData, incidentData)

        if let sd,
           let parsed = try? Self.decoder.decode(StatusResponse.self, from: sd) {
            indicator         = parsed.status.indicator
            statusDescription = parsed.status.description
        }

        if let id,
           let parsed = try? Self.decoder.decode(IncidentsResponse.self, from: id) {
            // Most recent first; cap at 5
            incidents = Array(parsed.incidents.prefix(5))
        }

        lastFetchedAt = Date()
        logger.info("Status: \(self.statusDescription, privacy: .public) — \(self.incidents.count) incidents")
    }

    private static func get(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("BurnRate/1.0", forHTTPHeaderField: "User-Agent")
        return try? await URLSession.shared.data(for: request).0
    }

    // MARK: - Decodable wrappers

    private struct StatusResponse: Decodable {
        struct Status: Decodable {
            let indicator: StatusIndicator
            let description: String
        }
        let status: Status
    }

    private struct IncidentsResponse: Decodable {
        let incidents: [ClaudeIncident]
    }
}
