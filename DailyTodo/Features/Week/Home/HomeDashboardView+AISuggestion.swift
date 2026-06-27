//
//  HomeDashboardView+AISuggestion.swift
//  DailyTodo
//
//  "Updo AI" proactive suggestion card — shown when the user is active but the
//  day is idle (nothing pending). The suggestion is derived purely from signals
//  we already hold (exams, schedule, streak, focus history, time of day) — NO
//  LLM / token usage. It's branded as Updo AI and expands downward to reveal a
//  concrete next step plus the reasoning behind it.
//

import SwiftUI

// MARK: - Suggestion Model

/// What a challenge measures, so its progress can be tracked from real data.
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
        self.action = action
    }
}

extension HomeDashboardView {

    // MARK: - Gating

    /// Show only for established users (starter retired) on an otherwise idle day,
    /// so the screen proactively suggests instead of sitting empty.
    var shouldShowUpdoAISuggestion: Bool {
        guard !shouldShowStarterCard else { return false }
        guard !shouldShowFocusCard else { return false }
        return todayPendingBoardCount == 0
    }

    // MARK: - Signals

    var hasFocusedToday: Bool {
        let cal = Calendar.current
        return allFocusRecords.contains { $0.isCompleted && cal.isDateInToday($0.startedAt) }
    }

    private func examDisplayName(_ exam: ExamItem) -> String {
        let course = exam.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
        return course.isEmpty ? exam.title : course
    }

    var hasSocialConnections: Bool {
        !crewStore.crews.isEmpty || !friends.isEmpty
    }

    /// Stable within a day, varies day to day — drives challenge rotation and
    /// the challenge-vs-personal alternation so the card never feels repetitive.
    private var dayOfYear: Int {
        Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
    }

    /// True once the user accepts today's challenge — keeps the card "on fire"
    /// for the rest of the day.
    var challengeAccepted: Bool {
        challengeAcceptedDay == dayOfYear
    }

    /// Accept handler: marks the day, ignites the card, then performs the action.
    func acceptChallenge(_ suggestion: UpdoAISuggestion) {
        HapticManager.shared.success()

        // Count once per day. Challenge days are ~2 apart, so a gap of 1...3
        // continues the streak; a wider gap (a missed challenge) resets it.
        if challengeAcceptedDay != dayOfYear {
            let gap = dayOfYear - lastAcceptedChallengeDay
            if lastAcceptedChallengeDay >= 0, gap > 0, gap <= 3 {
                challengeStreakCount += 1
            } else {
                challengeStreakCount = 1
            }
            lastAcceptedChallengeDay = dayOfYear
            challengeAcceptedTotal += 1
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            challengeAcceptedDay = dayOfYear
            aiSuggestionExpanded = true
        }
        // Let the "accepted / on fire" state register before navigating away.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            suggestion.action()
        }
    }

    // MARK: - Social challenge (rule-based, no LLM)

    /// A concrete, social, time-boxed challenge derived from the user's circle.
    /// Crew challenges take precedence (bigger stakes); falls back to a friend duel.
    var socialChallenge: UpdoAISuggestion? {
        let variant = dayOfYear % 3

        if !crewStore.crews.isEmpty {
            return crewChallenge(variant: variant)
        }

        if let friend = recentChatFriend ?? friends.first {
            return friendChallenge(variant: variant, friendName: friend.name)
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
                headline: tr("ai_sg_ch_crew_1_head"),
                reason: tr("ai_sg_ch_crew_1_reason"),
                ctaTitle: tr("ai_sg_ch_crew_1_cta"),
                ctaIcon: "scope",
                accent: accent,
                isChallenge: true,
                collapsedText: collapsed,
                introText: intro,
                action: { onOpenFocus() }
            )
        case 1:
            return UpdoAISuggestion(
                headline: tr("ai_sg_ch_crew_2_head"),
                reason: tr("ai_sg_ch_crew_2_reason"),
                ctaTitle: tr("ai_sg_ch_crew_2_cta"),
                ctaIcon: "person.3.fill",
                accent: accent,
                isChallenge: true,
                collapsedText: collapsed,
                introText: intro,
                action: { showCrewShortcut = true }
            )
        default:
            return UpdoAISuggestion(
                headline: tr("ai_sg_ch_crew_3_head"),
                reason: tr("ai_sg_ch_crew_3_reason"),
                ctaTitle: tr("ai_sg_ch_crew_3_cta"),
                ctaIcon: "plus",
                accent: accent,
                isChallenge: true,
                collapsedText: collapsed,
                introText: intro,
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
                headline: tr("ai_sg_ch_friend_1_head", friendName),
                reason: tr("ai_sg_ch_friend_1_reason"),
                ctaTitle: tr("ai_sg_ch_friend_1_cta"),
                ctaIcon: "scope",
                accent: accent,
                isChallenge: true,
                collapsedText: collapsed,
                introText: intro,
                action: { onOpenFocus() }
            )
        case 1:
            return UpdoAISuggestion(
                headline: tr("ai_sg_ch_friend_2_head", friendName),
                reason: tr("ai_sg_ch_friend_2_reason"),
                ctaTitle: tr("ai_sg_ch_friend_2_cta"),
                ctaIcon: "bubble.left.and.bubble.right.fill",
                accent: accent,
                isChallenge: true,
                collapsedText: collapsed,
                introText: intro,
                action: {
                    if recentChatFriend != nil {
                        showRecentFriendChat = true
                    } else {
                        showFriendsShortcut = true
                    }
                }
            )
        default:
            return UpdoAISuggestion(
                headline: tr("ai_sg_ch_friend_3_head", friendName),
                reason: tr("ai_sg_ch_friend_3_reason", friendName),
                ctaTitle: tr("ai_sg_ch_friend_3_cta"),
                ctaIcon: "plus",
                accent: accent,
                isChallenge: true,
                collapsedText: collapsed,
                introText: intro,
                action: { onAddTask() }
            )
        }
    }

    // MARK: - Rule-based resolver

    /// Priority-ordered rules over the data we already have. First match wins.
    var updoAISuggestion: UpdoAISuggestion {
        // 1 — An exam is approaching → propose a concrete study block.
        if let exam = nearestRelevantExam {
            let minutes = suggestedStudyMinutes(for: exam)
            return UpdoAISuggestion(
                headline: tr("ai_sg_exam_head", examDisplayName(exam)),
                reason: tr("ai_sg_exam_reason", examCountdownText(exam), minutes),
                ctaTitle: tr("ai_sg_exam_cta"),
                ctaIcon: "play.fill",
                accent: Color(arenaHex: AppArenaPalette.coral),
                action: { startInlineFocus() }
            )
        }

        // 2 — A class starts soon today → propose using the time before it.
        if let event = nextEvent, isNextClassStartingSoon, let mins = nextClassStartsInMinutes {
            return UpdoAISuggestion(
                headline: tr("ai_sg_class_head"),
                reason: tr("ai_sg_class_reason", event.title, mins),
                ctaTitle: tr("ai_sg_class_cta"),
                ctaIcon: "calendar",
                accent: Color(arenaHex: AppArenaPalette.blue),
                action: { onOpenWeek() }
            )
        }

        // 2.5 — Social challenge. When the user has a crew/friend, Updo AI hands
        // out a challenge on alternating days so it stays fresh, never nagging.
        if dayOfYear % 2 == 0, let challenge = socialChallenge {
            return challenge
        }

        // 3 — A live streak is at risk this evening → protect it with a small win.
        if streakCount >= 2,
           completedTodayBoardCount == 0,
           heroDayPhase == .evening || heroDayPhase == .night {
            return UpdoAISuggestion(
                headline: tr("ai_sg_streak_head"),
                reason: tr("ai_sg_streak_reason", streakCount),
                ctaTitle: tr("ai_sg_streak_cta"),
                ctaIcon: "plus",
                accent: Color(arenaHex: AppArenaPalette.gold),
                action: { onAddTask() }
            )
        }

        // 4 — Habitual focuser who hasn't focused today → nudge a deep-work block.
        if completedStarterFocusCount >= 3,
           !hasFocusedToday,
           heroDayPhase == .afternoon || heroDayPhase == .evening {
            return UpdoAISuggestion(
                headline: tr("ai_sg_focus_head"),
                reason: tr("ai_sg_focus_reason"),
                ctaTitle: tr("ai_sg_focus_cta"),
                ctaIcon: "scope",
                accent: Color(arenaHex: AppArenaPalette.purple),
                action: { onOpenFocus() }
            )
        }

        // 5 — Morning, empty day → start with one small step.
        if heroDayPhase == .morning {
            return UpdoAISuggestion(
                headline: tr("ai_sg_morning_head"),
                reason: tr("ai_sg_morning_reason"),
                ctaTitle: tr("ai_sg_morning_cta"),
                ctaIcon: "plus",
                accent: Color(arenaHex: AppArenaPalette.cyan),
                action: { onAddTask() }
            )
        }

        // 6 — Evening, empty day → plan tomorrow.
        if heroDayPhase == .evening || heroDayPhase == .night {
            return UpdoAISuggestion(
                headline: tr("ai_sg_evening_head"),
                reason: tr("ai_sg_evening_reason"),
                ctaTitle: tr("ai_sg_evening_cta"),
                ctaIcon: "calendar.badge.plus",
                accent: Color(arenaHex: AppArenaPalette.purple),
                action: { onOpenWeek() }
            )
        }

        // 7 — Fallback.
        return UpdoAISuggestion(
            headline: tr("ai_sg_default_head"),
            reason: tr("ai_sg_default_reason"),
            ctaTitle: tr("ai_sg_default_cta"),
            ctaIcon: "plus",
            accent: Color(arenaHex: AppArenaPalette.cyan),
            action: { onAddTask() }
        )
    }

    // MARK: - Card

    private var fireGradient: LinearGradient {
        LinearGradient(
            colors: [Color(arenaHex: "#F97316"), Color(arenaHex: "#EF4444")],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    @ViewBuilder
    var updoAISuggestionCard: some View {
        let suggestion = updoAISuggestion
        let onFire = suggestion.isChallenge && challengeAccepted

        VStack(alignment: .leading, spacing: 0) {
            // Header pill — always visible, toggles the reveal.
            Button {
                HapticManager.shared.navigation()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                    aiSuggestionExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    updoAIOrb(isChallenge: suggestion.isChallenge, onFire: onFire)

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
                                        Image(systemName: "flame.fill")
                                            .font(.system(size: 8, weight: .heavy))
                                    }
                                    Text(onFire ? tr("ai_sg_ch_accepted_caps") : tr("ai_sg_challenge_chip"))
                                        .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                                        .tracking(1.0)
                                }
                                .foregroundStyle(chipTint)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(chipTint.opacity(0.16)))
                            }
                        }

                        Text(headerLineText(suggestion: suggestion, onFire: onFire))
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(aiSuggestionExpanded && !onFire ? 0.55 : 0.9))
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

            // Reveal — opens downward.
            if aiSuggestionExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    if onFire {
                        HStack(spacing: 7) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(arenaHex: "#F97316"))
                            Text(tr("ai_sg_ch_accepted"))
                                .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color(arenaHex: "#FBBF24"))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(Color(arenaHex: "#F97316").opacity(0.16)))
                        .overlay(Capsule().stroke(Color(arenaHex: "#F97316").opacity(0.3), lineWidth: 1))
                    }

                    Text(suggestion.headline)
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(suggestion.reason)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.56))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

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
                                .font(.system(size: 13, weight: .bold))
                            Text(onFire ? tr("ai_sg_ch_continue") : suggestion.ctaTitle)
                                .font(.system(size: 14.5, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(onFire ? fireGradient : UpdoTheme.gradientAI, in: Capsule())
                        .shadow(color: (onFire ? Color.orange : UpdoTheme.cyan).opacity(0.24), radius: 10, y: 4)
                    }
                    .buttonStyle(UpdoPressButtonStyle())
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
        .background(updoAISuggestionBackground(onFire: onFire))
        .overlay(alignment: .top) {
            if onFire {
                ChallengeFireEdge()
                    .offset(y: -11)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            guard !didAutoOpenAISuggestion else { return }
            didAutoOpenAISuggestion = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    aiSuggestionExpanded = true
                }
            }
        }
    }

    private func headerLineText(suggestion: UpdoAISuggestion, onFire: Bool) -> String {
        if onFire { return tr("ai_sg_ch_accepted") }
        return aiSuggestionExpanded ? suggestion.introText : suggestion.collapsedText
    }

    private func updoAIOrb(isChallenge: Bool, onFire: Bool) -> some View {
        ZStack {
            Circle()
                .fill(onFire ? AnyShapeStyle(fireGradient) : AnyShapeStyle(UpdoTheme.gradientAI))
                .frame(width: 34, height: 34)
                .shadow(color: (onFire ? Color.orange : UpdoTheme.purple).opacity(0.5),
                        radius: onFire ? 10 : 6, y: 2)

            if isChallenge {
                Circle()
                    .stroke(Color(arenaHex: onFire ? "#FBBF24" : AppArenaPalette.gold).opacity(0.85),
                            lineWidth: 1.5)
                    .frame(width: 34, height: 34)
            }

            Image(systemName: onFire ? "flame.fill" : (isChallenge ? "flag.checkered" : "sparkles"))
                .font(.system(size: isChallenge ? 14 : 15, weight: .bold))
                .foregroundStyle(.white)

            if onFire {
                ChallengeOrbFlames()
                    .frame(width: 38, height: 22)
                    .offset(y: -23)
                    .allowsHitTesting(false)
            }
        }
    }

    private func updoAISuggestionBackground(onFire: Bool) -> some View {
        let topGlow = onFire ? Color(arenaHex: "#F97316") : UpdoTheme.cyan
        let bottomGlow = onFire ? Color(arenaHex: "#EF4444") : UpdoTheme.purple

        return RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(UpdoTheme.surface.opacity(0.96))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [topGlow.opacity(onFire ? 0.16 : 0.10), Color.clear],
                            center: .topLeading,
                            startRadius: 6,
                            endRadius: 200
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [bottomGlow.opacity(onFire ? 0.16 : 0.10), Color.clear],
                            center: .bottomTrailing,
                            startRadius: 8,
                            endRadius: 220
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: onFire
                                ? [Color(arenaHex: "#FBBF24").opacity(0.55), Color(arenaHex: "#EF4444").opacity(0.40)]
                                : [UpdoTheme.cyan.opacity(0.30), UpdoTheme.purple.opacity(0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: onFire ? 1.4 : 1
                    )
            )
            .shadow(color: (onFire ? Color.orange.opacity(0.22) : Color.black.opacity(0.22)),
                    radius: 16, y: 9)
    }
}

// MARK: - Fire effects (challenge accepted)

/// Small flickering flames rising from the Updo AI orb.
struct ChallengeOrbFlames: View {
    @State private var flicker = false
    private let sizes: [CGFloat] = [10, 15, 11]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(sizes.indices, id: \.self) { i in
                Image(systemName: "flame.fill")
                    .font(.system(size: sizes[i], weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(arenaHex: "#FDE68A"), Color(arenaHex: "#EF4444")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(flicker ? 1.0 : 0.68, anchor: .bottom)
                    .opacity(flicker ? 1.0 : 0.6)
                    .offset(y: flicker ? -2 : 1)
                    .animation(
                        .easeInOut(duration: 0.42 + Double(i) * 0.06)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.1),
                        value: flicker
                    )
            }
        }
        .shadow(color: Color.orange.opacity(0.5), radius: 5)
        .onAppear { flicker = true }
    }
}

/// A row of flames licking up over the top edge of the card.
struct ChallengeFireEdge: View {
    @State private var flicker = false
    private let sizes: [CGFloat] = [12, 18, 14, 21, 13, 17, 12]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(sizes.indices, id: \.self) { i in
                Image(systemName: "flame.fill")
                    .font(.system(size: sizes[i], weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(arenaHex: "#FDE68A"), Color(arenaHex: "#F97316"), Color(arenaHex: "#EF4444")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(flicker ? 1.0 : 0.72, anchor: .bottom)
                    .opacity(flicker ? 0.95 : 0.5)
                    .offset(y: flicker ? -3 : 2)
                    .animation(
                        .easeInOut(duration: 0.4 + Double(i) * 0.05)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.08),
                        value: flicker
                    )

                if i < sizes.count - 1 { Spacer(minLength: 0) }
            }
        }
        .padding(.horizontal, 16)
        .shadow(color: Color.orange.opacity(0.45), radius: 6)
        .onAppear { flicker = true }
    }
}
