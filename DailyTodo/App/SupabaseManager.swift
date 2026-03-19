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
            supabaseURL: URL(string: "https://srzvzaczgydwtopnlrvx.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNyenZ6YWN6Z3lkd3RvcG5scnZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NjIzNjAsImV4cCI6MjA4OTQzODM2MH0.8eSacyni-OQZEU6wbMZwjSPhLdQthZFGvUwHlCiaaF4"
        )
    }
}
