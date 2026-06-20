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
        ArenaSectionTitle(
            eyebrow: tr("hd_today_caps"),
            title: todayWhatTitle,
            italic: nil,
            accent: Color(arenaHex: AppArenaPalette.cyan)
        )
        .overlay(alignment: .bottomLeading) {
            Text(todayWhatSubtitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.48))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 44)
        }
        .padding(.bottom, 34)
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
                            .stroke(Color.white.opacity(0.08), lineWidth: 7)
                            .frame(width: 58, height: 58)

                        Circle()
                            .trim(from: 0, to: max(todayProgressValue, shouldShowNoTaskPromptHero ? 0.02 : 0.06))
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        progressCardAccent.opacity(0.70),
                                        progressCardAccent,
                                        Color(arenaHex: AppArenaPalette.cyan).opacity(0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 7, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 58, height: 58)

                        Text("\(Int(todayProgressValue * 100))%")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(progressCardAccent)
                            .monospacedDigit()
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(completedTodayBoardCount)/\(max(todayBoardTasks.count, 1))")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()

                        Text(progressCardCaption.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(.white.opacity(0.38))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 6) {
                    Text("TODAY FLOW")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(progressCardAccent.opacity(0.92))

                    Text(progressCardBottomText)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .black))

                    Text(tr("hv_streak_caps"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.3)
                }
                .foregroundStyle(Color(arenaHex: AppArenaPalette.gold))

                Text("\(streakCount)")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(Color(arenaHex: AppArenaPalette.gold))
                    .monospacedDigit()

                Text(tr("hd_days_streak"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(15)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
            .background(topCardBackground(accent: Color(arenaHex: AppArenaPalette.gold)))
        }
        .buttonStyle(.plain)
    }

    private var priorityMiniCard: some View {
        Button {
            priorityMiniCardAction()
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                Text(priorityMiniEyebrow.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(priorityMiniAccent)

                Text(priorityMiniTitle)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(priorityMiniSubtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 0)
            }
            .padding(15)
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
            return tr("hd_today_done")
        }

        if shouldShowNoTaskPromptHero {
            return tr("hd_today_empty")
        }

        if let task = focusTask {
            return task.title
        }

        return tr("hd_whats_today")
    }

    var todayWhatSubtitle: String {
        if let exam = nearestRelevantExam {
            return "\(exam.examType) • \(examCountdownText(exam))"
        }

        if let event = nextEvent {
            if isNextClassLiveNow {
                return tr("hd_active_class")
            }
            if let minutes = nextClassStartsInMinutes {
                return tr("hd_starts_in_min", minutes)
            }
            return tr("hd_next_class")
        }

        if todayPendingBoardCount == 0 && completedTodayBoardCount > 0 {
            return tr("hd_clean_day")
        }

        if shouldShowNoTaskPromptHero {
            return tr("hd_small_start_opt")
        }

        return homePriorityLine
    }

    var progressCardAccent: Color {
        if shouldShowNoTaskPromptHero {
            return Color(arenaHex: AppArenaPalette.purple)
        }

        if todayPendingBoardCount == 0 && completedTodayBoardCount > 0 {
            return Color(arenaHex: AppArenaPalette.green)
        }

        if todayProgressValue >= 0.6 {
            return Color(arenaHex: AppArenaPalette.green)
        }

        if todayProgressValue > 0 {
            return Color(arenaHex: AppArenaPalette.blue)
        }

        return Color(arenaHex: AppArenaPalette.cyan)
    }

    var priorityMiniAccent: Color {
        if nearestRelevantExam != nil {
            return Color(arenaHex: AppArenaPalette.coral)
        }

        if nextEvent != nil {
            return Color(arenaHex: AppArenaPalette.blue)
        }

        if todayPendingBoardCount == 0 && completedTodayBoardCount > 0 {
            return Color(arenaHex: AppArenaPalette.green)
        }

        return Color(arenaHex: AppArenaPalette.purple)
    }
    var progressCardCaption: String {
        if shouldShowNoTaskPromptHero {
            return "plan yok"
        }

        if todayPendingBoardCount == 0 && completedTodayBoardCount > 0 {
            return tr("done_word")
        }

        return tr("done_word")
    }

    var progressCardBottomText: String {
        if shouldShowNoTaskPromptHero {
            switch heroDayPhase {
            case .morning: return tr("hd_make_small_start")
            case .afternoon: return tr("hd_get_day_moving")
            case .evening, .night: return tr("hd_dont_leave_tomorrow")
            }
        }

        if todayPendingBoardCount == 0 && completedTodayBoardCount > 0 {
            return "Harika gidiyorsun"
        }

        if todayProgressValue == 0 {
            return tr("hd_lets_start")
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
            return tr("hd_today_check_caps")
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
            return tr("common_completed")
        }

        return tr("wv_free_day")
    }

    var priorityMiniSubtitle: String {
        if let exam = nearestRelevantExam {
            return "\(examCountdownText(exam)) • \(suggestedStudyMinutes(for: exam)) dk"
        }

        if let event = nextEvent {
            if isNextClassLiveNow {
                return tr("hd_active_now")
            }
            if let minutes = nextClassStartsInMinutes {
                return "\(minutes) dk sonra"
            }
            return nextEventTimeText
        }

        if todayPendingBoardCount == 0 && completedTodayBoardCount > 0 {
            return tr("hd_tasks_finished", completedTodayBoardCount)
        }

        return "Kendin planla"
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
        return tr("hd_check_social")
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
        guard let event = nextEvent else { return tr("common_today") }
        return "\(hm(event.startMinute)) • \(event.durationMinute) dk"
    }

    var hasNoTaskAtAllToday: Bool {
        todayBoardTasks.isEmpty
    }

    var shouldShowNoTaskPromptHero: Bool {
        hasNoTaskAtAllToday &&
        nearestRelevantExam == nil &&
        !focusSession.isSessionActive &&
        !hasAnyActiveFocusSession &&
        activeBackendCrewFocusSession == nil &&
        !hasRecentFriendConversation &&
        !hasCrewWorkToDo
    }

    var noTaskPromptHeroState: TodayHeroState {
        switch heroDayPhase {
        case .morning:
            return TodayHeroState(
                eyebrow: tr("hd_clean_start"),
                title: tr("hd_clarify_today"),
                subtitle: tr("hd_no_tasks_yet"),
                icon: "sparkles",
                accent: .blue,
                badge1: HeroBadge(icon: "sun.max.fill", text: "Sabah", tint: .orange),
                badge2: HeroBadge(icon: "checklist", text: tr("hd_empty_flow"), tint: .blue),
                contextLine: tr("hd_first_task_sets"),
                primaryCTA: tr("common_add_task"),
                primaryIcon: "plus",
                primaryAction: { onAddTask() },
                secondaryCTA: HeroCTA(title: "Hafta", icon: "calendar", action: { onOpenWeek() })
            )

        case .afternoon:
            return TodayHeroState(
                eyebrow: tr("hd_no_plan"),
                title: tr("hd_get_day_moving"),
                subtitle: tr("hd_one_task_rhythm"),
                icon: "bolt.fill",
                accent: .green,
                badge1: HeroBadge(icon: "clock.fill", text: tr("hd_noon"), tint: .orange),
                badge2: HeroBadge(icon: "checklist", text: tr("hd_empty_flow"), tint: .green),
                contextLine: tr("hd_short_task_tidies"),
                primaryCTA: tr("common_add_task"),
                primaryIcon: "plus",
                primaryAction: { onAddTask() },
                secondaryCTA: HeroCTA(title: "Hafta", icon: "calendar", action: { onOpenWeek() })
            )

        case .evening, .night:
            return TodayHeroState(
                eyebrow: tr("hd_evening_close"),
                title: tr("hd_dont_leave_tomorrow"),
                subtitle: tr("hd_tomorrow_steps"),
                icon: "calendar.badge.plus",
                accent: .purple,
                badge1: HeroBadge(icon: "moon.stars.fill", text: tr("hd_evening"), tint: .purple),
                badge2: HeroBadge(icon: "calendar", text: tr("common_tomorrow"), tint: .blue),
                contextLine: tr("hd_small_plan_morning"),
                primaryCTA: tr("hd_plan_tomorrow"),
                primaryIcon: "calendar.badge.plus",
                primaryAction: { onOpenWeek() },
                secondaryCTA: HeroCTA(title: tr("common_add_task"), icon: "plus", action: { onAddTask() })
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
            contextLine: activeSession.is_paused ? tr("hd_session_paused") : tr("hd_crew_focus_active"),
            primaryCTA: tr("hd_open_room"),
            primaryIcon: "arrow.right.circle.fill",
            primaryAction: {
                NotificationCenter.default.post(
                    name: .openCrewFocusFromNotification,
                    object: activeSession.crew_id.uuidString
                )
            },
            secondaryCTA: HeroCTA(title: "Crew", icon: "person.3.fill", action: { onOpenWeek() })
        )
    }

    var personalFocusFollowUpHeroState: TodayHeroState {
        let title = homeLiveFocusMainTitle.isEmpty ? "Odak devam ediyor" : homeLiveFocusMainTitle

        return TodayHeroState(
            eyebrow: tr("hd_flow_going"),
            title: title,
            subtitle: tr("hd_keep_rhythm"),
            icon: focusWorkoutMode ? "figure.strengthtraining.traditional" : "sparkles",
            accent: .blue,
            badge1: HeroBadge(icon: "scope", text: tr("hd_focus_on"), tint: .blue),
            badge2: HeroBadge(icon: "calendar", text: tr("common_today"), tint: .blue),
            contextLine: tr("hd_open_tasks_week"),
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
            subtitle = tr("hd_in_class_now", event.title)
            context = "Ders bitince ritmini koru."
            primaryCTA = tr("hd_open_week")
        } else {
            let minutes = nextClassStartsInMinutes ?? 0
            subtitle = tr("hd_class_starts_in", minutes, event.title)
            context = tr("hd_pre_class")
            primaryCTA = "Programa Git"
        }

        return TodayHeroState(
            eyebrow: isNextClassLiveNow ? tr("hd_active_now_label") : tr("hd_next_class_label"),
            title: event.title,
            subtitle: subtitle,
            icon: "book.closed.fill",
            accent: accent,
            badge1: HeroBadge(
                icon: isNextClassLiveNow ? "dot.radiowaves.left.and.right" : "clock.fill",
                text: nextEventTimeText,
                tint: accent
            ),
            badge2: HeroBadge(icon: "calendar", text: tr("common_today"), tint: .blue),
            contextLine: context,
            primaryCTA: primaryCTA,
            primaryIcon: "calendar",
            primaryAction: { onOpenWeek() },
            secondaryCTA: HeroCTA(title: tr("ph_tasks_word"), icon: "list.bullet", action: { showTasksShortcut = true })
        )
    }

    var socialFollowUpHeroState: TodayHeroState {
        let title = socialFollowUpTitle
        let subtitle = recentChatFriend != nil ? tr("hd_resume") : tr("hd_stay_connected")

        return TodayHeroState(
            eyebrow: tr("hd_social_flow"),
            title: title,
            subtitle: subtitle,
            icon: "bubble.left.and.bubble.right.fill",
            accent: .blue,
            badge1: HeroBadge(icon: "message.fill", text: "Sohbet", tint: .blue),
            badge2: HeroBadge(icon: "person.2.fill", text: tr("hd_friends"), tint: .pink),
            contextLine: tr("hd_short_msg"),
            primaryCTA: tr("hd_open_chat"),
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
        let completedTitle = latestCompletedTodayTaskTitle ?? tr("at_kind_task")

        return TodayHeroState(
            eyebrow: tr("hd_nice_progress"),
            title: tr("hd_x_done", completedTitle),
            subtitle: tr("hd_took_step"),
            icon: "checkmark.circle.fill",
            accent: .green,
            badge1: HeroBadge(icon: "checkmark.circle.fill", text: tr("common_completed"), tint: .green),
            badge2: HeroBadge(icon: "flame.fill", text: "Seri \(streakCount)", tint: .orange),
            contextLine: tr("hd_go_remaining"),
            primaryCTA: todayPendingBoardCount > 0 ? "Kalanlara Bak" : tr("hd_go_insights"),
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
            eyebrow: tr("hd_close_day"),
            title: tr("hd_lighten_tomorrow"),
            subtitle: tr("hd_small_plan_adds"),
            icon: "moon.stars.fill",
            accent: .purple,
            badge1: HeroBadge(icon: "calendar.badge.plus", text: tr("common_tomorrow"), tint: .purple),
            badge2: HeroBadge(icon: "checkmark.circle.fill", text: tr("hd_today_clean"), tint: .green),
            contextLine: tr("hd_clear_steps_morning"),
            primaryCTA: tr("hd_plan_tomorrow"),
            primaryIcon: "calendar.badge.plus",
            primaryAction: { onOpenWeek() },
            secondaryCTA: HeroCTA(title: tr("hd_insights"), icon: "chart.bar.fill", action: { onOpenInsights() })
        )
    }

    var lowMomentumHeroStateV2: TodayHeroState {
        TodayHeroState(
            eyebrow: tr("hd_small_start"),
            title: tr("hd_get_today_moving"),
            subtitle: tr("hd_one_task_flow"),
            icon: "bolt.fill",
            accent: .orange,
            badge1: HeroBadge(icon: "exclamationmark.circle.fill", text: tr("hd_need_start"), tint: .orange),
            badge2: HeroBadge(icon: "list.bullet", text: tr("rel_open_count", todayPendingBoardCount), tint: .blue),
            contextLine: tr("hd_not_perfect"),
            primaryCTA: tr("hd_open_tasks"),
            primaryIcon: "list.bullet",
            primaryAction: { showTasksShortcut = true },
            secondaryCTA: HeroCTA(title: tr("hd_start_focus"), icon: "play.fill", action: { startInlineFocus() })
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
            eyebrow: tr("hd_next_area"),
            title: "Crew seni bekliyor",
            subtitle: tr("hd_personal_done"),
            icon: "person.3.fill",
            accent: .pink,
            badge1: HeroBadge(icon: "checklist", text: tr("hd_open_work", activeCrewTaskCount), tint: .pink),
            badge2: HeroBadge(icon: "bolt.fill", text: "Crew", tint: .orange),
            contextLine: tr("hd_close_crew"),
            primaryCTA: "Crew’e Git",
            primaryIcon: "person.3.fill",
            primaryAction: { onOpenWeek() },
            secondaryCTA: HeroCTA(title: "Sohbet", icon: "bubble.left.and.bubble.right.fill", action: { showFriendsShortcut = true })
        )
    }

    var insightsFollowUpHeroState: TodayHeroState {
        TodayHeroState(
            eyebrow: tr("hd_today_finished"),
            title: tr("hd_check_flow"),
            subtitle: tr("hd_see_progress"),
            icon: "chart.bar.fill",
            accent: .blue,
            badge1: HeroBadge(icon: "flame.fill", text: "Seri \(streakCount)", tint: .orange),
            badge2: HeroBadge(icon: "chart.bar.fill", text: "Insights", tint: .blue),
            contextLine: tr("hd_helps_tomorrow"),
            primaryCTA: tr("hd_go_insights"),
            primaryIcon: "chart.bar.fill",
            primaryAction: { onOpenInsights() },
            secondaryCTA: HeroCTA(title: "Hafta", icon: "calendar", action: { onOpenWeek() })
        )
    }

    var wrapUpHeroState: TodayHeroState {
        TodayHeroState(
            eyebrow: tr("hd_day_complete"),
            title: tr("hd_prepare_tomorrow"),
            subtitle: tr("hd_calm_close"),
            icon: "calendar.badge.plus",
            accent: .green,
            badge1: HeroBadge(icon: "checkmark.circle.fill", text: "Tamam", tint: .green),
            badge2: HeroBadge(icon: "calendar", text: tr("common_tomorrow"), tint: .blue),
            contextLine: tr("hd_short_plan_friction"),
            primaryCTA: tr("hd_open_week"),
            primaryIcon: "calendar",
            primaryAction: { onOpenWeek() },
            secondaryCTA: HeroCTA(title: tr("common_add_task"), icon: "plus", action: { onAddTask() })
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
            eyebrow: tr("hd_clear_first"),
            title: task.title,
            subtitle: tr("hd_task_overdue"),
            icon: focusSymbol(for: task),
            accent: accent,
            badge1: HeroBadge(icon: "exclamationmark.triangle.fill", text: tr("common_overdue"), tint: accent),
            badge2: course.isEmpty ? nil : HeroBadge(icon: "book.closed.fill", text: course, tint: accent),
            contextLine: priorityTaskContextLine(for: task),
            primaryCTA: tr("hd_start"),
            primaryIcon: "play.fill",
            primaryAction: { startInlineFocus() },
            secondaryCTA: HeroCTA(title: tr("hd_all_tasks"), icon: "list.bullet", action: { showTasksShortcut = true })
        )
    }

    func priorityTaskHeroState(_ task: DTTaskItem) -> TodayHeroState {
        let accent = focusAccentColor(for: task)
        let course = task.courseName.trimmingCharacters(in: .whitespacesAndNewlines)

        return TodayHeroState(
            eyebrow: tr("hd_today_priority2"),
            title: task.title,
            subtitle: focusCardStatusTextStudent,
            icon: focusSymbol(for: task),
            accent: accent,
            badge1: HeroBadge(icon: "scope", text: dueBadgeText(for: task), tint: accent),
            badge2: course.isEmpty ? nil : HeroBadge(icon: "book.closed.fill", text: course, tint: accent),
            contextLine: priorityTaskContextLine(for: task),
            primaryCTA: tr("hd_start"),
            primaryIcon: "play.fill",
            primaryAction: { startInlineFocus() },
            secondaryCTA: HeroCTA(title: tr("hd_all_tasks"), icon: "list.bullet", action: { showTasksShortcut = true })
        )
    }

    func priorityTaskContextLine(for task: DTTaskItem) -> String {
        if store.isOverdue(task) {
            switch heroDayPhase {
            case .morning: return tr("hd_start_clearing")
            case .afternoon: return tr("hd_finish_relax")
            case .evening: return tr("hd_clear_before_evening")
            case .night: return tr("hd_close_lighter")
            }
        }

        switch heroDayPhase {
        case .morning: return tr("hd_early_momentum")
        case .afternoon: return tr("hd_now_momentum")
        case .evening: return tr("hd_finish_evening")
        case .night: return tr("hd_short_start_tomorrow")
        }
    }

    func buildHeroCandidates() -> [HomeHeroCandidate] {
        var candidates: [HomeHeroCandidate] = []

        if let activeSession = activeBackendCrewFocusSession {
            candidates.append(.init(kind: .sharedFocusActive, priority: 100, state: sharedFocusHeroState(activeSession)))
        }

        if focusSession.isSessionActive || hasAnyActiveFocusSession {
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
            eyebrow: tr("tv_upcoming_exam"),
            title: "\(exam.courseName.isEmpty ? exam.title : exam.courseName) \(exam.examType)",
            subtitle: "\(examCountdownText(exam)) • \(tr("hd_exam_study_block", minutes, label.lowercased()))",
            icon: "graduationcap.fill",
            accent: accent,
            badge1: HeroBadge(icon: "calendar", text: examDateText(exam), tint: accent),
            badge2: HeroBadge(icon: "timer", text: "\(minutes) dk", tint: .orange),
            contextLine: tr("hd_exam_block_sub"),
            primaryCTA: tr("hd_start_btn"),
            primaryIcon: "play.fill",
            primaryAction: { startInlineFocus() },
            secondaryCTA: HeroCTA(title: "Planla", icon: "calendar.badge.plus", action: { onOpenWeek() })
        )
    }

    func topCardBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.070),
                        Color(arenaHex: AppArenaPalette.purple).opacity(0.045),
                        Color.white.opacity(0.040)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(0.13),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 8,
                            endRadius: 190
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(accent.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }
    func heroBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.075),
                        Color(arenaHex: AppArenaPalette.purple).opacity(0.050),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(0.14),
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
                    .stroke(accent.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 16, y: 9)
    }
}
