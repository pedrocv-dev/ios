import Foundation

/// Domain model for a gas station, independent from any API or DTO.
struct GasStation: Identifiable, Hashable, Sendable {
    let id: String
    let brand: String
    let address: String
    /// MINETUR municipality identifier the station belongs to.
    let municipalityId: String
    let municipality: String
    let province: String
    let locality: String?
    let postalCode: String?
    let schedule: String?
    let latitude: Double?
    let longitude: Double?
    /// Price in €/L, `nil` when the station does not sell the fuel.
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
