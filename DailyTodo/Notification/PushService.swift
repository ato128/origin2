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

    private let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJIUzI1NiIsInJlZiI6InNyenZ6YWN6Z3lkd3RvcG5scnZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NjIzNjAsImV4cCI6MjA4OTQzODM2MH0.8eSacyni-OQZEU6wbMZwjSPhLdQthZFGvUwHlCiaaF4"

    private var currentEnvironment: String {
        PushTokenStore.shared.currentEnvironment
    }

    private func performRequest(bodyObject: [String: Any]) {
        guard let url = URL(string: endpoint) else {
            print("PUSH URL ERROR: endpoint invalid")
            return
        }

        guard JSONSerialization.isValidJSONObject(bodyObject) else {
            print("PUSH BODY ERROR: invalid JSON object")
            return
        }

        guard let body = try? JSONSerialization.data(withJSONObject: bodyObject) else {
            print("PUSH BODY SERIALIZE ERROR")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        print("🚀 PUSH REQUEST BODY:", String(data: body, encoding: .utf8) ?? "nil")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                print("🔴 PUSH SEND ERROR:", error.localizedDescription)
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let responseText = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""

            print("🟡 PUSH HTTP STATUS:", statusCode)

            if !responseText.isEmpty {
                print("🟣 PUSH RESPONSE:", responseText)
            }

            if !(200...299).contains(statusCode) {
                print("🔴 PUSH FAILED HTTP:", statusCode)
            }
        }
        .resume()
    }

    func sendFriendMessagePush(
        toUserId: String,
        friendshipID: String,
        senderName: String,
        message: String,
        badge: Int = 1
    ) {
        let cleanToUserId = toUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFriendshipID = friendshipID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToUserId.isEmpty, !cleanFriendshipID.isEmpty else {
            print("FRIEND PUSH SKIPPED: missing toUserId or friendshipID")
            return
        }

        print("🚀 FRIEND PUSH SEND CALLED")
        print("🚀 toUserId:", cleanToUserId)
        print("🚀 friendshipID:", cleanFriendshipID)
        print("🚀 environment:", currentEnvironment)

        performRequest(bodyObject: [
            "toUserId": cleanToUserId,
            "title": senderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "DailyTodo" : senderName,
            "message": message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Yeni mesaj" : message,
            "type": "friend_chat",
            "friendship_id": cleanFriendshipID,
            "deep_link": "dailytodo://friend-chat?friendship_id=\(cleanFriendshipID)",
            "badge": badge,
            "environment": currentEnvironment
        ])
    }

    func sendCrewMessagePush(
        toUserId: String,
        crewID: String,
        crewName: String,
        message: String,
        badge: Int = 1
    ) {
        let cleanToUserId = toUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCrewID = crewID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToUserId.isEmpty, !cleanCrewID.isEmpty else {
            print("CREW PUSH SKIPPED: missing toUserId or crewID")
            return
        }

        print("🚀 CREW PUSH SEND CALLED")
        print("🚀 toUserId:", cleanToUserId)
        print("🚀 crewID:", cleanCrewID)
        print("🚀 environment:", currentEnvironment)

        performRequest(bodyObject: [
            "toUserId": cleanToUserId,
            "title": crewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Crew" : crewName,
            "message": message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Yeni crew mesajı" : message,
            "type": "crew_chat",
            "crew_id": cleanCrewID,
            "deep_link": "dailytodo://crew-chat?crew_id=\(cleanCrewID)",
            "badge": badge,
            "environment": currentEnvironment
        ])
    }

    func sendFocusRoomPush(
        toUserId: String,
        crewID: String,
        crewName: String,
        message: String = "Focus odası başladı",
        badge: Int = 1
    ) {
        let cleanToUserId = toUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCrewID = crewID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToUserId.isEmpty, !cleanCrewID.isEmpty else {
            print("FOCUS PUSH SKIPPED: missing toUserId or crewID")
            return
        }

        print("🚀 FOCUS PUSH SEND CALLED")
        print("🚀 toUserId:", cleanToUserId)
        print("🚀 crewID:", cleanCrewID)
        print("🚀 environment:", currentEnvironment)

        performRequest(bodyObject: [
            "toUserId": cleanToUserId,
            "title": crewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Focus" : crewName,
            "message": message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Focus odası başladı" : message,
            "type": "focus_room",
            "crew_id": cleanCrewID,
            "deep_link": "dailytodo://crew-chat?crew_id=\(cleanCrewID)",
            "badge": badge,
            "environment": currentEnvironment
        ])
    }

    func sendCrewFocusInvitePush(
        toUserId: String,
        crewID: String,
        crewName: String,
        message: String = "Crew focus daveti geldi",
        badge: Int = 1
    ) {
        let cleanToUserId = toUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCrewID = crewID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanToUserId.isEmpty, !cleanCrewID.isEmpty else {
            print("CREW FOCUS INVITE PUSH SKIPPED: missing toUserId or crewID")
            return
        }

        print("🚀 CREW FOCUS INVITE PUSH SEND CALLED")
        print("🚀 toUserId:", cleanToUserId)
        print("🚀 crewID:", cleanCrewID)
        print("🚀 environment:", currentEnvironment)

        performRequest(bodyObject: [
            "toUserId": cleanToUserId,
            "title": crewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Crew Focus" : crewName,
            "message": message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Crew focus daveti geldi" : message,
            "type": "crew_focus_invite",
            "crew_id": cleanCrewID,
            "deep_link": "dailytodo://crew-chat?crew_id=\(cleanCrewID)",
            "badge": badge,
            "environment": currentEnvironment
        ])
    }
}
