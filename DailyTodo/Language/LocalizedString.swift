//
//  LocalizedString.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 27.03.2026.
//

import Foundation

func tr(_ key: String) -> String {
    let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
    
    let langCode: String
    switch lang {
    case "turkish": langCode = "tr"
    case "english": langCode = "en"
    default:
        // "system" → follow the device's top preferred language deterministically
        // (kept in sync with appLanguageIsEnglish()), so the whole UI matches the
        // native Sign in with Apple button instead of drifting to the base strings.
        langCode = (Locale.preferredLanguages.first ?? "en").hasPrefix("tr") ? "tr" : "en"
    }

    guard let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
        return NSLocalizedString(key, comment: "")
    }
    
    return bundle.localizedString(forKey: key, value: key, table: "Localizable")
}

func tr(_ key: String, _ arg1: CVarArg) -> String {
    String(format: tr(key), arg1)
}

func tr(_ key: String, _ arg1: CVarArg, _ arg2: CVarArg) -> String {
    String(format: tr(key), arg1, arg2)
}

func tr(_ key: String, _ arg1: CVarArg, _ arg2: CVarArg, _ arg3: CVarArg) -> String {
    String(format: tr(key), arg1, arg2, arg3)
}

// MARK: - Localized date tokens (follows appLanguage; TR/EN aware)

func appLanguageIsEnglish() -> Bool {
    let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
    switch lang {
    case "english": return true
    case "turkish": return false
    default:
        // "system": SADECE cihaz Türkçeyse Türkçe; diğer TÜM diller (Almanca,
        // Fransızca...) İngilizce kalır. tr() ile birebir aynı kural olmalı,
        // yoksa Türkçe/İngilizce dışı cihazlarda karışık dil çıkıyordu.
        return !(Locale.preferredLanguages.first ?? "en").hasPrefix("tr")
    }
}

/// Weekday index where 0 = Monday … 6 = Sunday.
func localizedWeekdayShort(_ index: Int) -> String {
    let i = max(0, min(6, index))
    let trList = ["PZT", "SAL", "ÇAR", "PER", "CUM", "CMT", "PAZ"]
    let enList = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    return (appLanguageIsEnglish() ? enList : trList)[i]
}

func localizedWeekdayLetter(_ index: Int) -> String {
    let i = max(0, min(6, index))
    let trList = ["P", "S", "Ç", "P", "C", "C", "P"]
    let enList = ["M", "T", "W", "T", "F", "S", "S"]
    return (appLanguageIsEnglish() ? enList : trList)[i]
}

func localizedWeekdayFull(_ index: Int) -> String {
    let i = max(0, min(6, index))
    let trList = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]
    let enList = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    return (appLanguageIsEnglish() ? enList : trList)[i]
}

/// Month index where 0 = January … 11 = December.
func localizedMonthShort(_ index: Int) -> String {
    let i = max(0, min(11, index))
    let trList = ["OCA", "ŞUB", "MAR", "NİS", "MAY", "HAZ", "TEM", "AĞU", "EYL", "EKİ", "KAS", "ARA"]
    let enList = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
    return (appLanguageIsEnglish() ? enList : trList)[i]
}
