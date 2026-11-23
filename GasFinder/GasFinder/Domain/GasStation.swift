//
// GasStation.swift
//  GasFinder
//
//  Created by pedro.candon.local on 20/11/2026.
//

import Foundation

/// Domain model for a gas station, independent from any API or DTO.
struct GasStation: Identifiable, Hashable, Sendable {
    let id: String
    let brand: String
    let address: String
    let municipalityId: String
    let municipality: String
    let province: String
    let locality: String?
    let postalCode: String?
    let schedule: String?
    let latitude: Double?
    let longitude: Double?
    let dieselPrice: Double?
    let gasoline95Price: Double?

    /// Price in €/L for the given fuel, or `nil` if not sold here.
    func price(for fuel: FuelType) -> Double? {
        switch fuel {
        case .diesel: return dieselPrice
        case .gasoline: return gasoline95Price
        }
    }
}
