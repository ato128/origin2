//
//  HomeView+UpdoSuggestion.swift
//  DailyTodo
//
//  The rule-based "Updo AI suggestion / challenge" card shown on the real Home
//  (HomeView). Separate from the AI-chat preview card — this one never spends
//  tokens: it analyses the user's own data (tasks, schedule, exams, focus, streak,
//  crew/friends) to push a concrete next action, and on social days hands out a
//  challenge that ignites the card when accepted.
//
//  Reuses `UpdoAISuggestion`, `ChallengeOrbFlames`, `ChallengeFireEdge`,
//  `UpdoPressButtonStyle` and the `ai_sg_*` / `ai_sg_ch_*` localization keys.
//

import SwiftUI

// MARK: - Shared suggestion model (moved from the retired HomeDashboardView)

enum ChallengeKind: String {
    case tasks   // tasks completed today
    case focus   // focus minutes today
}

struct UpdoAISuggestion {
    let headline: String
    let reason: String
    let ctaTitle: String
    let ctaIcon: String
    let accent: Color
    let isChallenge: Bool
    /// Pill text shown when the card is collapsed.
    let collapsedText: String
    /// Small label shown above the headline when expanded.
    let introText: String
    /// For challenges: what to measure and the goal (e.g. 3 tasks, 25 focus min).
    let challengeKind: ChallengeKind
    let challengeTarget: Int
    /// Urgent suggestions (imminent exam) bypass the frequency throttle.
    let isUrgentExam: Bool
    let action: () -> Void

    init(
        headline: String,
        reason: String,
        ctaTitle: String,
        ctaIcon: String,
        accent: Color,
        isChallenge: Bool = false,
        collapsedText: String = tr("ai_sg_collapsed"),
        introText: String = tr("ai_sg_intro"),
        challengeKind: ChallengeKind = .tasks,
        challengeTarget: Int = 0,
        isUrgentExam: Bool = false,
        action: @escaping () -> Void
    ) {
        self.headline = headline
        self.reason = reason
        self.ctaTitle = ctaTitle
        self.ctaIcon = ctaIcon
        self.accent = accent
        self.isChallenge = isChallenge
        self.collapsedText = collapsedText
        self.introText = introText
        self.challengeKind = challengeKind
        self.challengeTarget = challengeTarget
        self.isUrgentExam = isUrgentExam
        self.action = action
    }
}


extension HomeView {

    private enum AiPhase { case morning, afternoon, evening, night }

    // MARK: - Signals

    private var aiPhase: AiPhase {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return .morning
        case 12..<18: return .afternoon
        case 18..<23: return .evening
        default: return .night   // 23:00–04:59
        }
    }

    private var dayOfYear: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
    }

    private var hasEverFocused: Bool {
        allFocusRecords.contains { $0.countsTowardStats }
    }

    // Locally-computed equivalents (HomeView's own props are fileprivate / in
    // another extension, so we recompute from accessible data).
    private var aiActiveTaskCount: Int {
        store.items.filter { !$0.isDone }.count
    }

    private var aiStreakDays: Int {
        ProgressionManager.shared.currentStreak
    }

    private var aiHasFocusToday: Bool {
        let cal = Calendar.current
        let uid = session.currentUser?.id.uuidString
        return allFocusRecords.contains {
            $0.countsTowardStats && cal.isDateInToday($0.endedAt) && (uid == nil || $0.ownerUserID == uid)
        }
    }

    var recentFriendName: String? {
        allFriendMessages.first { !$0.isFromMe }?.senderName
    }

    var hasSocialConnections: Bool {
        !crewStore.crews.isEmpty || recentFriendName != nil
    }

    private var nearestRelevantExam: ExamItem? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let uid = session.currentUser?.id.uuidString

        return allExams
            .filter { exam in
                guard !exam.isCompleted else { return false }
                if let uid, let owner = exam.ownerUserID { return owner == uid }
                return true
            }
            .filter { $0.examDate >= today }
            .sorted { $0.examDate < $1.examDate }
            .first { exam in
                let days = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: exam.examDate)).day ?? 99
                return days <= 7
            }
    }

    private func examDaysText(_ exam: ExamItem) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: Date()),
            to: cal.startOfDay(for: exam.examDate)
        ).day ?? 0

        if days <= 0 { return tr("common_today") }
        if days == 1 { return tr("common_tomorrow") }
        return tr("ai_exam_days_n", days)
    }

    // MARK: - Gating

    /// Shown when the user is idle (nothing active) so Updo AI can push a first
    /// action, or on alternating "challenge days" when there's a crew/friend.
    var shouldShowUpdoSuggestion: Bool {
        guard !focusSession.isSessionActive else { return false }
        if aiActiveTaskCount == 0 { return true }
        if dayOfYear % 2 == 0, hasSocialConnections { return true }
        return false
    }

    /// Whether a given day already has any plan — a task OR a class/event. Used
    /// so the "plan tomorrow / start today" nudge vanishes once the day is set.
    private func hasPlan(on day: Date) -> Bool {
        let cal = Calendar.current

        let hasTask = store.items.contains { t in
            guard !t.isDone else { return false }
            if let d = t.dueDate, cal.isDate(d, inSameDayAs: day) { return true }
            if let w = t.scheduledWeekDate, cal.isDate(w, inSameDayAs: day) { return true }
            return false
        }
        if hasTask { return true }

        let weekdayIndex = (cal.component(.weekday, from: day) + 5) % 7
        return allEvents.contains { ev in
            if let scheduled = ev.scheduledDate { return cal.isDate(scheduled, inSameDayAs: day) }
            return ev.weekday == weekdayIndex
        }
    }

    private var todayHasPlan: Bool { hasPlan(on: Date()) }

    private var tomorrowHasPlan: Bool {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else { return false }
        return hasPlan(on: tomorrow)
    }

    private var hourNow: Int {
        Calendar.current.component(.hour, from: Date())
    }

    /// Next class/event on today's program, if it's still at least 20 minutes
    /// away — close enough to matter, far enough to fit a focus before it.
    private var nextEventToday: EventItem? {
        let cal = Calendar.current
        let now = Date()
        let weekdayIndex = (cal.component(.weekday, from: now) + 5) % 7
        let currentMinute = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)

        return allEvents
            .filter { ev in
                if let scheduled = ev.scheduledDate {
                    guard cal.isDateInToday(scheduled) else { return false }
                } else {
                    guard ev.weekday == weekdayIndex else { return false }
                }
                return ev.startMinute >= currentMinute + 20
            }
            .min { $0.startMinute < $1.startMinute }
    }

    private func minuteText(_ minuteOfDay: Int) -> String {
        String(format: "%02d.%02d", minuteOfDay / 60, minuteOfDay % 60)
    }

    /// Most recent completed task or focus session — nil if never active.
    private var lastActivityDate: Date? {
        let taskDates = store.items.compactMap { $0.isDone ? $0.completedAt : nil }
        let focusDates = allFocusRecords.filter { $0.countsTowardStats }.map { $0.endedAt }
        return (taskDates + focusDates).max()
    }

    /// Whole days since the user last did something (nil if never active).
    private var idleDays: Int? {
        guard let last = lastActivityDate else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: last), to: cal.startOfDay(for: Date())).day
    }

    private func examDays(_ exam: ExamItem) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: exam.examDate)).day ?? 7
    }

    // MARK: - Resolver (rule-based, no LLM)

    /// How many days Updo AI stays quiet after surfacing a non-urgent nudge.
    private var suggestionCooldownDays: Int { 2 }

    /// `nil` → the user is on track (or Updo AI is in its quiet window); the card
    /// falls back to the calm "Updo AI" chat-entry state. Otherwise a concrete,
    /// *still-relevant* nudge that disappears the moment the user acts on it.
    ///
    /// Frequency rule: an urgent exam (≤3 days) always shows. Everything else is
    /// rate-limited — once surfaced it persists for the rest of that day, then
    /// Updo AI stays quiet for `suggestionCooldownDays` so it never feels naggy.
    var updoSuggestion: UpdoAISuggestion? {
        guard let raw = rawSuggestion else { return nil }

        if raw.isUrgentExam { return raw }

        // Already surfaced today → keep it visible through the day.
        if aiSuggestionLastShownDay == dayOfYear { return raw }

        // Still inside the quiet window since the last nudge → stay neutral.
        let elapsed = dayOfYear - aiSuggestionLastShownDay
        if elapsed >= 0 && elapsed < suggestionCooldownDays { return nil }

        return raw
    }

    /// Stamps the throttle once a non-urgent suggestion is actually shown.
    /// Called from the card's `onAppear` (a getter must stay side-effect free).
    func markSuggestionSurfacedIfNeeded() {
        guard let raw = rawSuggestion, !raw.isUrgentExam else { return }
        if aiSuggestionLastShownDay != dayOfYear {
            aiSuggestionLastShownDay = dayOfYear
        }
    }

    /// Raw rule-based resolver (no throttle).
    private var rawSuggestion: UpdoAISuggestion? {
        // 1 — Urgent exam (≤3 days).
        if let exam = nearestRelevantExam, examDays(exam) <= 3 {
            return examSuggestion(exam, urgent: true)
        }

        // 2 — Re-engagement challenge: idle 1+ day and has a crew/friend.
        if let idle = idleDays, idle >= 1, hasSocialConnections, let challenge = socialChallenge {
            return challenge
        }

        // 3 — Streak at risk this evening.
        if aiStreakDays >= 2, !aiHasFocusToday, aiPhase == .evening || aiPhase == .night {
            return UpdoAISuggestion(
                headline: tr("ai_sg_streak_head"),
                reason: tr("ai_sg_streak_reason", aiStreakDays),
                ctaTitle: tr("ai_sg_streak_cta"),
                ctaIcon: "plus",
                accent: Color(arenaHex: AppArenaPalette.gold),
                action: { onAddTask() }
            )
        }

        // 4 — Habitual focuser who hasn't focused today.
        if hasEverFocused, !aiHasFocusToday, aiPhase == .afternoon || aiPhase == .evening {
            return UpdoAISuggestion(
                headline: tr("ai_sg_focus_head"),
                reason: tr("ai_sg_focus_reason"),
                ctaTitle: tr("ai_sg_focus_cta"),
                ctaIcon: "scope",
                accent: Color(arenaHex: AppArenaPalette.purple),
                action: { onOpenFocus() }
            )
        }

        // 5 — Non-urgent exam this week.
        if let exam = nearestRelevantExam {
            return examSuggestion(exam)
        }

        // 6 — Morning/afternoon and nothing (task or class) is on for today yet.
        if (aiPhase == .morning || aiPhase == .afternoon), !todayHasPlan {
            return UpdoAISuggestion(
                headline: tr("ai_sg_morning_head"),
                reason: tr("ai_sg_morning_reason"),
                ctaTitle: tr("ai_sg_morning_cta"),
                ctaIcon: "plus",
                accent: Color(arenaHex: AppArenaPalette.cyan),
                action: { onAddTask() }
            )
        }

        // 6.5 — Day still running: anchor the nudge to today's own program.
        // A class/event coming up (≥20 min away) beats a generic message.
        if hourNow < 21, let next = nextEventToday {
            return UpdoAISuggestion(
                headline: tr("ai_sg_event_head", next.title),
                reason: tr("ai_sg_event_reason", minuteText(next.startMinute)),
                ctaTitle: tr("ai_sg_event_cta"),
                ctaIcon: "scope",
                accent: Color(arenaHex: AppArenaPalette.cyan),
                action: { onOpenFocus() }
            )
        }

        // 7 — The day is truly winding down (21:00+) and tomorrow is empty.
        // Earlier evenings stay on today's program instead of "plan tomorrow".
        if hourNow >= 21 || aiPhase == .night, !tomorrowHasPlan {
            return UpdoAISuggestion(
                headline: tr("ai_sg_evening_head"),
                reason: tr("ai_sg_evening_reason"),
                ctaTitle: tr("ai_sg_evening_cta"),
                ctaIcon: "calendar.badge.plus",
                accent: Color(arenaHex: AppArenaPalette.purple),
                action: { onOpenWeek() }
            )
        }

        // On track → calm Updo AI chat-entry state.
        return nil
    }

    private func examSuggestion(_ exam: ExamItem, urgent: Bool = false) -> UpdoAISuggestion {
        let course = exam.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = course.isEmpty ? exam.title : course
        return UpdoAISuggestion(
            headline: tr("ai_sg_exam_head", name),
            reason: tr("ai_sg_exam_reason", examDaysText(exam), 45),
            ctaTitle: tr("ai_sg_exam_cta"),
            ctaIcon: "play.fill",
            accent: Color(arenaHex: AppArenaPalette.coral),
            isUrgentExam: urgent,
            action: { onOpenFocus() }
        )
    }

    // MARK: - Social challenge

    var socialChallenge: UpdoAISuggestion? {
        let variant = dayOfYear % 3

        if !crewStore.crews.isEmpty {
            return crewChallenge(variant: variant)
        }
        if let friend = recentFriendName {
            return friendChallenge(variant: variant, friendName: friend)
        }
        return nil
    }

    private func crewChallenge(variant: Int) -> UpdoAISuggestion {
        let collapsed = tr("ai_sg_ch_collapsed_crew")
        let intro = tr("ai_sg_ch_intro_crew")
        let accent = Color(arenaHex: AppArenaPalette.gold)

        switch variant {
        case 0:
            return UpdoAISuggestion(
                headline: tr("ai_sg_ch_crew_1_head"), reason: tr("ai_sg_ch_crew_1_reason"),
                ctaTitle: tr("ai_sg_ch_crew_1_cta"), ctaIcon: "scope", accent: accent,
                isChallenge: true, collapsedText: collapsed, introText: intro,
                challengeKind: .focus, challengeTarget: 25,
                action: { onOpenFocus() }
            )
        case 1:
            return UpdoAISuggestion(
                headline: tr("ai_sg_ch_crew_2_head"), reason: tr("ai_sg_ch_crew_2_reason"),
                ctaTitle: tr("ai_sg_ch_crew_2_cta"), ctaIcon: "checklist", accent: accent,
                isChallenge: true, collapsedText: collapsed, introText: intro,
                challengeKind: .tasks, challengeTarget: 3,
                action: { onOpenTasks() }
            )
        default:
            return UpdoAISuggestion(
                headline: tr("ai_sg_ch_crew_3_head"), reason: tr("ai_sg_ch_crew_3_reason"),
                ctaTitle: tr("ai_sg_ch_crew_3_cta"), ctaIcon: "plus", accent: accent,
                isChallenge: true, collapsedText: collapsed, introText: intro,
                challengeKind: .tasks, challengeTarget: 1,
                action: { onAddTask() }
            )
        }
    }

    private func friendChallenge(variant: Int, friendName: String) -> UpdoAISuggestion {
        let collapsed = tr("ai_sg_ch_collapsed_friend")
        let intro = tr("ai_sg_ch_intro_friend")
        let accent = Color(arenaHex: AppArenaPalette.gold)

        switch variant {
        case 0:
            return UpdoAISuggestion(
                headline: tr("ai_sg_ch_friend_1_head", friendName), reason: tr("ai_sg_ch_friend_1_reason"),
                ctaTitle: tr("ai_sg_ch_friend_1_cta"), ctaIcon: "scope", accent: accent,
                isChallenge: true, collapsedText: collapsed, introText: intro,
                challengeKind: .focus, challengeTarget: 25,
                action: { onOpenFocus() }
            )
        case 1:
            return UpdoAISuggestion(
                headline: tr("ai_sg_ch_friend_2_head", friendName), reason: tr("ai_sg_ch_friend_2_reason"),
                ctaTitle: tr("ai_sg_ch_friend_2_cta"), ctaIcon: "checklist", accent: accent,
                isChallenge: true, collapsedText: collapsed, introText: intro,
                challengeKind: .tasks, challengeTarget: 1,
                action: { onOpenTasks() }
            )
        default:
            return UpdoAISuggestion(
                headline: tr("ai_sg_ch_friend_3_head", friendName), reason: tr("ai_sg_ch_friend_3_reason", friendName),
                ctaTitle: tr("ai_sg_ch_friend_3_cta"), ctaIcon: "plus", accent: accent,
                isChallenge: true, collapsedText: collapsed, introText: intro,
                challengeKind: .tasks, challengeTarget: 1,
                action: { onAddTask() }
            )
        }
    }

    // MARK: - Accept / progress

    var challengeAccepted: Bool {
        challengeAcceptedDay == dayOfYear
    }

    /// Current value of the accepted challenge's metric, today.
    private var challengeMetricNow: Int {
        let cal = Calendar.current
        if challengeKindRaw == ChallengeKind.focus.rawValue {
            let secs = allFocusRecords
                .filter { $0.countsTowardStats && cal.isDateInToday($0.endedAt) }
                .reduce(0) { $0 + $1.completedSeconds }
            return secs / 60
        }
        return store.items.filter { t in
            guard t.isDone, let c = t.completedAt else { return false }
            return cal.isDateInToday(c)
        }.count
    }

    var challengeProgress: Int {
        guard challengeAccepted, challengeTarget > 0 else { return 0 }
        return max(0, min(challengeTarget, challengeMetricNow - challengeBaseline))
    }

    var challengeIsComplete: Bool {
        challengeAccepted && challengeTarget > 0 && challengeProgress >= challengeTarget
    }

    func acceptChallenge(_ suggestion: UpdoAISuggestion) {
        HapticManager.shared.action()

        // Snapshot the baseline so progress counts only what happens from now on.
        challengeKindRaw = suggestion.challengeKind.rawValue
        challengeTarget = suggestion.challengeTarget
        challengeBaseline = challengeMetricNow
        challengeCompletedDay = -1

        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
            challengeAcceptedDay = dayOfYear
            aiSuggestionExpanded = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            suggestion.action()
        }
    }

    /// Credits the streak the first time a challenge is actually completed.
    func creditChallengeCompletionIfNeeded() {
        guard challengeIsComplete, challengeCompletedDay != dayOfYear else { return }
        challengeCompletedDay = dayOfYear

        let gap = dayOfYear - lastAcceptedChallengeDay
        if lastAcceptedChallengeDay >= 0, gap > 0, gap <= 3 {
            challengeStreakCount += 1
        } else {
            challengeStreakCount = 1
        }
        lastAcceptedChallengeDay = dayOfYear
        challengeAcceptedTotal += 1
        HapticManager.shared.success()
    }

    // MARK: - Card

    private var fireGradient: LinearGradient {
        LinearGradient(
            colors: [Color(arenaHex: "#F97316"), Color(arenaHex: "#EF4444")],
            startPoint: .top, endPoint: .bottom
        )
    }

    @ViewBuilder
    var updoAICard: some View {
        // An accepted challenge stays on the card all day (with its progress),
        // regardless of what the resolver would otherwise surface now.
        if challengeAccepted, let challenge = socialChallenge {
            suggestionCard(challenge)
        } else if let suggestion = updoSuggestion {
            suggestionCard(suggestion)
                .onAppear { markSuggestionSurfacedIfNeeded() }
        } else {
            neutralCard
        }
    }

    // Suggestion state — expandable, with a concrete next step.
    @ViewBuilder
    private func suggestionCard(_ suggestion: UpdoAISuggestion) -> some View {
        let onFire = suggestion.isChallenge && challengeAccepted

        VStack(alignment: .leading, spacing: 0) {
            Button {
                HapticManager.shared.navigation()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                    aiSuggestionExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    suggestionOrb(isChallenge: suggestion.isChallenge, onFire: onFire)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(tr("ai_sg_eyebrow"))
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .tracking(1.6)
                                .foregroundStyle(UpdoTheme.cyan.opacity(0.9))

                            if suggestion.isChallenge {
                                let chipTint = Color(arenaHex: onFire ? "#F97316" : AppArenaPalette.gold)
                                HStack(spacing: 3) {
                                    if onFire {
                                        Image(systemName: "flame.fill").font(.system(size: 8, weight: .heavy))
                                    }
                                    Text(onFire ? tr("ai_sg_ch_accepted_caps") : tr("ai_sg_challenge_chip"))
                                        .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                                        .tracking(1.0)
                                }
                                .foregroundStyle(chipTint)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(chipTint.opacity(0.16)))
                            }

                            Spacer(minLength: 6)

                            if credits.isLoaded {
                                let remaining = credits.tokensRemaining
                                let pillTint: Color = remaining > 50 ? UpdoTheme.cyan : Color(arenaHex: "#FF5A44")
                                Text("\(remaining) kredi")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(pillTint)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule().fill(pillTint.opacity(0.14))
                                            .overlay(Capsule().stroke(pillTint.opacity(0.28), lineWidth: 1))
                                    )
                            }
                        }

                        Text(headerLine(suggestion: suggestion, onFire: onFire))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(aiSuggestionExpanded && !onFire ? 0.5 : 0.85))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .rotationEffect(.degrees(aiSuggestionExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if aiSuggestionExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    if onFire {
                        challengeStatusBanner(target: suggestion.challengeTarget, kind: suggestion.challengeKind)
                    }

                    Text(suggestion.headline)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(suggestion.reason)
                        .font(.system(size: 14.5, weight: .regular))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if !(onFire && challengeIsComplete) {
                        Button {
                            if suggestion.isChallenge && !challengeAccepted {
                                acceptChallenge(suggestion)
                            } else {
                                HapticManager.shared.action()
                                suggestion.action()
                            }
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: onFire ? "arrow.right" : suggestion.ctaIcon)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(onFire ? tr("ai_sg_ch_continue") : suggestion.ctaTitle)
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(onFire ? fireGradient : UpdoTheme.gradientAI, in: Capsule())
                            .shadow(color: (onFire ? Color.orange : UpdoTheme.cyan).opacity(0.24), radius: 10, y: 4)
                        }
                        .buttonStyle(UpdoPressButtonStyle())
                    }

                    Button {
                        HapticManager.shared.navigation()
                        showUpdoAI = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(tr("ai_sg_open_chat"))
                                .font(.system(size: 12.5, weight: .bold))
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(suggestionBackground(onFire: onFire))
        .opacity(pageAppeared ? 1 : 0)
        .offset(y: pageAppeared ? 0 : 12)
        .animation(.spring(response: 0.6, dampingFraction: 0.86).delay(0.08), value: pageAppeared)
        .onChange(of: challengeIsComplete) { _, complete in
            if complete { creditChallengeCompletionIfNeeded() }
        }
        .onAppear {
            guard !didAutoOpenSuggestion else { return }
            didAutoOpenSuggestion = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    aiSuggestionExpanded = true
                }
            }
        }
    }

    // Accepted-challenge status — progress toward the goal or a calm "complete".
    @ViewBuilder
    private func challengeStatusBanner(target: Int, kind: ChallengeKind) -> some View {
        let complete = challengeIsComplete
        let tint = Color(arenaHex: complete ? "#A3E635" : "#F97316")
        let key = kind == .focus ? "ai_sg_ch_progress_focus" : "ai_sg_ch_progress_tasks"

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: complete ? "checkmark.seal.fill" : "flame.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                Text(complete ? tr("ai_sg_ch_done") : tr("ai_sg_ch_accepted"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                Spacer(minLength: 6)
                Text(tr(key, challengeProgress, target))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }

            GeometryReader { geo in
                let frac = target > 0 ? CGFloat(challengeProgress) / CGFloat(target) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(tint).frame(width: max(4, geo.size.width * frac))
                }
            }
            .frame(height: 5)
            .animation(.spring(response: 0.5, dampingFraction: 0.82), value: challengeProgress)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(tint.opacity(0.25), lineWidth: 1))
    }

    // Neutral state — Updo AI asks "what do you want to do today?" with an inline
    // chat bar so the user can decide right on the card without opening chat first.
    private var neutralCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            // Header: orb + eyebrow + credits (tappable → opens full chat)
            HStack(spacing: 12) {
                suggestionOrb(isChallenge: false, onFire: false)

                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("ai_sg_eyebrow"))
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(UpdoTheme.cyan.opacity(0.9))

                    Text(tr("hv_ai_today_ask"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 6)

                if credits.isLoaded {
                    let remaining = credits.tokensRemaining
                    let pillTint: Color = remaining > 50 ? UpdoTheme.cyan : Color(arenaHex: "#FF5A44")
                    Text(tr("hv_ai_credit_n", remaining))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(pillTint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(pillTint.opacity(0.14))
                                .overlay(Capsule().stroke(pillTint.opacity(0.28), lineWidth: 1))
                        )
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { openAIChat(seed: nil) }

            // Inline chat bar
            HStack(spacing: 9) {
                TextField(tr("hv_ai_bar_placeholder"), text: $aiQuickInput, axis: .vertical)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .tint(UpdoTheme.cyan)
                    .lineLimit(1...3)
                    .focused($aiQuickFocused)
                    .submitLabel(.send)
                    .onSubmit { submitQuickInput() }

                Button {
                    submitQuickInput()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(quickInputReady ? Color.white : .white.opacity(0.4))
                        .frame(width: 30, height: 30)
                        .background(
                            Circle().fill(quickInputReady
                                          ? AnyShapeStyle(UpdoTheme.cyan)
                                          : AnyShapeStyle(Color.white.opacity(0.08)))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!quickInputReady)
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(Capsule(style: .continuous).stroke(UpdoTheme.border, lineWidth: 1))
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(suggestionBackground(onFire: false))
        .opacity(pageAppeared ? 1 : 0)
        .offset(y: pageAppeared ? 0 : 12)
        .animation(.spring(response: 0.6, dampingFraction: 0.86).delay(0.08), value: pageAppeared)
    }

    private var quickInputReady: Bool {
        !aiQuickInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitQuickInput() {
        let text = aiQuickInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        HapticManager.shared.navigation()
        openAIChat(seed: text)
    }

    /// Opens the full Updo AI chat, optionally seeding it with the user's intention.
    func openAIChat(seed: String?) {
        let trimmed = seed?.trimmingCharacters(in: .whitespacesAndNewlines)
        aiSeedPrompt = (trimmed?.isEmpty == false) ? trimmed : nil
        aiQuickInput = ""
        aiQuickFocused = false
        showUpdoAI = true
    }

    private func headerLine(suggestion: UpdoAISuggestion, onFire: Bool) -> String {
        if onFire { return tr("ai_sg_ch_accepted") }
        return aiSuggestionExpanded ? suggestion.introText : suggestion.collapsedText
    }

    private func suggestionOrb(isChallenge: Bool, onFire: Bool) -> some View {
        ZStack {
            Circle()
                .fill(onFire ? AnyShapeStyle(fireGradient) : AnyShapeStyle(UpdoTheme.gradientAI))
                .frame(width: 34, height: 34)
                .shadow(color: (onFire ? Color.orange : UpdoTheme.purple).opacity(0.5),
                        radius: onFire ? 10 : 6, y: 2)

            if isChallenge {
                Circle()
                    .stroke(Color(arenaHex: onFire ? "#FBBF24" : AppArenaPalette.gold).opacity(0.85), lineWidth: 1.5)
                    .frame(width: 34, height: 34)
            }

            Image(systemName: onFire
                  ? (challengeIsComplete ? "checkmark" : "flame.fill")
                  : (isChallenge ? "flag.checkered" : "sparkles"))
                .font(.system(size: isChallenge ? 14 : 15, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func suggestionBackground(onFire: Bool) -> some View {
        let topGlow = onFire ? Color(arenaHex: "#F97316") : UpdoTheme.cyan
        let bottomGlow = onFire ? Color(arenaHex: "#EF4444") : UpdoTheme.purple

        return RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(UpdoTheme.surface.opacity(0.96))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(RadialGradient(colors: [topGlow.opacity(onFire ? 0.16 : 0.10), .clear],
                                         center: .topLeading, startRadius: 6, endRadius: 200))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(RadialGradient(colors: [bottomGlow.opacity(onFire ? 0.16 : 0.10), .clear],
                                         center: .bottomTrailing, startRadius: 8, endRadius: 220))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: onFire
                                ? [Color(arenaHex: "#FBBF24").opacity(0.55), Color(arenaHex: "#EF4444").opacity(0.40)]
                                : [UpdoTheme.cyan.opacity(0.30), UpdoTheme.purple.opacity(0.22)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: onFire ? 1.4 : 1
                    )
            )
            .shadow(color: (onFire ? Color.orange.opacity(0.22) : Color.black.opacity(0.22)), radius: 16, y: 9)
    }
}
