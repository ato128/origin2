//
//  FriendFocusInviteSheet.swift
//  DailyTodo
//
//  Full-screen duo focus invite — arrives via push while a friend's session
//  is live. Joining anchors the local countdown to the host's start time.
//

import SwiftUI
import Combine

// MARK: - Payload

struct FriendFocusInvitePayload: Identifiable, Equatable {
    let id: UUID = UUID()
    let sessionID: UUID
    let hostName: String
    let durationMinutes: Int
    let startedAt: Date?
    var hostUserID: UUID? = nil

    static func == (lhs: FriendFocusInvitePayload, rhs: FriendFocusInvitePayload) -> Bool {
        lhs.sessionID == rhs.sessionID
    }

    static func from(userInfo: [AnyHashable: Any]) -> FriendFocusInvitePayload? {
        guard
            let sessionIDString = userInfo["session_id"] as? String,
            let sessionID = UUID(uuidString: sessionIDString)
        else { return nil }

        let hostName = (userInfo["host_name"] as? String) ?? "Arkadaşın"

        let duration: Int = {
            if let int = userInfo["duration_minutes"] as? Int { return int }
            if let str = userInfo["duration_minutes"] as? String, let parsed = Int(str) { return parsed }
            return 25
        }()

        let startedAt: Date? = {
            guard let str = userInfo["started_at"] as? String else { return nil }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: str) { return date }
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: str)
        }()

        let hostUserID = (userInfo["host_user_id"] as? String).flatMap(UUID.init(uuidString:))

        return FriendFocusInvitePayload(
            sessionID: sessionID,
            hostName: hostName,
            durationMinutes: duration,
            startedAt: startedAt,
            hostUserID: hostUserID
        )
    }
}

// MARK: - Sheet

struct FriendFocusInviteSheet: View {
    let payload: FriendFocusInvitePayload
    let onJoin: () -> Void
    let onDecline: () -> Void

    @State private var now: Date = Date()
    @State private var isJoining = false
    @State private var appeared = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var accent: Color { Color(arenaHex: AppArenaPalette.purple) }
    private var secondary: Color { Color(arenaHex: AppArenaPalette.blue) }
    private var green: Color { Color(arenaHex: AppArenaPalette.green) }

    private var remainingMinutes: Int {
        guard let startedAt = payload.startedAt else { return payload.durationMinutes }
        let elapsed = max(0, Int(now.timeIntervalSince(startedAt)) / 60)
        return max(0, payload.durationMinutes - elapsed)
    }

    private var isExpired: Bool {
        payload.startedAt != nil && remainingMinutes <= 0
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer(minLength: 20)

                // Host identity
                VStack(spacing: 16) {
                    UserAvatarView(
                        userID: payload.hostUserID,
                        name: payload.hostName,
                        tint: accent,
                        size: 84
                    )
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 2))
                    .shadow(color: accent.opacity(0.45), radius: 20, y: 10)
                    .scaleEffect(appeared ? 1 : 0.7)

                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 11, weight: .black))
                            Text(tr("ffi_eyebrow_caps"))
                                .font(.system(size: 10.5, weight: .black, design: .monospaced))
                                .tracking(2.0)
                        }
                        .foregroundStyle(accent)

                        Text(tr("ffi_invite_line", payload.hostName))
                            .font(.system(size: 23, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.96))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 20)
                    }
                }

                // Time state
                HStack(spacing: 10) {
                    timeCell(
                        title: tr("ffi_duration_caps"),
                        value: "\(payload.durationMinutes) dk",
                        icon: "clock.fill",
                        tint: accent
                    )
                    timeCell(
                        title: isExpired ? tr("ffi_done_caps") : tr("ffi_remaining_caps"),
                        value: isExpired ? tr("ffi_done") : "\(remainingMinutes) dk",
                        icon: isExpired ? "checkmark.circle.fill" : "flame.fill",
                        tint: isExpired ? green : secondary
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                // Actions
                VStack(spacing: 12) {
                    Button {
                        guard !isJoining else { return }
                        isJoining = true
                        onJoin()
                    } label: {
                        HStack(spacing: 10) {
                            if isJoining {
                                ProgressView().tint(.black)
                            } else {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 16, weight: .black))
                            }
                            Text(isJoining ? tr("cfi_joining") : tr("ffi_join_cta"))
                                .font(.system(size: 17, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [accent, secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                        .shadow(color: accent.opacity(0.4), radius: 16, y: 8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isJoining || isExpired)
                    .opacity(isExpired ? 0.45 : 1)

                    Button(action: onDecline) {
                        Text(tr("cfi_not_now"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
            }
        }
        .onReceive(timer) { now = $0 }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) { appeared = true }
        }
    }

    private func timeCell(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .black))
                Text(title)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.2)
            }
            .foregroundStyle(tint)

            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(arenaHex: "#0A0714"), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(accent.opacity(0.20))
                .frame(width: 360, height: 360)
                .blur(radius: 100)
                .offset(x: 130, y: -230)

            Circle()
                .fill(secondary.opacity(0.14))
                .frame(width: 300, height: 300)
                .blur(radius: 95)
                .offset(x: -120, y: 300)
        }
    }
}
