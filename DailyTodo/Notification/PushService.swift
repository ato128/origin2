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

    private func performRequest(bodyObject: [String: Any]) {
        guard let url = URL(string: endpoint) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        guard let body = try? JSONSerialization.data(withJSONObject: bodyObject) else {
            print("PUSH BODY SERIALIZE ERROR")
            return
        }

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                print("PUSH SEND ERROR:", error.localizedDescription)
            }

            if let http = response as? HTTPURLResponse {
                print("🟡 PUSH HTTP STATUS:", http.statusCode)
            }

            if let data,
               let text = String(data: data, encoding: .utf8),
               !text.isEmpty {
                print("🟣 PUSH RESPONSE:", text)
            }
        }.resume()
    }

    func sendFriendMessagePush(
        toUserId: String,
        friendshipID: String,
        senderName: String,
        message: String,
        badge: Int = 1
    ) {
        performRequest(bodyObject: [
            "toUserId": toUserId,
            "title": senderName,
            "message": message,
            "type": "friend_chat",
            "friendship_id": friendshipID,
            "deep_link": "dailytodo://friend-chat?friendship_id=\(friendshipID)",
            "badge": badge
        ])
    }

    func sendCrewMessagePush(
        toUserId: String,
        crewID: String,
        crewName: String,
        message: String,
        badge: Int = 1
    ) {
        performRequest(bodyObject: [
            "toUserId": toUserId,
            "title": crewName,
            "message": message,
            "type": "crew_chat",
            "crew_id": crewID,
            "deep_link": "dailytodo://crew-chat?crew_id=\(crewID)",
            "badge": badge
        ])
    }

    func sendFocusRoomPush(
        toUserId: String,
        crewID: String,
        crewName: String,
        message: String = "Focus odası başladı",
        badge: Int = 1
    ) {
        performRequest(bodyObject: [
            "toUserId": toUserId,
            "title": crewName,
            "message": message,
            "type": "focus_room",
            "crew_id": crewID,
            "deep_link": "dailytodo://crew-chat?crew_id=\(crewID)",
            "badge": badge
        ])
    }
}
