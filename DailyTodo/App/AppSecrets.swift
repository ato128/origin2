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

    /// RevenueCat public SDK key. Config.xcconfig'de production `appl_` key tanımlı
    /// (2026-08-10 geçildi) — gerçek satın almalar çalışır. Test store key'ine
    /// (`test_` öneki) GERİ DÖNME: Release build'inde SDK assertion ile çöker
    /// (SubscriptionManager.configure bu yüzden `test_` key'i Release'te reddeder).
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
        // xcconfig treats `//` as a comment, so a plain `https://…` value arrives
        // as just "https:" and PostHog posted to "https://batch/" (DNS -1003,
        // zero events delivered). Config.xcconfig now escapes it; this guard keeps
        // a truncated value from ever silently disabling analytics again.
        let fallback = "https://eu.i.posthog.com"
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "POSTHOG_HOST") as? String,
              let host = URL(string: raw)?.host, !host.isEmpty else { return fallback }
        return raw
    }

}
