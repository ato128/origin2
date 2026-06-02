//
//  FocusInviteService.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 12.04.2026.
//

import Foundation
import Supabase

final class FocusInviteService {
    static let shared = FocusInviteService()
    private init() {}

    private let functionURL = URL(string: "https://srzvzaczgydwtopnlrvx.supabase.co/functions/v1/send-message-push")!

    // ISO 8601 formatter for started_at
    private let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func sendInvites(
        sessionID: UUID,
        crewID: UUID,
        participantIDs: [UUID],
        hostName: String,
        duration: Int,
        taskTitle: String? = nil,
        // YENİ PARAMETRELER
        crewName: String? = nil,
        startedAt: Date? = nil,
        participantNames: [String]? = nil,
        totalParticipants: Int? = nil
    ) async {
        let currentUserIDString = UserDefaults.standard.string(forKey: "current_user_id")

        let filteredParticipantIDs = Array(
            Set(
                participantIDs.filter { $0.uuidString != currentUserIDString }
            )
        )

        guard !filteredParticipantIDs.isEmpty else {
            print("FOCUS INVITE: gönderilecek katılımcı yok")
            return
        }

        guard let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
              !anonKey.isEmpty else {
            print("FOCUS INVITE ERROR: SUPABASE_ANON_KEY bulunamadı")
            return
        }

        let normalizedTaskTitle = taskTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let normalizedCrewName = crewName?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let startedAtString = startedAt.map { iso8601.string(from: $0) }

        for participantID in filteredParticipantIDs {
            do {
                try await sendSingleInvite(
                    anonKey: anonKey,
                    toUserID: participantID,
                    sessionID: sessionID,
                    crewID: crewID,
                    hostName: hostName,
                    duration: duration,
                    taskTitle: normalizedTaskTitle,
                    crewName: normalizedCrewName,
                    startedAtString: startedAtString,
                    participantNames: participantNames,
                    totalParticipants: totalParticipants
                )
            } catch {
                print("FOCUS INVITE SEND ERROR [\(participantID.uuidString)]:", error.localizedDescription)
            }
        }
    }

    private func sendSingleInvite(
        anonKey: String,
        toUserID: UUID,
        sessionID: UUID,
        crewID: UUID,
        hostName: String,
        duration: Int,
        taskTitle: String?,
        crewName: String?,
        startedAtString: String?,
        participantNames: [String]?,
        totalParticipants: Int?
    ) async throws {
        guard let inviteSecret = Bundle.main.object(forInfoDictionaryKey: "FOCUS_INVITE_SECRET") as? String,
              !inviteSecret.isEmpty else {
            print("FOCUS INVITE ERROR: FOCUS_INVITE_SECRET bulunamadı")
            return
        }

        guard let accessToken = SupabaseManager.shared.client.auth.currentSession?.accessToken,
              !accessToken.isEmpty else {
            print("FOCUS INVITE ERROR: access token yok")
            return
        }

        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(inviteSecret, forHTTPHeaderField: "x-focus-invite-secret")

        let deepLink = "dailytodo://focus?crew_id=\(crewID.uuidString)&session_id=\(sessionID.uuidString)"

        let bodyText: String
        if let taskTitle, !taskTitle.isEmpty {
            bodyText = "\(hostName) \(duration) dk focus başlattı. Görev: \(taskTitle). Katılmak ister misin?"
        } else {
            bodyText = "\(hostName) \(duration) dk focus başlattı. Katılmak ister misin?"
        }

        // Eğer crew adı varsa title'a koy, yoksa default "Takım odakta"
        let title: String = {
            if let crewName, !crewName.isEmpty {
                return "\(crewName) · Focus"
            }
            return "Takım odakta"
        }()

        var body: [String: Any] = [
            "toUserId": toUserID.uuidString,
            "title": title,
            "message": bodyText,
            "type": "crew_focus_invite",
            "crew_id": crewID.uuidString,
            "session_id": sessionID.uuidString,
            "host_name": hostName,
            "duration_minutes": duration,
            "deep_link": deepLink,
            "badge": 1
        ]

        if let taskTitle, !taskTitle.isEmpty {
            body["task_title"] = taskTitle
        }

        // YENİ ALANLAR
        if let crewName, !crewName.isEmpty {
            body["crew_name"] = crewName
        }

        if let startedAtString {
            body["started_at"] = startedAtString
        }

        if let participantNames, !participantNames.isEmpty {
            body["participant_names"] = participantNames
        }

        if let totalParticipants {
            body["total_participants"] = totalParticipants
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("FOCUS INVITE BODY:", body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("FOCUS INVITE ERROR: function response geçersiz")
            return
        }

        let bodyString = String(data: data, encoding: .utf8) ?? "no-body"
        print("FOCUS INVITE STATUS:", httpResponse.statusCode)
        print("FOCUS INVITE RESPONSE:", bodyString)

        guard (200...299).contains(httpResponse.statusCode) else {
            print("FOCUS INVITE FUNCTION ERROR:", httpResponse.statusCode, bodyString)
            return
        }

        print("FOCUS INVITE SENT -> \(toUserID.uuidString)")
    }

    // ════════════════════════════════════════════════════════════════
    // Focus End Notifications (mevcut)
    // ════════════════════════════════════════════════════════════════

    func sendEndNotifications(
        crewID: UUID,
        crewName: String,
        participantIDs: [UUID],
        durationMinutes: Int,
        previousMinutes: Int? = nil
    ) async {
        let currentUserIDString = UserDefaults.standard.string(forKey: "current_user_id")

        let uniqueIDs = Array(Set(participantIDs))

        guard !uniqueIDs.isEmpty else {
            print("FOCUS END PUSH: gönderilecek kullanıcı yok")
            return
        }

        print("FOCUS END PUSH SEND -> \(uniqueIDs.count) kullanıcıya")

        for userID in uniqueIDs {
            if userID.uuidString == currentUserIDString {
                continue
            }

            PushService.shared.sendCrewFocusEndedPush(
                toUserId: userID.uuidString,
                crewID: crewID.uuidString,
                crewName: crewName,
                durationMinutes: durationMinutes,
                previousMinutes: previousMinutes
            )
        }
    }

    func sendLeftNotifications(
        crewID: UUID,
        crewName: String,
        leaverID: UUID,
        leaverName: String,
        otherParticipantIDs: [UUID]
    ) async {
        let filteredIDs = Array(
            Set(otherParticipantIDs.filter { $0 != leaverID })
        )

        guard !filteredIDs.isEmpty else {
            print("FOCUS LEFT PUSH: bildirilecek diğer kullanıcı yok")
            return
        }

        print("FOCUS LEFT PUSH SEND -> \(filteredIDs.count) kullanıcıya")

        for userID in filteredIDs {
            PushService.shared.sendCrewFocusLeftPush(
                toUserId: userID.uuidString,
                crewID: crewID.uuidString,
                crewName: crewName,
                leaverName: leaverName
            )
        }
    }
}
