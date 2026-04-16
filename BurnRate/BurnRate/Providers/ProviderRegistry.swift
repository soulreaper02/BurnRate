import Foundation
import Observation

@Observable
final class ProviderRegistry {
    private(set) var providers: [any UsageProvider] = []

    func register(_ provider: any UsageProvider) {
        providers.append(provider)
    }
}
