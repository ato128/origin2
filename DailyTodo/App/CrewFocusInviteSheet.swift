//
//  CrewFocusInviteSheet.swift
//  DailyTodo
//
//  Profesyonel tam ekran davet ekranı.
//  Push'tan veya manuel olarak çağrılabilir.
//

import SwiftUI
import Combine

// MARK: - Davet Payload Modeli

/// Push'tan veya yerel olarak parse edilebilen davet bilgisi.
/// Identifiable + Equatable çünkü sheet(item:) ile kullanılıyor.
struct CrewFocusInvitePayload: Identifiable, Equatable {
    let id: UUID = UUID()
    let crewID: UUID
    let sessionID: UUID
    let crewName: String
    let hostName: String
    let durationMinutes: Int
    let taskTitle: String?
    let startedAt: Date?
    let participantNames: [String]
    let totalParticipants: Int

    static func == (lhs: CrewFocusInvitePayload, rhs: CrewFocusInvitePayload) -> Bool {
        lhs.sessionID == rhs.sessionID && lhs.crewID == rhs.crewID
    }
}

// MARK: - Parser

extension CrewFocusInvitePayload {
    /// Push userInfo'dan parse et. Geriye dönük uyumlu - yeni alanlar yoksa default'lar kullanılır.
    static func from(userInfo: [AnyHashable: Any]) -> CrewFocusInvitePayload? {
        guard
            let crewIDString = userInfo["crew_id"] as? String,
            let sessionIDString = userInfo["session_id"] as? String,
            let crewID = UUID(uuidString: crewIDString),
            let sessionID = UUID(uuidString: sessionIDString)
        else {
            return nil
        }

        let hostName = (userInfo["host_name"] as? String) ?? "Birisi"
        let crewName = (userInfo["crew_name"] as? String) ?? "Crew"
        let taskTitle = userInfo["task_title"] as? String

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

        let participantNames: [String] = {
            if let array = userInfo["participant_names"] as? [String] { return array }
            // Push payload'ı bazen string olarak JSON gönderebilir
            if let str = userInfo["participant_names"] as? String,
               let data = str.data(using: .utf8),
               let array = try? JSONDecoder().decode([String].self, from: data) {
                return array
            }
            return []
        }()

        let totalParticipants: Int = {
            if let int = userInfo["total_participants"] as? Int { return int }
            if let str = userInfo["total_participants"] as? String, let parsed = Int(str) { return parsed }
            return max(1, participantNames.count)
        }()

        return CrewFocusInvitePayload(
            crewID: crewID,
            sessionID: sessionID,
            crewName: crewName,
            hostName: hostName,
            durationMinutes: duration,
            taskTitle: taskTitle,
            startedAt: startedAt,
            participantNames: participantNames,
            totalParticipants: totalParticipants
        )
    }
}

// MARK: - Sheet View

struct CrewFocusInviteSheet: View {
    let payload: CrewFocusInvitePayload
    let onJoin: () -> Void
    let onDismiss: () -> Void

    @State private var now: Date = Date()
    @State private var isJoining = false
    @State private var appeared = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Computed

    private var accent: Color {
        Color(arenaHex: AppArenaPalette.coral)
    }

    private var secondaryAccent: Color {
        Color(arenaHex: AppArenaPalette.gold)
    }

    private var greenAccent: Color {
        Color(arenaHex: AppArenaPalette.green)
    }

    /// Şu an kaçıncı dakikada (started_at'ten itibaren)
    private var elapsedMinutes: Int {
        guard let startedAt = payload.startedAt else { return 0 }
        let seconds = Int(now.timeIntervalSince(startedAt))
        return max(0, seconds / 60)
    }

    /// Kalan dakika
    private var remainingMinutes: Int {
        max(0, payload.durationMinutes - elapsedMinutes)
    }

    /// Geçen progress (0-1)
    private var progress: Double {
        guard payload.durationMinutes > 0 else { return 0 }
        let elapsedSeconds = max(0, Int(now.timeIntervalSince(payload.startedAt ?? now)))
        let totalSeconds = payload.durationMinutes * 60
        return min(1.0, max(0.0, Double(elapsedSeconds) / Double(totalSeconds)))
    }

    private var hasStarted: Bool {
        payload.startedAt != nil
    }

    private var isExpired: Bool {
        hasStarted && remainingMinutes <= 0
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundLayer.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Color.clear.frame(height: 4)

                    topBar

                    crewHeader

                    inviteMessage

                    if let taskTitle = payload.taskTitle, !taskTitle.isEmpty {
                        taskCard(title: taskTitle)
                    }

                    durationCard

                    if !payload.participantNames.isEmpty {
                        participantsCard
                    }

                    Spacer(minLength: 18)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }

            VStack(spacing: 12) {
                Spacer()

                joinButton

                Button(action: onDismiss) {
                    Text(tr("cfi_not_now"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 18)
            }
            .padding(.horizontal, 20)
        }
        .onReceive(timer) { date in
            now = date
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.86)) {
                appeared = true
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 38, height: 38)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 6) {
                if hasStarted && !isExpired {
                    Circle()
                        .fill(greenAccent)
                        .frame(width: 7, height: 7)

                    Text("LIVE")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(greenAccent)
                } else {
                    Text("CREW")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(accent)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(
                Capsule()
                    .fill((hasStarted ? greenAccent : accent).opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke((hasStarted ? greenAccent : accent).opacity(0.22), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Crew Header

    private var crewHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [accent, secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 2)
                    )
                    .shadow(color: accent.opacity(0.4), radius: 18, y: 8)

                Text(String(payload.crewName.prefix(1)).uppercased())
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .scaleEffect(appeared ? 1.0 : 0.7)

            Text(payload.crewName)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }

    // MARK: - Invite Message

    private var inviteMessage: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 12, weight: .black))
                Text(tr("cfi_focus_invite_caps"))
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(2.0)
            }
            .foregroundStyle(accent)

            Text("\(payload.hostName) seni focusa\ndavet ediyor")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.96))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
        }
    }

    // MARK: - Task Card

    private func taskCard(title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checklist")
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(accent)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(accent.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(tr("ct_task_caps"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.42))

                Text(title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Duration Card

    private var durationCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                durationCell(
                    title: tr("cfi_total_time_caps"),
                    value: "\(payload.durationMinutes) dk",
                    subtitle: nil,
                    icon: "clock.fill",
                    accent: accent
                )

                if hasStarted {
                    durationCell(
                        title: isExpired ? "TAMAMLANDI" : tr("now_label_caps"),
                        value: isExpired ? "Bitti" : "\(elapsedMinutes). dk",
                        subtitle: isExpired ? nil : tr("rel_min_left", remainingMinutes),
                        icon: isExpired ? "checkmark.circle.fill" : "play.fill",
                        accent: isExpired ? greenAccent : secondaryAccent
                    )
                } else {
                    durationCell(
                        title: "DURUM",
                        value: "Bekliyor",
                        subtitle: tr("cfi_not_started"),
                        icon: "hourglass",
                        accent: secondaryAccent
                    )
                }
            }

            // Progress bar (sadece başladıysa)
            if hasStarted && !isExpired {
                progressBar
            }
        }
    }

    private func durationCell(
        title: String,
        value: String,
        subtitle: String?,
        icon: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .black))
                Text(title)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.2)
            }
            .foregroundStyle(accent)

            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            } else {
                Spacer().frame(height: 14)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accent.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private var progressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent, secondaryAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(4, geo.size.width * progress), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text("0 dk")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))

                Spacer()

                Text(tr("cfi_percent_done", Int(progress * 100)))
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.62))

                Spacer()

                Text("\(payload.durationMinutes) dk")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Participants Card

    private var participantsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 12, weight: .black))

                Text("KATILANLAR")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.6)

                Spacer()

                Text("\(payload.participantNames.count)/\(payload.totalParticipants)")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
            }
            .foregroundStyle(accent)

            VStack(spacing: 8) {
                ForEach(Array(payload.participantNames.enumerated()), id: \.offset) { index, name in
                    participantRow(
                        name: name,
                        isHost: name == payload.hostName,
                        index: index
                    )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.075), lineWidth: 1)
                )
        )
    }

    private func participantRow(name: String, isHost: Bool, index: Int) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(greenAccent)
                .frame(width: 8, height: 8)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(name)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)

            Spacer()

            if isHost {
                Text("HOST")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(secondaryAccent)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(
                        Capsule()
                            .fill(secondaryAccent.opacity(0.16))
                    )
            } else {
                Text("KATILDI")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(greenAccent.opacity(0.85))
            }
        }
    }

    // MARK: - Join Button

    private var joinButton: some View {
        Button {
            guard !isJoining else { return }
            isJoining = true
            onJoin()
        } label: {
            HStack(spacing: 10) {
                if isJoining {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .black))
                }

                Text(isJoining ? tr("cfi_joining") : tr("cfi_join_start"))
                    .font(.system(size: 17, weight: .black, design: .rounded))

                if !isJoining {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .black))
                }
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent, secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: accent.opacity(0.4), radius: 18, y: 10)
        }
        .buttonStyle(.plain)
        .disabled(isJoining || isExpired)
        .opacity(isExpired ? 0.45 : 1)
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(arenaHex: "#11060A"),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(accent.opacity(0.20))
                .frame(width: 380, height: 380)
                .blur(radius: 100)
                .offset(x: 140, y: -240)

            Circle()
                .fill(secondaryAccent.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 95)
                .offset(x: -130, y: 320)
        }
    }
}
