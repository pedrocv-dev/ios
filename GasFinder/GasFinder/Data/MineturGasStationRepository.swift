//
// MineturGasStationRepository.swift
//  GasFinder
//
//  Created by pedro.candon.local on 23/11/2026.
//

import Foundation

/// MINETUR implementation of `GasStationRepository`.
///
/// The national dataset is large, so it is fetched as a whole and kept in an
/// in-memory cache with a limited TTL: repeated lookups (e.g. when the user
/// switches between Diésel and Gasolina, or searches another municipality)
/// reuse the cached dataset instead of hitting the network; once expired,
/// the dataset is fetched again and the cache is refreshed.
final class MineturGasStationRepository: GasStationRepository {
    private static let cacheKey = "all-stations"

    private let client: MineturClient
    private let cache: QueryCache<String, [GasStation]>

    init(
        client: MineturClient = MineturClient(),
        cache: QueryCache<String, [GasStation]> = QueryCache(ttl: 120)
    ) {
        self.client = client
        self.cache = cache
    }

    func stations() async throws -> [GasStation] {
        if let cached = await cache.value(for: Self.cacheKey) {
            return cached
        }

        let stations = try await client.allStations()
        await cache.set(stations, for: Self.cacheKey)
        return stations
    }
}
