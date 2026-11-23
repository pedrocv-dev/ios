import SwiftUI

@main
struct GasFinderApp: App {
    var body: some Scene {
        WindowGroup {
            let municipalityRepository = MineturMunicipalityRepository()
            let stationRepository = MineturGasStationRepository()
            let searchStations = SearchStationsUseCase(
                municipalityRepository: municipalityRepository,
                stationRepository: stationRepository
            )
            SearchScreen(viewModel: SearchViewModel(searchStations: searchStations))
        }
    }
}
