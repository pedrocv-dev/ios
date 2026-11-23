import Foundation

enum MineturError: Error, Equatable {
    case invalidURL
    case unexpectedStatusCode(Int)
}

/// DTO for one station of the MINETUR "Estaciones Terrestres" response.
/// Field names match the API exactly (Spanish, with spaces and accents).
private struct StationDTO: Decodable {
    let id: String
    let municipalityId: String
    let brand: String
    let address: String
    let municipality: String
    let province: String
    let locality: String?
    let postalCode: String?
    let schedule: String?
    let latitude: String?
    let longitude: String?
    let dieselPrice: String?
    let gasoline95Price: String?

    enum CodingKeys: String, CodingKey {
        case id = "IDEESS"
        case municipalityId = "IDMunicipio"
        case brand = "Rótulo"
        case address = "Dirección"
        case municipality = "Municipio"
        case province = "Provincia"
        case locality = "Localidad"
        case postalCode = "C.P."
        case schedule = "Horario"
        case latitude = "Latitud"
        case longitude = "Longitud (WGS84)"
        case dieselPrice = "Precio Gasoleo A"
        case gasoline95Price = "Precio Gasolina 95 E5"
    }
}

private struct StationsResponseDTO: Decodable {
    let stations: [StationDTO]

    enum CodingKeys: String, CodingKey {
        case stations = "ListaEESSPrecio"
    }
}

/// Domain mapping helpers.
private extension StationDTO {
    /// Parses Spanish-formatted decimals ("1,909" or "1.909").
    /// Empty or malformed values become `nil`.
    static func parsePrice(_ raw: String?) -> Double? {
        guard let raw, !raw.isEmpty else { return nil }
        return Double(raw.replacingOccurrences(of: ",", with: "."))
    }

    var domainModel: GasStation {
        GasStation(
            id: id,
            brand: brand,
            address: address,
            municipalityId: municipalityId,
            municipality: municipality,
            province: province,
            locality: locality,
            postalCode: postalCode,
            schedule: schedule,
            latitude: Self.parsePrice(latitude),
            longitude: Self.parsePrice(longitude),
            dieselPrice: Self.parsePrice(dieselPrice),
            gasoline95Price: Self.parsePrice(gasoline95Price)
        )
    }
}

/// DTOs for the MINETUR listing endpoints.
struct ProvinceDTO: Decodable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "IDPovincia" // sic: the API spells the key this way.
        case name = "Provincia"
    }
}

struct MunicipalityDTO: Decodable {
    let id: String
    let name: String
    let province: String

    enum CodingKeys: String, CodingKey {
        case id = "IDMunicipio"
        case name = "Municipio"
        case province = "Provincia"
    }
}

extension MunicipalityDTO {
    var domainModel: Municipality {
        Municipality(id: id, name: name, province: province)
    }
}

/// HTTP client for the official MINETUR fuel prices REST service
/// (datos.gob.es): the national station dataset and the province /
/// municipality listings. Cancellation of the calling task cancels the
/// underlying URLSession requests.
struct MineturClient: Sendable {
    private let session: URLSession
    let baseURL: URL
    let listingsBaseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/EstacionesTerrestres/")!,
        listingsBaseURL: URL = URL(string: "https://sedeaplicaciones.minetur.gob.es/ServiciosRESTCarburantes/PreciosCarburantes/Listados/")!
    ) {
        self.session = session
        self.baseURL = baseURL
        self.listingsBaseURL = listingsBaseURL
    }

    func allStations() async throws -> [GasStation] {
        let (data, _) = try await perform(request: URLRequest(url: baseURL))
        // The national dataset is large (~12 MB): decode and map off the
        // main actor so the UI never blocks.
        return try await Task.detached(priority: .userInitiated) {
            try JSONDecoder().decode(StationsResponseDTO.self, from: data)
                .stations
                .map(\.domainModel)
        }.value
    }

    func provinces() async throws -> [ProvinceDTO] {
        let (data, _) = try await perform(request: URLRequest(url: listingsBaseURL.appending(path: "Provincias")))
        return try JSONDecoder().decode([ProvinceDTO].self, from: data)
    }

    func municipalities(provinceId: String) async throws -> [MunicipalityDTO] {
        let url = listingsBaseURL.appending(path: "MunicipiosPorProvincia/\(provinceId)")
        let (data, _) = try await perform(request: URLRequest(url: url))
        return try JSONDecoder().decode([MunicipalityDTO].self, from: data)
    }

    /// Fetches the municipalities of every province concurrently.
    func allMunicipalities() async throws -> [Municipality] {
        let provinces = try await provinces()
        let groups = try await withThrowingTaskGroup(of: [Municipality].self) { group in
            for province in provinces {
                group.addTask {
                    try await self.municipalities(provinceId: province.id)
                        .map(\.domainModel)
                }
            }
            var all: [Municipality] = []
            for try await part in group {
                all.append(contentsOf: part)
            }
            return all
        }
        return groups.sorted { ($0.name, $0.province) < ($1.name, $1.province) }
    }

    private func perform(request: URLRequest) async throws -> (Data, URLResponse) {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            // Normalize URLSession's cancellation so callers can rely on
            // CancellationError to detect a superseded search.
            throw CancellationError()
        }

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw MineturError.unexpectedStatusCode(status)
        }
        return (data, response)
    }
}
