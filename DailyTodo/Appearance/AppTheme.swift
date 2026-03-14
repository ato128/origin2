//
//  AppTheme.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 14.03.2026.
//

enum AppTheme: String, CaseIterable, Identifiable {
    case gradient
    case dark
    case amoled
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gradient: return "Gradient"
        case .dark: return "Dark"
        case .amoled: return "AMOLED"
        case .light: return "Light"
        }
    }

    var icon: String {
        switch self {
        case .gradient: return "sparkles"
        case .dark: return "moon"
        case .amoled: return "moon.fill"
        case .light: return "sun.max"
        }
    }
}
