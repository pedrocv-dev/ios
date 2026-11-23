import Foundation

/// Use case: find the cheapest stations of a municipality for a fuel type.
///
/// Steps: resolve the municipality name (when needed), fetch the national
/// dataset of stations (cached by the repository), keep the stations of that
/// municipality selling the requested fuel and sort them by price, cheapest
/// first.
struct SearchStationsUseCase: Sendable {
    private let municipalityRepository: any MunicipalityRepository
    private let stationRepository: any GasStationRepository

    init(
        municipalityRepository: any MunicipalityRepository,
        stationRepository: any GasStationRepository
    ) {
        self.municipalityRepository = municipalityRepository
        self.stationRepository = stationRepository
    }

    /// Resolves the query to a municipality and searches its stations.
    func execute(query: String, fuel: FuelType) async throws -> [GasStation] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let matches = try await municipalityRepository.searchMunicipalities(query: trimmed)
        guard let municipality = matches.first else {
            throw StationSearchError.municipalityNotFound(trimmed)
        }
        return try await execute(municipality: municipality, fuel: fuel)
    }

    /// Searches the stations of an already resolved municipality.
    func execute(municipality: Municipality, fuel: FuelType) async throws -> [GasStation] {
        let stations = try await stationRepository.stations()
        return stations
            .filter { $0.municipalityId == municipality.id }
            .compactMap { station -> (GasStation, Double)? in
                guard let price = station.price(for: fuel) else { return nil }
                return (station, price)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }
}
