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
        return NSLocalizedString(key, comment: "")
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
