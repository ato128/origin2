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
        // Mirror to the shared App Group so the Live Activity widget can localize too.
        mirrorToAppGroup(selectedLanguage)
    }

    func setLanguage(_ language: AppLanguage) {
        selectedLanguage = language
        storedLanguageRawValue = language.rawValue
        mirrorToAppGroup(language)
    }

    private func mirrorToAppGroup(_ language: AppLanguage) {
        UserDefaults(suiteName: "group.com.atakan.updo")?.set(language.rawValue, forKey: "appLanguage")
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
