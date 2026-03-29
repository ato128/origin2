//
//  PushService.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 29.03.2026.
//

import Foundation

final class PushService {
    static let shared = PushService()
    private init() {}

    private let endpoint = "https://srzvzaczgydwtopnlrvx.supabase.co/functions/v1/send-message-push"
    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNyenZ6YWN6Z3lkd3RvcG5scnZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NjIzNjAsImV4cCI6MjA4OTQzODM2MH0.8eSacyni-OQZEU6wbMZwjSPhLdQthZFGvUwHlCiaaF4"

    func send(toUserId: String, message: String) {
        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        guard let body = try? JSONSerialization.data(withJSONObject: [
            "toUserId": toUserId,
            "message": message
        ]) else { return }

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let http = response as? HTTPURLResponse {
                print("🟡 PUSH HTTP STATUS:", http.statusCode)
            }
        }.resume()
    }
}
