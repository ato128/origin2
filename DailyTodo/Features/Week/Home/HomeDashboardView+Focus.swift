//
//  HomeDashboardView+Focus.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI
import SwiftData

extension HomeDashboardView {

    var focusCard: some View {
        Group {
            if let task = focusTask {
                let accent = focusAccentColor(for: task)
                let isLinkedToCurrentFocus = isCurrentFocusTask(task)

                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(focusSectionTitle(for: task))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(palette.secondaryText)

                            HStack(spacing: 6) {
                                Text(task.title)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundStyle(palette.primaryText)
                                    .lineLimit(1)

                                if isLinkedToCurrentFocus {
                                    focusStateTag(title: "Odakta", tint: accent)
                                }
                            }

                            Text(focusReasonText(for: task))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(palette.secondaryText)
                        }

                        Spacer()

                        ZStack {
                            Circle()
                                .fill(accent.opacity(0.14))
                                .frame(width: 46, height: 46)

                            Image(systemName: focusSymbol(for: task))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(accent)
                        }
                    }

                    HStack(spacing: 8) {
                        if let due = task.dueDate {
                            miniBadge(
                                icon: "clock.fill",
                                text: due.formatted(date: .omitted, time: .shortened),
                                tint: palette.secondaryText
                            )
                        }

                        miniBadge(
                            icon: "scope",
                            text: focusCardStatusTextStudent,
                            tint: accent
                        )

                        if !task.courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            miniBadge(
                                icon: "book.closed.fill",
                                text: task.courseName,
                                tint: accent.opacity(0.95)
                            )
                        }

                        Spacer()
                    }

                    Button {
                        startInlineFocus()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 13, weight: .bold))

                            Text("25 dk Başlat")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [accent, accent.opacity(0.88)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .foregroundStyle(.white)
                        .shadow(color: accent.opacity(0.20), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(palette.cardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(
                                    RadialGradient(
                                        colors: [accent.opacity(0.10), Color.clear],
                                        center: .topTrailing,
                                        startRadius: 10,
                                        endRadius: 220
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(accent.opacity(0.16), lineWidth: 1)
                        )
                )
                .shadow(color: accent.opacity(0.08), radius: 12, x: 0, y: 5)
            }
        }
    }

    var activeFocusCard: some View {
        homeLiveFocusCard
    }

    func crewSharedFocusCard(session: CrewFocusSessionDTO) -> some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let remaining = backendCrewFocusRemainingSeconds(for: session, now: now)
            let liveTimeText = backendCrewFocusTimeText(for: session, now: now)
            let total = Double(session.duration_minutes * 60)
            let progress = total > 0 ? min(1, max(0, 1 - Double(remaining) / total)) : 0
            let accent = backendCrewFocusAccentColor(for: session, now: now)
            let isFinished = !session.is_active || remaining <= 0

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Ortak Odak")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.secondaryText)

                        Text(session.title)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)
                            .lineLimit(1)

                        Text("\(session.host_name) başlattı")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                    }

                    Spacer()

                    Text(isFinished ? "Bitti" : liveTimeText)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(isFinished ? .green : palette.primaryText)
                        .monospacedDigit()
                }

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(palette.secondaryCardFill)
                        .frame(height: 8)

                    GeometryReader { geo in
                        Capsule()
                            .fill(accent)
                            .frame(
                                width: max(10, geo.size.width * (isFinished ? 1 : progress)),
                                height: 8
                            )
                    }
                }
                .frame(height: 8)

                HStack(spacing: 10) {
                    Button {
                        guard !isFinished else { return }
                        NotificationCenter.default.post(
                            name: .openCrewFocusFromNotification,
                            object: session.crew_id.uuidString
                        )
                    } label: {
                        Text(isFinished ? "Tamamlandı" : "Katıl")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(isFinished ? Color.green : Color.accentColor)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isFinished)

                    Button {
                        guard !isFinished else { return }
                        NotificationCenter.default.post(
                            name: .openCrewFocusFromNotification,
                            object: session.crew_id.uuidString
                        )
                    } label: {
                        Text("Aç")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(accent.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isFinished)
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(palette.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [accent.opacity(0.10), Color.clear],
                                    center: .topLeading,
                                    startRadius: 20,
                                    endRadius: 220
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(accent.opacity(0.18), lineWidth: 1)
                    )
            )
        }
    }

    var multiCrewFocusCard: some View {
        let sessions = activeCrewFocusSessions
        let primary = sessions.first
        let totalCount = sessions.count

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ortak Odak")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.secondaryText)

                    Text("Birden Fazla Aktif Crew Focus")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(2)

                    if let primary {
                        Text("\(primary.host_name) dahil \(totalCount) aktif oturum var")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                    } else {
                        Text("\(totalCount) aktif oturum var")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                    }
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.pink.opacity(0.14))
                        .frame(width: 48, height: 48)

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.pink)
                }
            }

            VStack(spacing: 10) {
                ForEach(Array(sessions.prefix(3)), id: \.id) { session in
                    Button {
                        NotificationCenter.default.post(
                            name: .openCrewFocusFromNotification,
                            object: session.crew_id.uuidString
                        )
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(session.title)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(palette.primaryText)
                                    .lineLimit(1)

                                Text("\(session.host_name) • \(session.duration_minutes) dk")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(palette.secondaryText)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text("Katıl")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .frame(height: 30)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.accentColor)
                                )
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(palette.secondaryCardFill.opacity(0.85))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 10) {
                Button {
                    if let first = sessions.first {
                        NotificationCenter.default.post(
                            name: .openCrewFocusFromNotification,
                            object: first.crew_id.uuidString
                        )
                    }
                } label: {
                    Text("İlk Oturumu Aç")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
                .disabled(sessions.isEmpty)

                Button {
                    if let first = sessions.first {
                        NotificationCenter.default.post(
                            name: .openCrewFocusFromNotification,
                            object: first.crew_id.uuidString
                        )
                    }
                } label: {
                    Text("Tümünü Gör")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.pink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.pink.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [Color.pink.opacity(0.10), Color.clear],
                                center: .topLeading,
                                startRadius: 14,
                                endRadius: 220
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.pink.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: Color.pink.opacity(0.08), radius: 12, x: 0, y: 5)
    }

    var homeLiveFocusCard: some View {
        TimelineView(.animation) { _ in
            let remaining = max(0, focusSession.remainingSeconds)
            let minutes = remaining / 60
            let seconds = remaining % 60
            let timeText = String(format: "%02d:%02d", minutes, seconds)
            let accent = liveHomeFocusAccentColor(remaining: remaining)
            let progress = max(0.02, focusSession.progress)
            let isFinished = !focusSession.isSessionActive && remaining == 0

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(homeLiveFocusSectionTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.secondaryText)

                        HStack(spacing: 6) {
                            Text(homeLiveFocusMainTitle)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.primaryText)
                                .lineLimit(1)

                            focusStateTag(
                                title: homeLiveFocusBadgeText,
                                tint: accent
                            )
                        }

                        Text(homeLiveFocusSubtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(palette.secondaryText)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 5) {
                        Text(timeText)
                            .font(.system(size: 25, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(accent)

                        if focusSession.selectedMode == .crew {
                            Text("\(focusSession.readyCount)/\(max(focusSession.participantCount, 1)) hazır")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.secondaryText)
                        }
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(palette.secondaryCardFill.opacity(0.9))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accent.opacity(0.95),
                                        accent.opacity(0.75)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(12, geo.size.width * progress))
                            .shadow(color: accent.opacity(0.18), radius: 8, x: 0, y: 3)
                    }
                }
                .frame(height: 8)

                HStack(spacing: 8) {
                    miniBadge(
                        icon: focusSession.isPaused ? "pause.fill" : "timer",
                        text: homeLiveFocusStatusText(remaining: remaining),
                        tint: accent
                    )

                    if focusSession.selectedMode == .crew {
                        miniBadge(
                            icon: "person.3.fill",
                            text: focusSession.hostName ?? "Crew",
                            tint: accent.opacity(0.95)
                        )
                    } else if focusSession.selectedMode == .personal {
                        miniBadge(
                            icon: "sparkles",
                            text: focusSession.selectedGoal.title,
                            tint: accent.opacity(0.95)
                        )
                    } else {
                        miniBadge(
                            icon: "person.2.fill",
                            text: "Shared",
                            tint: accent.opacity(0.95)
                        )
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    Button {
                        if focusSession.selectedMode == .crew {
                            if let crewID = focusSession.currentCrewID,
                               let sessionDTO = crewStore.activeFocusSessionByCrew[crewID],
                               sessionDTO.is_active {
                                NotificationCenter.default.post(
                                    name: .openCrewFocusFromNotification,
                                    object: sessionDTO.crew_id.uuidString
                                )
                            } else {
                                focusSession.expandSession()
                            }
                        } else {
                            focusSession.expandSession()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: focusSession.selectedMode == .crew ? "person.3.fill" : "arrow.up.forward.app.fill")
                                .font(.system(size: 13, weight: .bold))

                            Text(focusSession.selectedMode == .crew ? "Aç" : "Devam Et")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.accentColor.opacity(0.96),
                                            Color.accentColor.opacity(0.82)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isFinished)

                    Button {
                        focusSession.expandSession()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 13, weight: .bold))

                            Text("Yönet")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(accent.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isFinished)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(palette.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [accent.opacity(0.12), Color.clear],
                                    center: .topLeading,
                                    startRadius: 12,
                                    endRadius: 220
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [accent.opacity(0.07), Color.clear],
                                    center: .bottomTrailing,
                                    startRadius: 10,
                                    endRadius: 180
                                )
                            )
                            .blur(radius: 14)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(accent.opacity(0.18), lineWidth: 1)
                    )
            )
            .shadow(color: accent.opacity(0.08), radius: 12, x: 0, y: 5)
        }
    }

    func liveHomeFocusAccentColor(remaining: Int) -> Color {
        if focusSession.isPaused { return .orange }

        if remaining <= 60 {
            return .red
        }

        switch focusSession.selectedMode {
        case .personal:
            return .blue
        case .crew:
            return .pink
        case .friend:
            return .purple
        }
    }

    var homeLiveFocusSectionTitle: String {
        switch focusSession.selectedMode {
        case .personal:
            return "Aktif Odak"
        case .crew:
            return "Ortak Odak"
        case .friend:
            return "Birlikte Odak"
        }
    }

    var homeLiveFocusMainTitle: String {
        switch focusSession.selectedMode {
        case .personal:
            return focusSession.selectedGoal.title.isEmpty ? "Odak Oturumu" : "\(focusSession.selectedGoal.title) Focus"
        case .crew:
            return "Crew Focus"
        case .friend:
            return "Friend Focus"
        }
    }

    var homeLiveFocusSubtitle: String {
        if focusSession.isPaused {
            return "Oturum şu an beklemede"
        }

        switch focusSession.selectedMode {
        case .personal:
            return "Kişisel focus akışı aktif"
        case .crew:
            if let host = focusSession.hostName, !host.isEmpty {
                return "\(host) başlattı"
            }
            return "Ortak odak devam ediyor"
        case .friend:
            return "Birlikte odak devam ediyor"
        }
    }

    var homeLiveFocusBadgeText: String {
        if focusSession.isPaused { return "Durdu" }

        switch focusSession.selectedMode {
        case .personal:
            return "Aktif"
        case .crew:
            return "Canlı"
        case .friend:
            return "Birlikte"
        }
    }

    func homeLiveFocusStatusText(remaining: Int) -> String {
        if focusSession.isPaused {
            return "Beklemede"
        }

        if remaining <= 60 {
            return "Son dakika"
        }

        if remaining <= 300 {
            return "Yakında bitiyor"
        }

        return "Devam ediyor"
    }

    func focusStateTag(title: String, tint: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Capsule().fill(tint.opacity(0.14)))
    }

    var focusCardStatusTextStudent: String {
        guard let task = focusTask else { return "Bugün için öneri yok" }
        if store.isOverdue(task) { return "Öncelikli" }
        if let due = task.dueDate, Calendar.current.isDateInToday(due) { return "Sıradaki odak" }
        return "Hazır"
    }

    func focusSectionTitle(for task: DTTaskItem) -> String {
        if store.isOverdue(task) { return "Öncelikli Odak" }
        if let due = task.dueDate, Calendar.current.isDateInToday(due) { return "Bugünün Odak Noktası" }
        return "Çalışma Seansı"
    }

    func focusReasonText(for task: DTTaskItem) -> String {
        if store.isOverdue(task) {
            return "Bu görev gecikmiş. Önce bunu temizlemek iyi olur."
        }

        if let due = task.dueDate {
            let minutes = Int(due.timeIntervalSinceNow / 60)
            if minutes > 0 && minutes <= 90 {
                return "Teslime yakın. Kısa bir odak çok iş çıkarır."
            }
            if Calendar.current.isDateInToday(due) {
                return "Bugün bitirmen iyi olur."
            }
        }

        return "Şimdi başlamak için uygun bir görev."
    }

    func focusAccentColor(for task: DTTaskItem) -> Color {
        if store.isOverdue(task) { return .red }

        switch task.taskType.lowercased() {
        case "exam":
            return .orange
        case "project":
            return .purple
        case "workout":
            return .green
        case "study":
            return .blue
        case "homework":
            return .pink
        default:
            return .accentColor
        }
    }

    func focusSymbol(for task: DTTaskItem) -> String {
        switch task.taskType.lowercased() {
        case "exam":
            return "doc.text.fill"
        case "project":
            return "folder.fill"
        case "workout":
            return "dumbbell.fill"
        case "study":
            return "brain.head.profile"
        case "homework":
            return "book.closed.fill"
        default:
            return "scope"
        }
    }

    func isCurrentFocusTask(_ task: DTTaskItem) -> Bool {
        guard focusSession.isSessionActive else { return false }
        return focusSession.selectedMode == .personal
    }
}
