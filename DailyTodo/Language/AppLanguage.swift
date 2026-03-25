//
//  AppLanguage.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 24.03.2026.
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case turkish
    case english

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .system:
            return "language_option_system"
        case .turkish:
            return "language_option_turkish"
        case .english:
            return "language_option_english"
        }
    }

    var localeIdentifier: String? {
        switch self {
        case .system:
            return nil
        case .turkish:
            return "tr"
        case .english:
            return "en"
        }
    }
}
