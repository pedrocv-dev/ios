//
// SearchViewModel.swift
//  GasFinder
//
//  Created by pedro.candon.local on 23/11/2026.
//

import Foundation
import Observation

@Observable
@MainActor
final class SearchViewModel {
    enum State: Equatable {
        case idle
        case loading
        case results([GasStation])
        case empty
        case failure(String)
    }

    var municipalityQuery: String = ""
    var fuel: FuelType = .diesel {
        didSet { refetchWithCurrentQuery() }
    }
    private(set) var state: State = .idle

    private var searchTask: Task<Void, Never>?
    private let searchStations: SearchStationsUseCase

    init(searchStations: SearchStationsUseCase) {
        self.searchStations = searchStations
    }

    /// Called when the user presses the search button (or submits the field).
    /// An empty query just resets to idle.
    func submitSearch() {
        searchTask?.cancel()

        let trimmed = municipalityQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .idle
            return
        }

        state = .loading
        let fuel = fuel
        searchTask = Task { [searchStations] in
            do {
                let results = try await searchStations.execute(query: trimmed, fuel: fuel)
                guard !Task.isCancelled else { return }
                state = results.isEmpty ? .empty : .results(results)
            } catch is CancellationError {
                return
            } catch StationSearchError.municipalityNotFound(let name) {
                guard !Task.isCancelled else { return }
                state = .failure("No se encontró el municipio «\(name)».")
            } catch {
                guard !Task.isCancelled else { return }
                state = .failure(Self.errorMessage(for: error))
            }
        }
    }

    private func refetchWithCurrentQuery() {
        guard !municipalityQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        submitSearch()
    }

    static func errorMessage(for error: Error) -> String {
        if let mineturError = error as? MineturError {
            switch mineturError {
            case .unexpectedStatusCode(let code):
                return "La búsqueda falló (estado \(code)). Inténtalo de nuevo."
            case .invalidURL:
                return "No se pudo construir la petición. Inténtalo de nuevo."
            }
        }
        return "Algo salió mal. Inténtalo de nuevo."
    }
}
