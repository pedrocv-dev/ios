//
// SearchStationsUseCaseTests.swift
//  GasFinder
//
//  Created by pedro.candon.local on 20/11/2026.
//

import XCTest
@testable import GasFinder

// MARK: - Test doubles
private actor MockMunicipalityRepository: MunicipalityRepository {
    private let matches: [Municipality]
    private(set) var queries: [String] = []

    init(matches: [Municipality] = []) {
        self.matches = matches
    }

    func searchMunicipalities(query: String) async throws -> [Municipality] {
        queries.append(query)
        return matches
    }
}

private actor MockGasStationRepository: GasStationRepository {
    private let stations: [GasStation]
    private let error: (any Error)?
    private(set) var fetchCount = 0

    init(stations: [GasStation] = [], error: (any Error)? = nil) {
        self.stations = stations
        self.error = error
    }

    func stations() async throws -> [GasStation] {
        fetchCount += 1
        try Task.checkCancellation()
        if let error { throw error }
        return stations
    }
}

// MARK: - Tests
final class SearchStationsUseCaseTests: XCTestCase {
    private let madrid = Municipality(id: "4354", name: "Madrid", province: "MADRID")
    private let stations = [
        GasStation(id: "1", brand: "CEPSA", address: "Calle A", municipalityId: "4354",
                   municipality: "Madrid", province: "MADRID", locality: nil, postalCode: nil,
                   schedule: nil, latitude: nil, longitude: nil,
                   dieselPrice: 1.909, gasoline95Price: 1.684),
        GasStation(id: "2", brand: "REPSOL", address: "Calle B", municipalityId: "4354",
                   municipality: "Madrid", province: "MADRID", locality: nil, postalCode: nil,
                   schedule: nil, latitude: nil, longitude: nil,
                   dieselPrice: 1.799, gasoline95Price: nil),
        GasStation(id: "3", brand: "SHELL", address: "Calle C", municipalityId: "4354",
                   municipality: "Madrid", province: "MADRID", locality: nil, postalCode: nil,
                   schedule: nil, latitude: nil, longitude: nil,
                   dieselPrice: 1.850, gasoline95Price: 1.599),
        GasStation(id: "4", brand: "OTRA", address: "Calle D", municipalityId: "9999",
                   municipality: "Otro", province: "OTRA", locality: nil, postalCode: nil,
                   schedule: nil, latitude: nil, longitude: nil,
                   dieselPrice: 1.000, gasoline95Price: 1.000),
    ]

    func test_execute_filtersByMunicipalityAndSortsByPrice() async throws {
        let municipalityRepository = MockMunicipalityRepository(matches: [madrid])
        let stationRepository = MockGasStationRepository(stations: stations)
        let useCase = SearchStationsUseCase(
            municipalityRepository: municipalityRepository,
            stationRepository: stationRepository
        )

        let results = try await useCase.execute(query: "madrid", fuel: .diesel)

        XCTAssertEqual(results.map(\.id), ["2", "3", "1"])
        let queries = await municipalityRepository.queries
        XCTAssertEqual(queries, ["madrid"])
    }

    func test_execute_gasoline_filtersOutStationsWithoutGasoline() async throws {
        let municipalityRepository = MockMunicipalityRepository(matches: [madrid])
        let stationRepository = MockGasStationRepository(stations: stations)
        let useCase = SearchStationsUseCase(
            municipalityRepository: municipalityRepository,
            stationRepository: stationRepository
        )

        let results = try await useCase.execute(query: "Madrid", fuel: .gasoline)

        XCTAssertEqual(results.map(\.id), ["3", "1"])
    }

    func test_execute_resolvedMunicipality_filtersById() async throws {
        let municipalityRepository = MockMunicipalityRepository(matches: [madrid])
        let stationRepository = MockGasStationRepository(stations: stations)
        let useCase = SearchStationsUseCase(
            municipalityRepository: municipalityRepository,
            stationRepository: stationRepository
        )

        let results = try await useCase.execute(municipality: madrid, fuel: .gasoline)

        XCTAssertEqual(results.map(\.id), ["3", "1"])
        let queries = await municipalityRepository.queries
        XCTAssertTrue(queries.isEmpty, "Resolved municipalities must not be re-resolved")
    }

    func test_execute_emptyQuery_returnsEmptyWithoutCalls() async {
        let municipalityRepository = MockMunicipalityRepository()
        let stationRepository = MockGasStationRepository()
        let useCase = SearchStationsUseCase(
            municipalityRepository: municipalityRepository,
            stationRepository: stationRepository
        )

        let results = try? await useCase.execute(query: "   ", fuel: .diesel)

        XCTAssertEqual(results, [])
        let queries = await municipalityRepository.queries
        XCTAssertTrue(queries.isEmpty)
        let fetchCount = await stationRepository.fetchCount
        XCTAssertEqual(fetchCount, 0)
    }

    func test_execute_unknownMunicipality_throwsMunicipalityNotFound() async {
        let municipalityRepository = MockMunicipalityRepository(matches: [])
        let stationRepository = MockGasStationRepository()
        let useCase = SearchStationsUseCase(
            municipalityRepository: municipalityRepository,
            stationRepository: stationRepository
        )

        do {
            _ = try await useCase.execute(query: "Atlántida", fuel: .diesel)
            XCTFail("Expected municipalityNotFound")
        } catch StationSearchError.municipalityNotFound(let name) {
            XCTAssertEqual(name, "Atlántida")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_execute_propagatesRepositoryError() async {
        struct StubError: Error {}
        let municipalityRepository = MockMunicipalityRepository(matches: [madrid])
        let stationRepository = MockGasStationRepository(error: StubError())
        let useCase = SearchStationsUseCase(
            municipalityRepository: municipalityRepository,
            stationRepository: stationRepository
        )

        do {
            _ = try await useCase.execute(query: "madrid", fuel: .diesel)
            XCTFail("Expected the repository error to propagate")
        } catch {
            XCTAssertTrue(error is StubError)
        }
    }
}
