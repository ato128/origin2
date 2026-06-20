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

        guard let raw, !raw.isEmpty, let url = URL(string: raw) else {
            fatalError("SUPABASE_URL missing in Info.plist / xcconfig")
        }
        return url
    }

    static var supabaseAnonKey: String {
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String

        guard let key, !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY missing in Info.plist / xcconfig")
        }
        return key
    }

    /// RevenueCat public SDK key.
    /// ⚠️ Şu an Config.xcconfig'de bir TEST STORE key'i ("test_" öneki) tanımlı —
    /// App Store'da gerçek satın alma bu key ile ÇALIŞMAZ. Production'a geçiş tek satır:
    /// Config.xcconfig'deki REVENUECAT_API_KEY değerini "appl_..." key'iyle değiştirmek yeterli
    /// (App Store Connect ürünleri + RevenueCat bağlantısı tamamlandıktan sonra).
    static var revenueCatAPIKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String, !key.isEmpty else {
            fatalError("REVENUECAT_API_KEY missing in Info.plist / xcconfig")
        }
        return key
    }

    static var postHogAPIKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_API_KEY") as? String, !key.isEmpty else {
            fatalError("POSTHOG_API_KEY missing in Info.plist / xcconfig")
        }
        return key
    }

    static var postHogHost: String {
        return Bundle.main.object(forInfoDictionaryKey: "POSTHOG_HOST") as? String ?? "https://eu.i.posthog.com"
    }

}
