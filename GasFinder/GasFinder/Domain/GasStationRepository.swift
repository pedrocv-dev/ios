import Foundation

/// Abstraction over the data source of gas station prices.
protocol GasStationRepository: Sendable {
    /// Returns all stations of Spain with their current prices. The
    /// implementation is expected to cache the dataset (it is large), so
    /// repeated calls within the TTL do not hit the network. Cancellation
    /// of the caller's task is propagated down to the network layer.
    func stations() async throws -> [GasStation]
}
