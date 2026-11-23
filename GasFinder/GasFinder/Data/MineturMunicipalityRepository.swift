//
// MineturMunicipalityRepository.swift
//  GasFinder
//
//  Created by pedro.candon.local on 23/11/2026.
//

import Foundation

/// MINETUR implementation of `MunicipalityRepository`.
///
/// The municipality list is always fetched from the API
/// (`Listados/Provincias` + `Listados/MunicipiosPorProvincia/{id}`, one
/// request per province, run concurrently) and kept in an in-memory cache
/// with a limited TTL, so repeated searches never repeat those requests.
final class MineturMunicipalityRepository: MunicipalityRepository {
    private static let cacheKey = "all-municipalities"

    private let client: MineturClient
    private let cache: QueryCache<String, [Municipality]>

    init(
        client: MineturClient = MineturClient(),
        cache: QueryCache<String, [Municipality]> = QueryCache(ttl: 300)
    ) {
        self.client = client
        self.cache = cache
    }

    func searchMunicipalities(query: String) async throws -> [Municipality] {
        let all = try await municipalityList()
        return Self.matches(for: query, in: all)
    }

    private func municipalityList() async throws -> [Municipality] {
        if let cached = await cache.value(for: Self.cacheKey) {
            return cached
        }
        let municipalities = try await client.allMunicipalities()
        await cache.set(municipalities, for: Self.cacheKey)
        return municipalities
    }

    /// Exact matching, ignoring case and diacritics: first by municipality
    /// name, then by province name; otherwise there is no match.
    static func matches(for query: String, in municipalities: [Municipality]) -> [Municipality] {
        let normalized = normalize(query)
        guard !normalized.isEmpty else { return [] }

        let byName = municipalities.filter { normalize($0.name) == normalized }
        if !byName.isEmpty {
            return byName.sorted { $0.name < $1.name }
        }

        let byProvince = municipalities.filter { normalize($0.province) == normalized }
        if !byProvince.isEmpty {
            return byProvince.sorted { $0.name < $1.name }
        }

        return []
    }

    /// Case- and diacritic-insensitive normalization ("MÉRIDA" == "mérida").
    static func normalize(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
