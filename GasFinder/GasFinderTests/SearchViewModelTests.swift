//
// SearchViewModelTests.swift
//  GasFinder
//
//  Created by pedro.candon.local on 23/11/2026.
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

    /// Mirrors the real repository: exact municipality or province name.
    func searchMunicipalities(query: String) async throws -> [Municipality] {
        queries.append(query)
        let normalized = MineturMunicipalityRepository.normalize(query)
        return matches.filter {
            MineturMunicipalityRepository.normalize($0.name) == normalized
                || MineturMunicipalityRepository.normalize($0.province) == normalized
        }
    }
}

/// Station repository whose first lookup can be made slow enough to be
/// cancelled by the ViewModel. Records cancellation and how many times the
/// network would have been hit.
private actor SlowGasStationRepository: GasStationRepository {
    private let slowFirstFetch: Bool
    private(set) var fetchCount = 0
    private(set) var observedCancellation = false

    init(slowFirstFetch: Bool = false) {
        self.slowFirstFetch = slowFirstFetch
    }

    func stations() async throws -> [GasStation] {
        fetchCount += 1
        if slowFirstFetch && fetchCount == 1 {
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                observedCancellation = true
                throw CancellationError()
            }
        }
        return [GasStation(
            id: "1", brand: "REPSOL", address: "Calle 1",
            municipalityId: "4354", municipality: "X", province: "P",
            locality: nil, postalCode: nil, schedule: nil,
            latitude: nil, longitude: nil,
            dieselPrice: 1.500, gasoline95Price: 1.600
        )]
    }

    func hasObservedCancellation() -> Bool {
        observedCancellation
    }
}

private actor FailingGasStationRepository: GasStationRepository {
    let error: Error
    init(error: Error) { self.error = error }

    func stations() async throws -> [GasStation] {
        throw error
    }
}

@MainActor
final class SearchViewModelTests: XCTestCase {
    private let madrid = Municipality(id: "4354", name: "Madrid", province: "MADRID")

    private func makeViewModel(
        municipalityRepository: any MunicipalityRepository,
        stationRepository: any GasStationRepository
    ) -> SearchViewModel {
        SearchViewModel(
            searchStations: SearchStationsUseCase(
                municipalityRepository: municipalityRepository,
                stationRepository: stationRepository
            )
        )
    }

    func test_submitSearch_resolvesMunicipalityAndShowsResults() async {
        let municipalityRepository = MockMunicipalityRepository(matches: [madrid])
        let stationRepository = SlowGasStationRepository()
        let viewModel = makeViewModel(
            municipalityRepository: municipalityRepository,
            stationRepository: stationRepository
        )

        viewModel.municipalityQuery = "madrid"
        viewModel.submitSearch()
        await waitForIdle(viewModel)

        guard case .results(let stations) = viewModel.state else {
            return XCTFail("Expected results, got \(String(describing: viewModel.state))")
        }
        XCTAssertEqual(stations.map(\.id), ["1"])
        XCTAssertEqual(stations.first?.price(for: .diesel), 1.500)
    }

    func test_submitSearch_unknownMunicipality_showsFailure() async {
        let municipalityRepository = MockMunicipalityRepository(matches: [])
        let stationRepository = SlowGasStationRepository()
        let viewModel = makeViewModel(
            municipalityRepository: municipalityRepository,
            stationRepository: stationRepository
        )

        viewModel.municipalityQuery = "Atlántida"
        viewModel.submitSearch()
        await waitForIdle(viewModel)

        XCTAssertEqual(viewModel.state, .failure("No se encontró el municipio «Atlántida»."))
    }

    func test_submitSearch_emptyQuery_resetsToIdle() async {
        let municipalityRepository = MockMunicipalityRepository()
        let stationRepository = SlowGasStationRepository()
        let viewModel = makeViewModel(
            municipalityRepository: municipalityRepository,
            stationRepository: stationRepository
        )

        viewModel.municipalityQuery = "   "
        viewModel.submitSearch()

        XCTAssertEqual(viewModel.state, .idle)
        let fetchCount = await stationRepository.fetchCount
        XCTAssertEqual(fetchCount, 0)
    }

    func test_typingDoesNotTriggerSearch() async {
        let municipalityRepository = MockMunicipalityRepository(matches: [madrid])
        let stationRepository = SlowGasStationRepository()
        let viewModel = makeViewModel(
            municipalityRepository: municipalityRepository,
            stationRepository: stationRepository
        )

        viewModel.municipalityQuery = "madrid"
        await Task.yield()

        XCTAssertEqual(viewModel.state, .idle, "Typing must not start a search")
        let fetchCount = await stationRepository.fetchCount
        XCTAssertEqual(fetchCount, 0, "Typing must not hit the repository")
    }

    func test_newSearch_cancelsPreviousOne_andOnlyLatestResultsAreShown() async {
        let municipalityRepository = MockMunicipalityRepository(matches: [
            madrid,
            Municipality(id: "9999", name: "Slowtown", province: "SLOW"),
        ])
        let stationRepository = SlowGasStationRepository(slowFirstFetch: true)
        let viewModel = makeViewModel(
            municipalityRepository: municipalityRepository,
            stationRepository: stationRepository
        )

        viewModel.municipalityQuery = "Slowtown"
        viewModel.submitSearch()
        await Task.yield()
        XCTAssertEqual(viewModel.state, .loading)

        viewModel.municipalityQuery = "madrid"
        viewModel.submitSearch()
        await waitForIdle(viewModel)

        guard case .results(let stations) = viewModel.state else {
            return XCTFail("Expected results, got \(String(describing: viewModel.state))")
        }
        XCTAssertEqual(stations.map(\.id), ["1"], "Results of a superseded search must never be shown")

        var cancelled = await stationRepository.hasObservedCancellation()
        let deadline = Date().addingTimeInterval(2)
        while !cancelled && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(10))
            cancelled = await stationRepository.hasObservedCancellation()
        }
        XCTAssertTrue(cancelled, "The in-flight request must be cancelled")
    }

    func test_fuelChange_refiltersWithoutSecondNetworkFetch() async throws {
        MockURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { _ in
            (HTTPURLResponse(
                url: MineturClient().baseURL,
                statusCode: 200, httpVersion: nil, headerFields: nil
            )!, Data(Self.stationsFixture.utf8))
        }
        let stationRepository = MineturGasStationRepository(
            client: MineturClient(session: URLSession(configuration: configuration))
        )
        let municipalityRepository = MockMunicipalityRepository(matches: [madrid])
        let viewModel = makeViewModel(
            municipalityRepository: municipalityRepository,
            stationRepository: stationRepository
        )

        viewModel.municipalityQuery = "madrid"
        viewModel.submitSearch()
        await waitForIdle(viewModel)

        viewModel.fuel = .gasoline
        await waitForIdle(viewModel)

        guard case .results(let stations) = viewModel.state else {
            return XCTFail("Expected results after fuel change, got \(String(describing: viewModel.state))")
        }
        XCTAssertFalse(stations.isEmpty)
        XCTAssertTrue(stations.allSatisfy { $0.gasoline95Price != nil })
        XCTAssertEqual(MockURLProtocol.requestCount, 1, "Fuel change must reuse the cached stations")
    }

    // MARK: Helpers
    private func waitForIdle(_ viewModel: SearchViewModel, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while viewModel.state == .loading && Date() < deadline {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(10))
        }
    }
}

// MARK: - Fixtures
private extension SearchViewModelTests {
    static let stationsFixture = """
    {
      "Fecha": "19/11/2026 12:20:38",
      "ListaEESSPrecio": [
        {
          "C.P.": "28008",
          "Dirección": "PASEO MORET, 7",
          "Horario": "L-V: 08:00-21:00",
          "Latitud": "40,432861",
          "Localidad": "MADRID",
          "Longitud (WGS84)": "-3,724194",
          "Municipio": "Madrid",
          "Precio Gasoleo A": "1,909",
          "Precio Gasolina 95 E5": "1,684",
          "Provincia": "MADRID",
          "Rótulo": "CEPSA",
          "IDEESS": "10943",
          "IDMunicipio": "4354",
          "IDProvincia": "28"
        }
      ],
      "Nota": "",
      "ResultadoConsulta": "OK"
    }
    """
}
