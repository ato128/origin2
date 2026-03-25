//
//  LanguageManager.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 24.03.2026.
//

import SwiftUI
import Combine

@MainActor
final class LanguageManager: ObservableObject {
    @AppStorage("appLanguage") private var storedLanguageRawValue: String = AppLanguage.system.rawValue

    @Published var selectedLanguage: AppLanguage = .system

    init() {
        selectedLanguage = AppLanguage(rawValue: storedLanguageRawValue) ?? .system
    }

    func setLanguage(_ language: AppLanguage) {
        selectedLanguage = language
        storedLanguageRawValue = language.rawValue
    }

    var activeLocale: Locale {
        switch selectedLanguage {
        case .system:
            if let preferred = Locale.preferredLanguages.first {
                return Locale(identifier: preferred)
            }
            return .current
        case .turkish:
            return Locale(identifier: "tr")
        case .english:
            return Locale(identifier: "en")
        }
    }
}
