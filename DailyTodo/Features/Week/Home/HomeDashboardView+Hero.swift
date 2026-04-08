//
//  HomeDashboardView+Hero.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 30.03.2026.
//

import SwiftUI

enum HomeHeroKind: String {
    case sharedFocusActive
    case personalFocusActive
    case overdueTask
    case nextClass
    case todayPriorityTask
    case upcomingExam
    case socialFollowUp
    case crewFollowUp
    case insightsFollowUp
    case noTaskPrompt
    case wrapUp
}

struct HomeHeroCandidate: Identifiable {
    let id = UUID()
    let kind: HomeHeroKind
    let priority: Int
    let state: TodayHeroState
}

struct HeroBadge {
    let icon: String
    let text: String
    let tint: Color
}

struct HeroCTA {
    let title: String
    let icon: String
    let action: () -> Void
}

struct TodayHeroState {
    let eyebrow: String
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color

    let badge1: HeroBadge?
    let badge2: HeroBadge?

    let contextLine: String

    let primaryCTA: String
    let primaryIcon: String
    let primaryAction: () -> Void

    let secondaryCTA: HeroCTA?
}

extension HomeDashboardView {

    enum HeroDayPhase {
        case morning
        case afternoon
        case evening
        case night
    }

    // MARK: - Main Top Section

    var todayHeroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            todayWhatHeader

            HStack(alignment: .top, spacing: 12) {
                progressSummaryCard

                VStack(spacing: 12) {
                    streakMiniCard
                    priorityMiniCard
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var todayWhatHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BUGÜN NE VAR")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(palette.secondaryText.opacity(0.9))
                .tracking(0.5)

            Text(todayWhatTitle)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(todayWhatSubtitle)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var progressSummaryCard: some View {
        Button {
            if todayPendingBoardCount > 0 {
                showTasksShortcut = true
            } else if shouldShowNoTaskPromptHero {
                onAddTask()
            } else {
                onOpenInsights()
            }
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 6)
                            .frame(width: 54, height: 54)

                        Circle()
                            .trim(from: 0, to: max(todayProgressValue, shouldShowNoTaskPromptHero ? 0.02 : 0.06))
                            .stroke(
                                LinearGradient(
                                    colors: [progressCardAccent.opacity(0.75), progressCardAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 54, height: 54)

                        Text("\(Int(todayProgressValue * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(progressCardAccent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(completedTodayBoardCount)/\(max(todayBoardTasks.count, 1))")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)

                        Text(progressCardCaption)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(palette.secondaryText)
                    }

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                Text(progressCardBottomText)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(progressCardAccent)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
            .background(topCardBackground(accent: progressCardAccent))
        }
        .buttonStyle(.plain)
    }

    private var streakMiniCard: some View {
        Button {
            onOpenInsights()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("🔥 SERİ")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.orange)
                    .tracking(0.4)

                Text("\(streakCount)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.orange)

                Text("gün üst üste")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .background(topCardBackground(accent: .orange))
        }
        .buttonStyle(.plain)
    }

    private var priorityMiniCard: some View {
        Button {
            priorityMiniCardAction()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(priorityMiniEyebrow)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(priorityMiniAccent)
                    .tracking(0.4)

                Text(priorityMiniTitle)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(priorityMiniSubtitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .background(topCardBackground(accent: priorityMiniAccent))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Mapping

    var todayWhatTitle: String {
        if let exam = nearestRelevantExam {
            let course = exam.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
            return course.isEmpty ? exam.title : course
        }

        if let event = nextEvent {
            return event.title
        }

        if todayPendingBoardCount == 0 && completedTodayBoardCount > 0 {
            return "Bugün tamam"
        }

        if shouldShowNoTaskPromptHero {
            return "Bugün boş"
        }

        if let task = focusTask {
            return task.title
        }

        return "Bugün ne var?"
    }

    var todayWhatSubtitle: String {
        if let exam = nearestRelevantExam {
            return "\(exam.examType) • \(examCountdownText(exam))"
        }

        if let event = nextEvent {
            if isNextClassLiveNow {
                return "Şu an aktif ders"
            }
            if let minutes = nextClassStartsInMinutes {
                return "\(minutes) dk sonra başlıyor"
            }
            return "Bugünün sıradaki dersi"
        }

        if todayPendingBoardCount == 0 && completedTodayBoardCount > 0 {
            return "Günü temiz kapattın"
        }

        if shouldShowNoTaskPromptHero {
            return "İstersen küçük bir başlangıç yap"
        }

        return homePriorityLine
    }

    var progressCardAccent: Color {
        if shouldShowNoTaskPromptHero { return .purple }
        if todayPendingBoardCount == 0 && completedTodayBoardCount > 0 { return .green }
        if todayProgressValue >= 0.6 { return .green }
        if todayProgressValue > 0 { return .blue }
        return .blue
    }

    var progressCardCaption: String {
        if shouldShowNoTaskPromptHero {
            return "plan yok"
        }

        if todayPendingBoardCount == 0 && completedTodayBoardCount > 0 {
            return "tamamlandı"
        }

        return "tamamlandı"
    }

    var progressCardBottomText: String {
        if shouldShowNoTaskPromptHero {
            switch heroDayPhase {
            case .morning: return "Küçük bir başlangıç yap"
            case .afternoon: return "Günü hareket ettir"
            case .evening, .night: return "Yarını boş bırakma"
            }
        }

        if todayPendingBoardCount == 0 && completedTodayBoardCount > 0 {
            return "Harika gidiyorsun"
        }

        if todayProgressValue == 0 {
            return "Hadi başlayalım!"
        }

        if todayProgressValue < 1 {
            return "Devam et"
        }

        return "Harika"
    }

    var priorityMiniEyebrow: String {
        if nearestRelevantExam != nil {
            return "📌 SINAV"
        }

        if nextEvent != nil {
            return "📚 DERS"
        }

        if todayPendingBoardCount == 0 && completedTodayBoardCount > 0 {
            return "✅ BUGÜN"
        }

        return "✨ PLAN"
    }

    var priorityMiniTitle: String {
        if let exam = nearestRelevantExam {
            let course = exam.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
            return course.isEmpty ? exam.title : "\(course)\n\(exam.examType)"
        }

        if let event = nextEvent {
            return event.title
        }

        if todayPendingBoardCount == 0 && completedTodayBoardCount > 0 {
            return "Tamamlandı"
        }

        return "Boş gün"
    }

    var priorityMiniSubtitle: String {
        if let exam = nearestRelevantExam {
            return "\(examCountdownText(exam)) • \(suggestedStudyMinutes(for: exam)) dk"
        }

        if let event = nextEvent {
            if isNextClassLiveNow {
                return "Şimdi aktif"
            }
            if let minutes = nextClassStartsInMinutes {
                return "\(minutes) dk sonra"
            }
            return nextEventTimeText
        }

        if todayPendingBoardCount == 0 && completedTodayBoardCount > 0 {
            return "\(completedTodayBoardCount) görev bitti"
        }

        return "Kendin planla"
    }

    var priorityMiniAccent: Color {
        if nearestRelevantExam != nil { return .pink }
        if nextEvent != nil { return .blue }
        if todayPendingBoardCount == 0 && completedTodayBoardCount > 0 { return .green }
        return .purple
    }

    func priorityMiniCardAction() {
        if nearestRelevantExam != nil {
            onOpenWeek()
            return
        }

        if nextEvent != nil {
            onOpenWeek()
            return
        }

        if todayPendingBoardCount == 0 && completedTodayBoardCount > 0 {
            showTasksShortcut = true
            return
        }

        onAddTask()
    }

    // MARK: - Existing Hero Logic

    var resolvedHeroKind: HomeHeroKind {
        let candidates = buildHeroCandidates()
        let best = candidates.max { $0.priority < $1.priority }
        return best?.kind ?? .wrapUp
    }

    var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    var heroDayPhase: HeroDayPhase {
        switch currentHour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }

    var hasRecentFriendConversation: Bool {
        recentChatFriend != nil
    }

    var socialFollowUpTitle: String {
        if let friend = recentChatFriend {
            return "\(friend.name) ile devam et"
        }
        return "Sosyal akışa göz at"
    }

    var isNextClassLiveNow: Bool {
        guard let nextEvent else { return false }
        let now = currentMinuteOfDay()
        let start = nextEvent.startMinute
        let end = nextEvent.startMinute + nextEvent.durationMinute
        return now >= start && now < end
    }

    var isNextClassStartingSoon: Bool {
        guard let nextEvent else { return false }
        let now = currentMinuteOfDay()
        let diff = nextEvent.startMinute - now
        return diff > 0 && diff <= 20
    }

    var nextClassStartsInMinutes: Int? {
        guard let nextEvent else { return nil }
        let now = currentMinuteOfDay()
        let diff = nextEvent.startMinute - now
        return diff > 0 ? diff : nil
    }

    var nextEventTimeText: String {
        guard let event = nextEvent else { return "Bugün" }
        return "\(hm(event.startMinute)) • \(event.durationMinute) dk"
    }

    var hasNoTaskAtAllToday: Bool {
        todayBoardTasks.isEmpty
    }

    var shouldShowNoTaskPromptHero: Bool {
        hasNoTaskAtAllToday &&
        nearestRelevantExam == nil &&
        !isFocusActive &&
        !hasAnyActiveFocusSession &&
        activeBackendCrewFocusSession == nil &&
        !hasRecentFriendConversation &&
        !hasCrewWorkToDo
    }

    var noTaskPromptHeroState: TodayHeroState {
        switch heroDayPhase {
        case .morning:
            return TodayHeroState(
                eyebrow: "Temiz başlangıç",
                title: "Bugünü netleştir",
                subtitle: "Henüz görev görünmüyor. Küçük bir başlangıç yeterli.",
                icon: "sparkles",
                accent: .blue,
                badge1: HeroBadge(icon: "sun.max.fill", text: "Sabah", tint: .orange),
                badge2: HeroBadge(icon: "checklist", text: "Boş akış", tint: .blue),
                contextLine: "İlk görevini belirlemek günün yönünü netleştirir.",
                primaryCTA: "Görev Ekle",
                primaryIcon: "plus",
                primaryAction: { onAddTask() },
                secondaryCTA: HeroCTA(title: "Hafta", icon: "calendar", action: { onOpenWeek() })
            )

        case .afternoon:
            return TodayHeroState(
                eyebrow: "Henüz plan oluşmadı",
                title: "Günü hareket ettir",
                subtitle: "Tek bir küçük görev bile ritmi başlatabilir.",
                icon: "bolt.fill",
                accent: .green,
                badge1: HeroBadge(icon: "clock.fill", text: "Öğle", tint: .orange),
                badge2: HeroBadge(icon: "checklist", text: "Boş akış", tint: .green),
                contextLine: "Kısa ve net bir görev eklemek günü toparlar.",
                primaryCTA: "Görev Ekle",
                primaryIcon: "plus",
                primaryAction: { onAddTask() },
                secondaryCTA: HeroCTA(title: "Hafta", icon: "calendar", action: { onOpenWeek() })
            )

        case .evening, .night:
            return TodayHeroState(
                eyebrow: "Akşam kapanışı",
                title: "Yarını boş bırakma",
                subtitle: "Yarın için 1–2 küçük adım belirlemek iyi olabilir.",
                icon: "calendar.badge.plus",
                accent: .purple,
                badge1: HeroBadge(icon: "moon.stars.fill", text: "Akşam", tint: .purple),
                badge2: HeroBadge(icon: "calendar", text: "Yarın", tint: .blue),
                contextLine: "Şimdi yapılan küçük bir plan sabahı kolaylaştırır.",
                primaryCTA: "Yarını Planla",
                primaryIcon: "calendar.badge.plus",
                primaryAction: { onOpenWeek() },
                secondaryCTA: HeroCTA(title: "Görev Ekle", icon: "plus", action: { onAddTask() })
            )
        }
    }

    func sharedFocusHeroState(_ activeSession: CrewFocusSessionDTO) -> TodayHeroState {
        TodayHeroState(
            eyebrow: "Ortak odak aktif",
            title: activeSession.title,
            subtitle: "\(activeSession.host_name) ile oturum devam ediyor.",
            icon: activeSession.is_paused ? "pause.fill" : "person.2.fill",
            accent: activeSession.is_paused ? .orange : .blue,
            badge1: HeroBadge(
                icon: "timer",
                text: backendCrewFocusTimeText(for: activeSession, now: Date()),
                tint: activeSession.is_paused ? .orange : .blue
            ),
            badge2: HeroBadge(icon: "person.2.fill", text: "Crew", tint: .pink),
            contextLine: activeSession.is_paused ? "Oturum duraklatılmış." : "Şu an ekip odağı aktif.",
            primaryCTA: "Odayı Aç",
            primaryIcon: "arrow.right.circle.fill",
            primaryAction: { focusRoomSession = activeSession },
            secondaryCTA: HeroCTA(title: "Crew", icon: "person.3.fill", action: { onOpenWeek() })
        )
    }

    var personalFocusFollowUpHeroState: TodayHeroState {
        let title = activeFocusTaskTitle.isEmpty ? "Odak devam ediyor" : activeFocusTaskTitle

        return TodayHeroState(
            eyebrow: "Akış sürüyor",
            title: title,
            subtitle: "Şimdilik ritmi koru.",
            icon: focusWorkoutMode ? "figure.strengthtraining.traditional" : "sparkles",
            accent: .blue,
            badge1: HeroBadge(icon: "scope", text: "Odak açık", tint: .blue),
            badge2: HeroBadge(icon: "calendar", text: "Bugün", tint: .blue),
            contextLine: "İstersen görevleri ya da haftayı hızlıca açabilirsin.",
            primaryCTA: "Devam Et",
            primaryIcon: "play.fill",
            primaryAction: { showTasksShortcut = true },
            secondaryCTA: HeroCTA(title: "Hafta", icon: "calendar", action: { onOpenWeek() })
        )
    }

    func nextClassHeroState(_ event: EventItem) -> TodayHeroState {
        let accent = hexColor(event.colorHex)

        let subtitle: String
        let context: String
        let primaryCTA: String

        if isNextClassLiveNow {
            subtitle = "Şu an \(event.title) dersindesin."
            context = "Ders bitince ritmini koru."
            primaryCTA = "Haftayı Aç"
        } else {
            let minutes = nextClassStartsInMinutes ?? 0
            subtitle = "\(minutes) dk sonra \(event.title) başlıyor."
            context = "Ders öncesi zihnini toparlamak iyi olabilir."
            primaryCTA = "Programa Git"
        }

        return TodayHeroState(
            eyebrow: isNextClassLiveNow ? "Şu an aktif" : "Sıradaki ders",
            title: event.title,
            subtitle: subtitle,
            icon: "book.closed.fill",
            accent: accent,
            badge1: HeroBadge(
                icon: isNextClassLiveNow ? "dot.radiowaves.left.and.right" : "clock.fill",
                text: nextEventTimeText,
                tint: accent
            ),
            badge2: HeroBadge(icon: "calendar", text: "Bugün", tint: .blue),
            contextLine: context,
            primaryCTA: primaryCTA,
            primaryIcon: "calendar",
            primaryAction: { onOpenWeek() },
            secondaryCTA: HeroCTA(title: "Görevler", icon: "list.bullet", action: { showTasksShortcut = true })
        )
    }

    var socialFollowUpHeroState: TodayHeroState {
        let title = socialFollowUpTitle
        let subtitle = recentChatFriend != nil ? "İstersen kaldığın yerden devam et." : "Arkadaşlarınla bağlantıda kal."

        return TodayHeroState(
            eyebrow: "Sosyal akış",
            title: title,
            subtitle: subtitle,
            icon: "bubble.left.and.bubble.right.fill",
            accent: .blue,
            badge1: HeroBadge(icon: "message.fill", text: "Sohbet", tint: .blue),
            badge2: HeroBadge(icon: "person.2.fill", text: "Arkadaşlar", tint: .pink),
            contextLine: "Kısa bir mesaj bile seni akışa geri bağlayabilir.",
            primaryCTA: "Sohbeti Aç",
            primaryIcon: "bubble.left.and.bubble.right.fill",
            primaryAction: {
                if recentChatFriend != nil {
                    showRecentFriendChat = true
                } else {
                    showFriendsShortcut = true
                }
            },
            secondaryCTA: HeroCTA(title: "Crew", icon: "person.3.fill", action: { onOpenWeek() })
        )
    }

    var hasAnyCompletedTaskToday: Bool {
        completedTodayCount > 0
    }

    var hasNoCompletedTaskToday: Bool {
        completedTodayCount == 0
    }

    var shouldShowNightPlanningHero: Bool {
        currentHour >= 20 && todayPendingBoardCount == 0 && !hasNoTaskAtAllToday
    }

    var shouldShowLowMomentumHero: Bool {
        currentHour >= 14 && hasNoCompletedTaskToday && todayPendingBoardCount > 0
    }

    var latestCompletedTodayTaskTitle: String? {
        todayCompletedTasks
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .first?
            .title
    }

    var completionFollowUpHeroStateV2: TodayHeroState {
        let completedTitle = latestCompletedTodayTaskTitle ?? "Görev"

        return TodayHeroState(
            eyebrow: "Güzel ilerliyorsun",
            title: "\(completedTitle) tamamlandı",
            subtitle: "Bugün bir adım attın.",
            icon: "checkmark.circle.fill",
            accent: .green,
            badge1: HeroBadge(icon: "checkmark.circle.fill", text: "Tamamlandı", tint: .green),
            badge2: HeroBadge(icon: "flame.fill", text: "Seri \(streakCount)", tint: .orange),
            contextLine: "İstersen kalan işlere ya da içgörülere geç.",
            primaryCTA: todayPendingBoardCount > 0 ? "Kalanlara Bak" : "İçgörülere Git",
            primaryIcon: todayPendingBoardCount > 0 ? "list.bullet" : "chart.bar.fill",
            primaryAction: {
                if todayPendingBoardCount > 0 {
                    showTasksShortcut = true
                } else {
                    onOpenInsights()
                }
            },
            secondaryCTA: HeroCTA(
                title: hasCrewWorkToDo ? "Crew" : "Hafta",
                icon: hasCrewWorkToDo ? "person.3.fill" : "calendar",
                action: { onOpenWeek() }
            )
        )
    }

    var nightPlanningHeroStateV2: TodayHeroState {
        TodayHeroState(
            eyebrow: "Günü kapat",
            title: "Yarını hafiflet",
            subtitle: "Küçük bir plan yarına çok şey katar.",
            icon: "moon.stars.fill",
            accent: .purple,
            badge1: HeroBadge(icon: "calendar.badge.plus", text: "Yarın", tint: .purple),
            badge2: HeroBadge(icon: "checkmark.circle.fill", text: "Bugün temiz", tint: .green),
            contextLine: "1–2 net adım belirlemek sabahı kolaylaştırır.",
            primaryCTA: "Yarını Planla",
            primaryIcon: "calendar.badge.plus",
            primaryAction: { onOpenWeek() },
            secondaryCTA: HeroCTA(title: "İçgörüler", icon: "chart.bar.fill", action: { onOpenInsights() })
        )
    }

    var lowMomentumHeroStateV2: TodayHeroState {
        TodayHeroState(
            eyebrow: "Küçük bir başlangıç",
            title: "Bugünü hareket ettir",
            subtitle: "Tek bir küçük görev bile akışı başlatabilir.",
            icon: "bolt.fill",
            accent: .orange,
            badge1: HeroBadge(icon: "exclamationmark.circle.fill", text: "Başlangıç lazım", tint: .orange),
            badge2: HeroBadge(icon: "list.bullet", text: "\(todayPendingBoardCount) açık", tint: .blue),
            contextLine: "Mükemmel olmak zorunda değil.",
            primaryCTA: "Görevleri Aç",
            primaryIcon: "list.bullet",
            primaryAction: { showTasksShortcut = true },
            secondaryCTA: HeroCTA(title: "Odak Başlat", icon: "play.fill", action: { startInlineFocus() })
        )
    }

    var upcomingActiveExams: [ExamItem] {
        userScopedExams
            .filter { !$0.isCompleted && $0.examDate >= Calendar.current.startOfDay(for: Date()) }
            .sorted { $0.examDate < $1.examDate }
    }

    var nearestRelevantExam: ExamItem? {
        upcomingActiveExams.first { exam in
            let days = daysUntilExam(exam)
            return days <= 7
        }
    }

    var crewFollowUpHeroState: TodayHeroState {
        TodayHeroState(
            eyebrow: "Sıradaki alan",
            title: "Crew seni bekliyor",
            subtitle: "Kişisel tarafı bitirdin.",
            icon: "person.3.fill",
            accent: .pink,
            badge1: HeroBadge(icon: "checklist", text: "\(activeCrewTaskCount) açık iş", tint: .pink),
            badge2: HeroBadge(icon: "bolt.fill", text: "Crew", tint: .orange),
            contextLine: "Ekip akışını da kapatabilirsin.",
            primaryCTA: "Crew’e Git",
            primaryIcon: "person.3.fill",
            primaryAction: { onOpenWeek() },
            secondaryCTA: HeroCTA(title: "Sohbet", icon: "bubble.left.and.bubble.right.fill", action: { showFriendsShortcut = true })
        )
    }

    var insightsFollowUpHeroState: TodayHeroState {
        TodayHeroState(
            eyebrow: "Bugün bitti",
            title: "Akışını kontrol et",
            subtitle: "Bugünkü ilerlemeni ve ritmini görebilirsin.",
            icon: "chart.bar.fill",
            accent: .blue,
            badge1: HeroBadge(icon: "flame.fill", text: "Seri \(streakCount)", tint: .orange),
            badge2: HeroBadge(icon: "chart.bar.fill", text: "Insights", tint: .blue),
            contextLine: "Yarını daha iyi kurmana yardım eder.",
            primaryCTA: "İçgörülere Git",
            primaryIcon: "chart.bar.fill",
            primaryAction: { onOpenInsights() },
            secondaryCTA: HeroCTA(title: "Hafta", icon: "calendar", action: { onOpenWeek() })
        )
    }

    var wrapUpHeroState: TodayHeroState {
        TodayHeroState(
            eyebrow: "Gün tamamlandı",
            title: "Yarını hazırlayabilirsin",
            subtitle: "Bugün sakin kapandı.",
            icon: "calendar.badge.plus",
            accent: .green,
            badge1: HeroBadge(icon: "checkmark.circle.fill", text: "Tamam", tint: .green),
            badge2: HeroBadge(icon: "calendar", text: "Yarın", tint: .blue),
            contextLine: "Kısa bir plan sabah sürtünmesini azaltır.",
            primaryCTA: "Haftayı Aç",
            primaryIcon: "calendar",
            primaryAction: { onOpenWeek() },
            secondaryCTA: HeroCTA(title: "Görev Ekle", icon: "plus", action: { onAddTask() })
        )
    }

    func examHeroPriority(for exam: ExamItem) -> Int {
        let days = daysUntilExam(exam)
        switch days {
        case ...1: return 88
        case 2...3: return 80
        case 4...7: return 68
        default: return 40
        }
    }

    func overdueTaskHeroState(_ task: DTTaskItem) -> TodayHeroState {
        let accent = Color.red
        let course = task.courseName.trimmingCharacters(in: .whitespacesAndNewlines)

        return TodayHeroState(
            eyebrow: "Önce bunu temizle",
            title: task.title,
            subtitle: "Bu görev gecikmiş.",
            icon: focusSymbol(for: task),
            accent: accent,
            badge1: HeroBadge(icon: "exclamationmark.triangle.fill", text: "Gecikmiş", tint: accent),
            badge2: course.isEmpty ? nil : HeroBadge(icon: "book.closed.fill", text: course, tint: accent),
            contextLine: priorityTaskContextLine(for: task),
            primaryCTA: "Başla",
            primaryIcon: "play.fill",
            primaryAction: { startInlineFocus() },
            secondaryCTA: HeroCTA(title: "Tüm Görevler", icon: "list.bullet", action: { showTasksShortcut = true })
        )
    }

    func priorityTaskHeroState(_ task: DTTaskItem) -> TodayHeroState {
        let accent = focusAccentColor(for: task)
        let course = task.courseName.trimmingCharacters(in: .whitespacesAndNewlines)

        return TodayHeroState(
            eyebrow: "Bugünün önceliği",
            title: task.title,
            subtitle: focusCardStatusTextStudent,
            icon: focusSymbol(for: task),
            accent: accent,
            badge1: HeroBadge(icon: "scope", text: dueBadgeText(for: task), tint: accent),
            badge2: course.isEmpty ? nil : HeroBadge(icon: "book.closed.fill", text: course, tint: accent),
            contextLine: priorityTaskContextLine(for: task),
            primaryCTA: "Başla",
            primaryIcon: "play.fill",
            primaryAction: { startInlineFocus() },
            secondaryCTA: HeroCTA(title: "Tüm Görevler", icon: "list.bullet", action: { showTasksShortcut = true })
        )
    }

    func priorityTaskContextLine(for task: DTTaskItem) -> String {
        if store.isOverdue(task) {
            switch heroDayPhase {
            case .morning: return "Güne bunu temizleyerek başlamak iyi olur."
            case .afternoon: return "Bunu bitirmen günü rahatlatır."
            case .evening: return "Akşam kapanmadan bunu temizlemek iyi olur."
            case .night: return "Bunu kapatıp günü daha hafif bitirebilirsin."
            }
        }

        switch heroDayPhase {
        case .morning: return "Erken başlarsan momentum kazanırsın."
        case .afternoon: return "Şimdi başlarsan momentum kazanırsın."
        case .evening: return "Bugün bitirmen akşamı rahatlatır."
        case .night: return "Kısa bir başlangıç bile yarını kolaylaştırır."
        }
    }

    func buildHeroCandidates() -> [HomeHeroCandidate] {
        var candidates: [HomeHeroCandidate] = []

        if let activeSession = activeBackendCrewFocusSession {
            candidates.append(.init(kind: .sharedFocusActive, priority: 100, state: sharedFocusHeroState(activeSession)))
        }

        if isFocusActive || hasAnyActiveFocusSession {
            candidates.append(.init(kind: .personalFocusActive, priority: 95, state: personalFocusFollowUpHeroState))
        }

        if let overdue = todayPendingTasks.first(where: { store.isOverdue($0) }) {
            candidates.append(.init(kind: .overdueTask, priority: 90, state: overdueTaskHeroState(overdue)))
        }

        if let event = nextEvent, isNextClassLiveNow || isNextClassStartingSoon {
            candidates.append(.init(kind: .nextClass, priority: isNextClassLiveNow ? 82 : 70, state: nextClassHeroState(event)))
        }

        if let exam = nearestRelevantExam {
            candidates.append(.init(kind: .upcomingExam, priority: examHeroPriority(for: exam), state: upcomingExamHeroState(exam)))
        }

        if let task = focusTask {
            candidates.append(.init(kind: .todayPriorityTask, priority: 75, state: priorityTaskHeroState(task)))
        }

        if shouldShowLowMomentumHero {
            candidates.append(.init(kind: .todayPriorityTask, priority: 65, state: lowMomentumHeroStateV2))
        }

        if hasAnyCompletedTaskToday && todayPendingBoardCount == 0 {
            candidates.append(.init(kind: .insightsFollowUp, priority: 52, state: completionFollowUpHeroStateV2))
        }

        if hasCompletedAllPersonalTodayTasks && hasCrewWorkToDo {
            candidates.append(.init(kind: .crewFollowUp, priority: 60, state: crewFollowUpHeroState))
        }

        if hasCompletedAllPersonalTodayTasks && hasRecentFriendConversation {
            candidates.append(.init(kind: .socialFollowUp, priority: 50, state: socialFollowUpHeroState))
        }

        if hasCompletedAllPersonalTodayTasks && hasInsightsWorthShowing {
            candidates.append(.init(kind: .insightsFollowUp, priority: 45, state: insightsFollowUpHeroState))
        }

        if shouldShowNoTaskPromptHero {
            candidates.append(.init(kind: .noTaskPrompt, priority: 46, state: noTaskPromptHeroState))
        }

        if shouldShowNightPlanningHero {
            candidates.append(.init(kind: .wrapUp, priority: 48, state: nightPlanningHeroStateV2))
        }

        candidates.append(.init(kind: .wrapUp, priority: 10, state: wrapUpHeroState))
        return candidates
    }

    func resolveHeroState() -> TodayHeroState {
        let candidates = buildHeroCandidates()
        let best = candidates.max { $0.priority < $1.priority }
        return best?.state ?? wrapUpHeroState
    }

    func upcomingExamHeroState(_ exam: ExamItem) -> TodayHeroState {
        let accent = examAccentColor(exam)
        let minutes = suggestedStudyMinutes(for: exam)
        let label = suggestedStudyLabel(for: exam)

        return TodayHeroState(
            eyebrow: "Yaklaşan sınav",
            title: "\(exam.courseName.isEmpty ? exam.title : exam.courseName) \(exam.examType)",
            subtitle: "\(examCountdownText(exam)) • Bugün \(minutes) dk \(label.lowercased()) iyi olabilir.",
            icon: "graduationcap.fill",
            accent: accent,
            badge1: HeroBadge(icon: "calendar", text: examDateText(exam), tint: accent),
            badge2: HeroBadge(icon: "timer", text: "\(minutes) dk", tint: .orange),
            contextLine: "Sınava yaklaşırken küçük ama net bir çalışma bloğu stresi azaltır.",
            primaryCTA: "Başlat",
            primaryIcon: "play.fill",
            primaryAction: { startSuggestedExamFocus(for: exam) },
            secondaryCTA: HeroCTA(title: "Planla", icon: "calendar.badge.plus", action: { onOpenWeek() })
        )
    }

    func topCardBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(0.10),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 8,
                            endRadius: 180
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(accent.opacity(0.12), lineWidth: 1)
            )
    }

    func heroBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(0.10),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 10,
                            endRadius: 240
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                Color.clear,
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }
}
