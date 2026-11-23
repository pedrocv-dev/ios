import Foundation

/// Domain model for a Spanish municipality (municipio).
struct Municipality: Identifiable, Hashable, Sendable {
    /// MINETUR municipality identifier used by the prices API.
    let id: String
    let name: String
    let province: String
}

/// Errors that can prevent a station search from being executed.
enum StationSearchError: Error, Equatable {
    case municipalityNotFound(String)
}
