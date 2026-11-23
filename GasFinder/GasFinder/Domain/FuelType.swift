//
// FuelType.swift
//  GasFinder
//
//  Created by pedro.candon.local on 20/11/2026.
//

import Foundation

/// Fuel types the app can filter by, mapped to the MINETUR price fields.
enum FuelType: String, CaseIterable, Identifiable, Sendable {
    case diesel
    case gasoline

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .diesel: return "Diésel"
        case .gasoline: return "Gasolina 95"
        }
    }
}
