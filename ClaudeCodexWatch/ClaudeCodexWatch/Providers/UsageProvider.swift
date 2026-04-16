import Foundation

protocol UsageProvider: Sendable {
    var id: ProviderID { get }
    var displayName: String { get }
    // Must never throw; errors are encoded in the returned snapshot.
    func fetchSnapshot() async -> UsageSnapshot
}
