import SwiftUI

/// Search screen: municipality text field + fuel filter + results list,
/// with navigation to the station detail. The search only runs when the
/// user presses the search button (the button is always enabled).
struct SearchScreen: View {
    @State private var viewModel: SearchViewModel

    init(viewModel: SearchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchControls
                content
            }
            .navigationTitle("GasFinder")
        }
    }

    private var searchControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Municipio (p. ej. Madrid)", text: $viewModel.municipalityQuery)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .onSubmit(viewModel.submitSearch)
                Button("Buscar", action: viewModel.submitSearch)
                    .buttonStyle(.borderedProminent)
            }
            Picker("Combustible", selection: $viewModel.fuel) {
                ForEach(FuelType.allCases) { fuel in
                    Text(fuel.displayName).tag(fuel)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            ContentUnavailableView(
                "Busca gasolineras",
                systemImage: "fuelpump",
                description: Text("Escribe un municipio, elige el combustible y pulsa Buscar.")
            )
        case .loading:
            ProgressView("Buscando…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .empty:
            ContentUnavailableView(
                "Sin resultados",
                systemImage: "fuelpump.slash",
                description: Text("No hay estaciones con ese combustible en el municipio.")
            )
        case .failure(let message):
            ContentUnavailableView(
                "Error",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        case .results(let stations):
            List(stations) { station in
                NavigationLink(value: station) {
                    row(for: station)
                }
            }
            .listStyle(.plain)
            .navigationDestination(for: GasStation.self) { station in
                DetailScreen(station: station)
            }
        }
    }

    private func row(for station: GasStation) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(station.brand)
                    .font(.headline)
                Text(station.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let price = station.price(for: viewModel.fuel) {
                Text(Self.priceFormatter.string(from: NSNumber(value: price)) ?? "")
                    .font(.title3.bold())
                    .foregroundStyle(.green)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }

    static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 3
        formatter.locale = Locale(identifier: "es_ES")
        return formatter
    }()
}
