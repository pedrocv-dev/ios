//
// MineturMunicipalityRepositoryTests.swift
//  GasFinder
//
//  Created by pedro.candon.local on 23/11/2026.
//

import XCTest
@testable import GasFinder

final class MineturMunicipalityRepositoryTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    /// Serves the listing endpoints from fixtures keyed by request path.
    private func installFixtures() {
        MockURLProtocol.handler = { request in
            let path = request.url!.path
            let body: String
            switch path {
            case let p where p.hasSuffix("Provincias"):
                body = Self.provincesJSON
            case let p where p.contains("MunicipiosPorProvincia/28"):
                body = Self.madridMunicipalitiesJSON
            case let p where p.contains("MunicipiosPorProvincia/01"):
                body = Self.alavaMunicipalitiesJSON
            default:
                body = "[]"
            }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data(body.utf8))
        }
    }

    private func makeRepository(
        cache: QueryCache<String, [Municipality]> = QueryCache(ttl: 300)
    ) -> MineturMunicipalityRepository {
        MineturMunicipalityRepository(
            client: MineturClient(session: session),
            cache: cache
        )
    }

    func test_resolvesExactMunicipalityNameFromTheAPI() async throws {
        installFixtures()
        let repository = makeRepository()

        let matches = try await repository.searchMunicipalities(query: "  madrid ")

        XCTAssertEqual(matches.map(\.id), ["4354"])
        XCTAssertEqual(matches.first?.province, "MADRID")
    }

    func test_noExactMunicipalityName_fallsBackToExactProvinceName() async throws {
        installFixtures()
        let repository = makeRepository()

        let matches = try await repository.searchMunicipalities(query: "álava")

        XCTAssertEqual(matches.map(\.name), ["Amurrio", "Vitoria-Gasteiz"])
    }

    func test_noMatchAnywhere_returnsEmpty() async throws {
        installFixtures()
        let repository = makeRepository()

        let matches = try await repository.searchMunicipalities(query: "Atlántida")

        XCTAssertTrue(matches.isEmpty)
    }

    func test_municipalityList_isFetchedOnceAndCached() async throws {
        installFixtures()
        let repository = makeRepository()

        _ = try await repository.searchMunicipalities(query: "madrid")
        let firstCount = MockURLProtocol.requestCount
        _ = try await repository.searchMunicipalities(query: "vitoria-gasteiz")

        XCTAssertEqual(
            MockURLProtocol.requestCount, firstCount,
            "Repeated searches must reuse the cached municipality list"
        )
    }

    func test_expiredCache_refetchesMunicipalityList() async throws {
        installFixtures()
        let clock = FakeClock()
        let repository = makeRepository(cache: QueryCache(ttl: 300, now: clock.provider))

        _ = try await repository.searchMunicipalities(query: "madrid")
        let firstCount = MockURLProtocol.requestCount
        clock.advance(by: 301)
        _ = try await repository.searchMunicipalities(query: "madrid")

        XCTAssertGreaterThan(MockURLProtocol.requestCount, firstCount)
    }

    func test_matchingIgnoresCaseAndDiacritics_onlyExactMatches() async throws {
        installFixtures()
        let repository = makeRepository()

        let partial = try await repository.searchMunicipalities(query: "vitor")
        XCTAssertTrue(partial.isEmpty, "Matching must be exact, not partial")

        let accented = try await repository.searchMunicipalities(query: "VITORIA-GASTEIZ")
        XCTAssertEqual(accented.map(\.name), ["Vitoria-Gasteiz"])
    }
}

// MARK: - Fixtures
private extension MineturMunicipalityRepositoryTests {
    static let provincesJSON = """
    [
      {"IDPovincia": "01", "Provincia": "ÁLAVA", "IDCCAA": "16", "CCAA": "País Vasco"},
      {"IDPovincia": "28", "Provincia": "MADRID", "IDCCAA": "13", "CCAA": "Madrid"}
    ]
    """

    static let madridMunicipalitiesJSON = """
    [
      {"IDMunicipio": "4276", "Municipio": "Acebeda (La)", "Provincia": "MADRID"},
      {"IDMunicipio": "4354", "Municipio": "Madrid", "Provincia": "MADRID"},
      {"IDMunicipio": "4295", "Municipio": "Villa del Prado", "Provincia": "MADRID"}
    ]
    """

    static let alavaMunicipalitiesJSON = """
    [
      {"IDMunicipio": "1008", "Municipio": "Amurrio", "Provincia": "ÁLAVA"},
      {"IDMunicipio": "1059", "Municipio": "Vitoria-Gasteiz", "Provincia": "ÁLAVA"}
    ]
    """
}
