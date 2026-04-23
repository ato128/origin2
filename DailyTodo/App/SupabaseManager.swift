//
//  SupabaseManager.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.03.2026.
//

import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        client = SupabaseClient(
            supabaseURL: AppSecrets.supabaseURL,
            supabaseKey: AppSecrets.supabaseAnonKey,
            options: SupabaseClientOptions(
                auth: .init(
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
}
