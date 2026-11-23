import XCTest
@testable import GasFinder

// MARK: - Test doubles

/// URLProtocol that serves canned responses and counts the requests,
/// so tests can assert whether the repository hit the network or the cache.
final class MockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) private static var _requestCount = 0

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _requestCount
    }

    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _handler
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _handler = newValue
        }
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        _handler = nil
        _requestCount = 0
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.recordRequest()
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    private static func recordRequest() {
        lock.lock()
        defer { lock.unlock() }
        _requestCount += 1
    }

    override func stopLoading() {}
}

// MARK: - Tests

final class MineturGasStationRepositoryTests: XCTestCase {
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    private func makeRepository(cache: QueryCache<String, [GasStation]> = QueryCache(ttl: 120)) -> MineturGasStationRepository {
        MineturGasStationRepository(client: MineturClient(session: session), cache: cache)
    }

    private func makeResponse(
        statusCode: Int = 200,
        body: String = MineturGasStationRepositoryTests.stationsJSON,
        delay: TimeInterval = 0
    ) throws -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: MineturClient().baseURL,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        if delay > 0 {
            Thread.sleep(forTimeInterval: delay)
        }
        return (response, Data(body.utf8))
    }

    // MARK: Mapping

    func test_stations_mapsResponseIntoDomainModel() async throws {
        MockURLProtocol.handler = { _ in try self.makeResponse() }
        let repository = makeRepository()

        let stations = try await repository.stations()

        XCTAssertEqual(stations.count, 2)
        let cepsa = try XCTUnwrap(stations.first { $0.brand == "CEPSA" })
        XCTAssertEqual(cepsa.id, "10943")
        XCTAssertEqual(cepsa.municipalityId, "4354")
        XCTAssertEqual(cepsa.address, "PASEO MORET, 7")
        XCTAssertEqual(cepsa.municipality, "Madrid")
        XCTAssertEqual(cepsa.province, "MADRID")
        XCTAssertEqual(cepsa.postalCode, "28008")
        XCTAssertEqual(cepsa.schedule, "L-V: 08:00-21:00; S: 09:00-14:00")
        XCTAssertEqual(try XCTUnwrap(cepsa.latitude), 40.432861, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(cepsa.longitude), -3.724194, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(cepsa.dieselPrice), 1.909, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(cepsa.gasoline95Price), 1.684, accuracy: 0.000001)

        // Station without prices for these fuels.
        let shell = try XCTUnwrap(stations.first { $0.brand == "SHELL" })
        XCTAssertNil(shell.dieselPrice)
        XCTAssertNil(shell.gasoline95Price)
    }

    func test_stations_nonSuccessStatus_throws() async {
        MockURLProtocol.handler = { _ in try self.makeResponse(statusCode: 500) }
        let repository = makeRepository()

        do {
            _ = try await repository.stations()
            XCTFail("Expected a failure for a 500 response")
        } catch let error as MineturError {
            XCTAssertEqual(error, .unexpectedStatusCode(500))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: Cache behavior

    func test_repeatedLookup_hitsCacheWithoutSecondNetworkCall() async throws {
        MockURLProtocol.handler = { _ in try self.makeResponse() }
        let repository = makeRepository()

        let first = try await repository.stations()
        let second = try await repository.stations()

        XCTAssertEqual(first, second)
        XCTAssertEqual(MockURLProtocol.requestCount, 1, "Second lookup must be served from cache")
    }

    func test_expiredCache_refetchesFromNetworkAndRefreshes() async throws {
        let clock = FakeClock()
        let cache = QueryCache<String, [GasStation]>(ttl: 120, now: clock.provider)
        MockURLProtocol.handler = { _ in try self.makeResponse() }
        let repository = makeRepository(cache: cache)

        _ = try await repository.stations()
        clock.advance(by: 121) // TTL expired
        _ = try await repository.stations()

        XCTAssertEqual(MockURLProtocol.requestCount, 2, "Expired cache must trigger a network refetch")
    }

    func test_freshCacheWithinTTL_doesNotRefetch() async throws {
        let clock = FakeClock()
        let cache = QueryCache<String, [GasStation]>(ttl: 120, now: clock.provider)
        MockURLProtocol.handler = { _ in try self.makeResponse() }
        let repository = makeRepository(cache: cache)

        _ = try await repository.stations()
        clock.advance(by: 60)
        _ = try await repository.stations()

        XCTAssertEqual(MockURLProtocol.requestCount, 1)
    }

    // MARK: Cancellation

    func test_cancellation_propagatesFromNetworkRequest() async throws {
        MockURLProtocol.handler = { _ in try self.makeResponse(delay: 2) }
        let repository = makeRepository()

        let task = Task {
            try await repository.stations()
        }
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected the cancelled lookup to throw")
        } catch {
            XCTAssertTrue(error is CancellationError, "Unexpected error: \(error)")
        }
    }
}

// MARK: - Fixtures

private extension MineturGasStationRepositoryTests {
    static let stationsJSON = """
    {
      "Fecha": "19/11/2026 12:20:38",
      "ListaEESSPrecio": [
        {
          "C.P.": "28008",
          "Dirección": "PASEO MORET, 7",
          "Horario": "L-V: 08:00-21:00; S: 09:00-14:00",
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
        },
        {
          "C.P.": "28001",
          "Dirección": "CALLE SERRANO, 14",
          "Horario": "L-D: 24H",
          "Latitud": "40,425700",
          "Localidad": "MADRID",
          "Longitud (WGS84)": "-3,688800",
          "Municipio": "Madrid",
          "Precio Gasoleo A": "",
          "Precio Gasolina 95 E5": "",
          "Provincia": "MADRID",
          "Rótulo": "SHELL",
          "IDEESS": "10944",
          "IDMunicipio": "4354",
          "IDProvincia": "28"
        }
      ],
      "Nota": "Archivo de todos los productos en todas las estaciones de servicio.",
      "ResultadoConsulta": "OK"
    }
    """
}
