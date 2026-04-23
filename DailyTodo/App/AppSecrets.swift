//
//  AppSecrets.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 23.04.2026.
//

import Foundation

enum AppSecrets {
    static var supabaseURL: URL {
        let raw = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
        print("DEBUG SUPABASE_URL RAW =", raw ?? "nil")

        guard let raw, !raw.isEmpty, let url = URL(string: raw) else {
            fatalError("SUPABASE_URL missing in Info.plist / xcconfig")
        }
        return url
    }

    static var supabaseAnonKey: String {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        print("DEBUG SUPABASE_ANON_KEY RAW =", key ?? "nil")

        guard let key, !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY missing in Info.plist / xcconfig")
        }
        return key
    }
}
