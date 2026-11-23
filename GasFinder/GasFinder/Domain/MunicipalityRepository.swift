import Foundation

/// Abstraction over the municipality data source (name → municipality).
/// The Domain layer never knows where the list comes from.
protocol MunicipalityRepository: Sendable {
    /// Returns the municipalities whose name matches the query, best
    /// matches first (exact match, then prefix, then containment).
    func searchMunicipalities(query: String) async throws -> [Municipality]
}
