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

    private var functionURL: URL {
        URL(string: "\(ChatBackendEnvironment.httpBaseURL)/v1/focus/invite")!
    }

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
        participantUserIDs: [String]? = nil,
        totalParticipants: Int? = nil
    ) async {
        let currentUserIDString = UserDefaults.standard.string(forKey: "current_user_id")

        let filteredParticipantIDs = Array(
            Set(
                participantIDs.filter { $0.uuidString != currentUserIDString }
            )
        )

        guard !filteredParticipantIDs.isEmpty else {
            Log.debug("FOCUS INVITE: gönderilecek katılımcı yok")
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
                    toUserID: participantID,
                    sessionID: sessionID,
                    crewID: crewID,
                    hostName: hostName,
                    duration: duration,
                    taskTitle: normalizedTaskTitle,
                    crewName: normalizedCrewName,
                    startedAtString: startedAtString,
                    participantNames: participantNames,
                    participantUserIDs: participantUserIDs,
                    totalParticipants: totalParticipants
                )
            } catch {
                Log.debug("FOCUS INVITE SEND ERROR [\(participantID.uuidString)]:", error.localizedDescription)
            }
        }
    }

    private func sendSingleInvite(
        toUserID: UUID,
        sessionID: UUID,
        crewID: UUID,
        hostName: String,
        duration: Int,
        taskTitle: String?,
        crewName: String?,
        startedAtString: String?,
        participantNames: [String]?,
        participantUserIDs: [String]?,
        totalParticipants: Int?
    ) async throws {
       

        guard let accessToken = SupabaseManager.shared.client.auth.currentSession?.accessToken,
              !accessToken.isEmpty else {
            Log.debug("FOCUS INVITE ERROR: access token yok")
            return
        }

        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let deepLink = "dailytodo://focus?crew_id=\(crewID.uuidString)&session_id=\(sessionID.uuidString)"

        let bodyText: String
        if let taskTitle, !taskTitle.isEmpty {
            bodyText = tr("fis_invite_task", hostName, duration, taskTitle)
        } else {
            bodyText = tr("fis_invite", hostName, duration)
        }

        // Eğer crew adı varsa title'a koy, yoksa default tr("fis_team_focusing")
        let title: String = {
            if let crewName, !crewName.isEmpty {
                return "\(crewName) · Focus"
            }
            return tr("fis_team_focusing")
        }()

        var body: [String: Any] = [
            "toUserId": toUserID.uuidString,
            "crewID": crewID.uuidString,
            "crewName": crewName ?? "Crew",
            "sessionID": sessionID.uuidString,
            "hostName": hostName,
            "durationMinutes": duration,
            "deepLink": deepLink,
            "badge": 1
        ]
        if let taskTitle, !taskTitle.isEmpty {
            body["taskTitle"] = taskTitle
        }

        if let startedAtString {
            body["startedAt"] = startedAtString
        }

        if let participantNames, !participantNames.isEmpty {
            body["participantNames"] = participantNames
        }

        if let participantUserIDs, !participantUserIDs.isEmpty {
            body["participantUserIDs"] = participantUserIDs
        }

        if let totalParticipants {
            body["totalParticipants"] = totalParticipants
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        Log.debug("FOCUS INVITE BODY:", body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            Log.debug("FOCUS INVITE ERROR: function response geçersiz")
            return
        }

        let bodyString = String(data: data, encoding: .utf8) ?? "no-body"
        Log.debug("FOCUS INVITE STATUS:", httpResponse.statusCode)
        Log.debug("FOCUS INVITE RESPONSE:", bodyString)

        guard (200...299).contains(httpResponse.statusCode) else {
            Log.debug("FOCUS INVITE FUNCTION ERROR:", httpResponse.statusCode, bodyString)
            return
        }

        Log.debug("FOCUS INVITE SENT -> \(toUserID.uuidString)")
    }

    // ════════════════════════════════════════════════════════════════
    // Friend request push — istek Supabase'e yazıldıktan sonra çağrılır;
    // gönderen adını backend kendisi çözer.
    // ════════════════════════════════════════════════════════════════

    func sendFriendRequestPush(toUserID: UUID) async {
        guard let accessToken = SupabaseManager.shared.client.auth.currentSession?.accessToken,
              !accessToken.isEmpty,
              let url = URL(string: "\(ChatBackendEnvironment.httpBaseURL)/v1/push/friend-request")
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "toUserID": toUserID.uuidString
        ])

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            Log.debug("FRIEND REQUEST PUSH STATUS:", status)
        } catch {
            Log.debug("FRIEND REQUEST PUSH ERROR:", error.localizedDescription)
        }
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
            Log.debug("FOCUS END PUSH: gönderilecek kullanıcı yok")
            return
        }

        Log.debug("FOCUS END PUSH SEND -> \(uniqueIDs.count) kullanıcıya")

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
            Log.debug("FOCUS LEFT PUSH: bildirilecek diğer kullanıcı yok")
            return
        }

        Log.debug("FOCUS LEFT PUSH SEND -> \(filteredIDs.count) kullanıcıya")

        for userID in filteredIDs {
            PushService.shared.sendCrewFocusLeftPush(
                toUserId: userID.uuidString,
                crewID: crewID.uuidString,
                crewName: crewName,
                leaverName: leaverName
            )
        }
    }
    func sendJoinedNotifications(
        crewID: UUID,
        crewName: String,
        sessionID: UUID,
        joinedUserID: UUID?,
        joinedName: String,
        activeParticipantIDs: [UUID]
    ) async {
        let filteredIDs = Array(
            Set(
                activeParticipantIDs.filter { id in
                    guard let joinedUserID else { return true }
                    return id != joinedUserID
                }
            )
        )

        guard !filteredIDs.isEmpty else {
            Log.debug("FOCUS JOINED PUSH: bildirilecek diğer kullanıcı yok")
            return
        }

        Log.debug("FOCUS JOINED PUSH SEND -> \(filteredIDs.count) kullanıcıya")

        for userID in filteredIDs {
            PushService.shared.sendCrewFocusJoinedPush(
                toUserId: userID.uuidString,
                crewID: crewID.uuidString,
                crewName: crewName,
                sessionID: sessionID.uuidString,
                joinedName: joinedName,
                badge: 0
            )
        }
    }
}
