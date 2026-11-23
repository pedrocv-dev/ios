import SwiftUI

/// Detail screen: shows the relevant information of the selected station.
struct DetailScreen: View {
    let station: GasStation

    var body: some View {
        List {
            Section {
                HStack {
                    Text(station.brand)
                        .font(.title2.bold())
                    Spacer()
                    if let diesel = station.dieselPrice {
                        priceBadge("Diésel", diesel)
                    }
                    if let gasoline = station.gasoline95Price {
                        priceBadge("G. 95", gasoline)
                    }
                }
            }
            Section("Datos") {
                row(title: "Dirección", value: station.address)
                row(title: "Municipio", value: station.municipality)
                row(title: "Provincia", value: station.province)
                if let locality = station.locality {
                    row(title: "Localidad", value: locality)
                }
                if let postalCode = station.postalCode {
                    row(title: "Código postal", value: postalCode)
                }
            }
            if let schedule = station.schedule, !schedule.isEmpty {
                Section("Horario") {
                    Text(schedule)
                }
            }
            Section("Precios (€/L)") {
                if let diesel = station.dieselPrice {
                    row(title: "Gasóleo A (diésel)", value: Self.price(diesel))
                }
                if let gasoline = station.gasoline95Price {
                    row(title: "Gasolina 95 E5", value: Self.price(gasoline))
                }
            }
            if station.latitude != nil, station.longitude != nil {
                Section("Coordenadas") {
                    row(title: "Latitud", value: Self.coordinate(station.latitude))
                    row(title: "Longitud", value: Self.coordinate(station.longitude))
                }
            }
        }
        .navigationTitle(station.brand)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func priceBadge(_ label: String, _ price: Double) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(Self.price(price))
                .font(.headline)
                .foregroundStyle(.green)
                .monospacedDigit()
        }
    }

    private func row(title: String, value: String?) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value ?? "—")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private static func price(_ price: Double?) -> String {
        guard let price else { return "—" }
        return SearchScreen.priceFormatter.string(from: NSNumber(value: price)) ?? String(format: "%.3f", price)
    }

    private static func coordinate(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.6f", value)
    }
}
