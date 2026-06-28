//
//  HomeView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 3.06.2026.
//
import SwiftUI
import SwiftData
import Combine

struct HomeView: View {
    // MARK: - Environment

    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var focusSession: FocusSessionManager
    @EnvironmentObject var studentStore: StudentStore

    // MARK: - SwiftData Queries

    @Query(sort: \EventItem.startMinute, order: .forward) var allEvents: [EventItem]
    @Query var allFocusRecords: [FocusSessionRecord]
    @Query(sort: \FriendMessage.createdAt, order: .reverse) var allFriendMessages: [FriendMessage]
    @Query(sort: \ExamItem.examDate, order: .forward) var allExams: [ExamItem]

    // MARK: - Callbacks

    let onAddTask: () -> Void
    let onOpenWeek: () -> Void
    let onOpenInsights: () -> Void
    let onOpenFocus: () -> Void
    let onOpenCrew: () -> Void
    let onOpenChat: () -> Void
    let onOpenTasks: () -> Void

    // MARK: - Local UI State

    @State private var showProfileHub = false
    @State private var showMessages = false
    @State private var showTimelineDetail = false
    @State var showUpdoAI = false
    @State var pageAppeared = false
    @State private var now: Date = Date()

    // Streak bubble
    @State private var showStreakBubble = false
    @State private var streakBubbleMode: StreakBubbleMode = .info
    @State private var bubbleStreakValue = 0
    @Environment(\.scenePhase) private var scenePhase

    private let lastSeenStreakKey = "home.lastSeenStreak"

    @State private var pulse = false
    @State private var breathe = false
    @State private var shimmer = false
    @State private var shimmerPhase: CGFloat = -1.2
    @State private var aiCardPressed = false

    // Updo AI rule-based suggestion / challenge card
    @State var aiSuggestionExpanded = false
    @State var didAutoOpenSuggestion = false
    // Inline "what do you want to do today?" chat bar on the neutral card.
    @State var aiQuickInput = ""
    @State var aiSeedPrompt: String? = nil
    @FocusState var aiQuickFocused: Bool
    @AppStorage("updoChallengeAcceptedDayV1") var challengeAcceptedDay: Int = -1
    @AppStorage("challengeStreakCountV1") var challengeStreakCount: Int = 0
    @AppStorage("challengeAcceptedTotalV1") var challengeAcceptedTotal: Int = 0
    @AppStorage("lastAcceptedChallengeDayV1") var lastAcceptedChallengeDay: Int = -100
    // Accepted-challenge progress tracking (real data, no LLM).
    @AppStorage("challengeKindV1") var challengeKindRaw: String = "tasks"
    @AppStorage("challengeTargetV1") var challengeTarget: Int = 0
    @AppStorage("challengeBaselineV1") var challengeBaseline: Int = 0
    @AppStorage("challengeCompletedDayV1") var challengeCompletedDay: Int = -1
    // Throttle: day-of-year a non-urgent suggestion was last surfaced, so Updo AI
    // doesn't nag every time the user opens Home.
    @AppStorage("aiSuggestionLastShownDayV1") var aiSuggestionLastShownDay: Int = -100

    @ObservedObject var credits = DailyCreditsManager.shared
    @ObservedObject private var progression = ProgressionManager.shared

    // `now` is only read at minute granularity (timeline position, day checks) —
    // 15 s keeps it fresh without re-rendering the whole view every second.
    private let secondTimer = Timer.publish(every: 15, on: .main, in: .common).autoconnect()
    private let pulseTimer = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()
    private let breatheTimer = Timer.publish(every: 2.8, on: .main, in: .common).autoconnect()
    private let shimmerTimer = Timer.publish(every: 3.2, on: .main, in: .common).autoconnect()

    // MARK: - Theme

    private var accentPrimary: Color { Color(arenaHex: "#7C3AED") }
    private var accentSecondary: Color { Color(arenaHex: "#1593FF") }
    private var accentWarm: Color { Color(arenaHex: "#FF5A44") }
    private var accentCyan: Color { Color(arenaHex: "#2DD4FF") }
    private var accentGold: Color { Color(arenaHex: "#FBBF24") }
    private var accentGreen: Color { Color(arenaHex: "#A3E635") }

    private var homePrimaryGradient: LinearGradient {
        LinearGradient(
            colors: [accentCyan, accentSecondary, accentPrimary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ArenaBackground(
                primaryGlow: accentSecondary,
                secondaryGlow: accentPrimary,
                warmGlow: accentWarm,
                intensity: 0.88
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: focusSession.isSessionActive ? 18 : 22) {
                    topBar
                    heroSection
                    focusCard
                    timelineSection

                    Color.clear.frame(height: focusSession.isSessionActive ? 168 : 96)
                }
                .padding(.horizontal, 16)
                .padding(.top, focusSession.isSessionActive ? 4 : 6)
            }
            .animation(.spring(response: 0.44, dampingFraction: 0.88), value: focusSession.isSessionActive)

            if showStreakBubble {
                StreakBubble(
                    streak: bubbleStreakValue,
                    mode: streakBubbleMode,
                    onClose: { showStreakBubble = false }
                )
                .padding(.leading, 14)
                .padding(.top, 70)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showProfileHub) {
            NavigationStack {
                ProfileHubView()
            }
        }
        .sheet(isPresented: $showMessages) {
            NavigationStack {
                MessagesView()
            }
        }
        .fullScreenCover(isPresented: $showUpdoAI, onDismiss: { aiSeedPrompt = nil }) {
            UpdoAIView(
                seedPrompt: aiSeedPrompt,
                onDismissAndOpenWeek: {
                    showUpdoAI = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onOpenWeek() }
                },
                onDismissAndAddTask: {
                    showUpdoAI = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onAddTask() }
                }
            )
            .environmentObject(session)
            .environmentObject(store)
            .environmentObject(studentStore)
        }
        .sheet(isPresented: $showTimelineDetail) {
            TimelineDetailSheet(
                events: todayEvents,
                currentMinute: currentMinuteOfDay,
                weeklyMinutes: weeklyFocusMinutes,
                accentPrimary: accentPrimary,
                accentSecondary: accentSecondary,
                accentCyan: accentCyan,
                accentGold: accentGold,
                accentGreen: accentGreen,
                accentWarm: accentWarm
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            pageAppeared = true
            startShimmerLoop()
            evaluateStreakChange()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { evaluateStreakChange() }
        }
        .onReceive(secondTimer) { value in
            now = value
        }
        .onReceive(pulseTimer) { _ in
            withAnimation(.easeInOut(duration: 1.2)) {
                pulse.toggle()
            }
        }
        .onReceive(breatheTimer) { _ in
            withAnimation(.easeInOut(duration: 2.8)) {
                breathe.toggle()
            }
        }
        .onReceive(shimmerTimer) { _ in
            withAnimation(.easeInOut(duration: 3.2)) {
                shimmer.toggle()
            }
        }
    }

    private func startShimmerLoop() {
        withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
            shimmerPhase = 1.4
        }
    }

    // MARK: - Streak bubble

    /// Compares the current streak to the last value we showed the user. If it
    /// grew, auto-presents the "Seri arttı" bubble and lets it self-dismiss.
    private func evaluateStreakChange() {
        let current = progression.currentStreak
        let defaults = UserDefaults.standard
        let hasSeen = defaults.object(forKey: lastSeenStreakKey) != nil
        let lastSeen = defaults.integer(forKey: lastSeenStreakKey)

        if hasSeen && current > lastSeen && current > 0 {
            bubbleStreakValue = current
            streakBubbleMode = .increased
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                showStreakBubble = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
                if streakBubbleMode == .increased {
                    withAnimation(.easeIn(duration: 0.25)) { showStreakBubble = false }
                }
            }
        }

        defaults.set(current, forKey: lastSeenStreakKey)
    }

    /// Toggles the informational bubble when the user taps the flame badge.
    private func toggleStreakInfo() {
        if showStreakBubble && streakBubbleMode == .info {
            withAnimation(.easeIn(duration: 0.2)) { showStreakBubble = false }
            return
        }
        bubbleStreakValue = progression.currentStreak
        streakBubbleMode = .info
        withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
            showStreakBubble = true
        }
    }
}

// MARK: - Top Bar

private extension HomeView {
    var topBar: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                showProfileHub = true
            } label: {
                ZStack {
                    Circle()
                        .fill(homePrimaryGradient)
                        .frame(width: 48, height: 48)
                        .shadow(color: accentCyan.opacity(0.20), radius: 13, y: 7)

                    Circle()
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        .frame(width: 48, height: 48)

                    if let initial = userInitial {
                        Text(initial)
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            StreakFlameBadge(streak: progression.currentStreak) {
                toggleStreakInfo()
            }

            Spacer(minLength: 8)

            topBarIconButton(
                icon: "bubble.left.and.bubble.right.fill",
                tint: unreadMessageCount > 0 ? accentWarm : .white.opacity(0.88),
                badge: unreadMessageCount > 0 ? "\(min(unreadMessageCount, 9))" : nil,
                badgeColor: accentWarm
            ) {
                showMessages = true
            }
        }
        .padding(.top, 4)
        .opacity(pageAppeared ? 1 : 0)
        .offset(y: pageAppeared ? 0 : 8)
        .animation(.spring(response: 0.55, dampingFraction: 0.86), value: pageAppeared)
    }

    func topBarIconButton(
        icon: String,
        tint: Color,
        badge: String?,
        badgeColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.105),
                                        Color.white.opacity(0.050)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.24), radius: 14, y: 7)
                    )

                if let badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(minWidth: 17, minHeight: 17)
                        .background(Circle().fill(badgeColor))
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Hero Section

private extension HomeView {
    @ViewBuilder
    var heroSection: some View {
        let state = resolveHomeState()

        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 9) {
                if state.showLiveDot {
                    Circle()
                        .fill(state.liveAccent)
                        .frame(width: 6, height: 6)
                        .scaleEffect(pulse ? 1.45 : 1.0)
                        .opacity(pulse ? 0.48 : 1.0)
                        .shadow(color: state.liveAccent.opacity(0.65), radius: 7)
                }

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [state.accent, accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 22, height: 1)

                Text(state.eyebrow)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2.35)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [state.accent, accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(state.title)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .layoutPriority(1)

                Text(state.italicLine)
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                state.accent,
                                accentSecondary,
                                accentPrimary
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }

            if !state.metaItems.isEmpty {
                HStack(spacing: 13) {
                    ForEach(Array(state.metaItems.enumerated()), id: \.offset) { idx, item in
                        if idx > 0 {
                            Circle()
                                .fill(Color.white.opacity(0.28))
                                .frame(width: 3, height: 3)
                        }

                        HStack(spacing: 6) {
                            Image(systemName: item.icon)
                                .font(.system(size: 12, weight: .black))

                            Text(item.text)
                                .font(.system(size: 13, weight: .black))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .foregroundStyle(.white.opacity(0.52))
                    }
                }
                .padding(.top, 6)
            }
        }
        .opacity(pageAppeared ? 1 : 0)
        .offset(y: pageAppeared ? 0 : 16)
        .scaleEffect(pageAppeared ? 1.0 : 0.985, anchor: .topLeading)
        .animation(.spring(response: 0.68, dampingFraction: 0.84).delay(0.05), value: pageAppeared)
    }
}

// MARK: - Focus Card

private extension HomeView {
    @ViewBuilder
    var focusCard: some View {
        if focusSession.isSessionActive {
            activeFocusCountdownCard
        } else {
            updoAICard
        }
    }

    var activeFocusCountdownCard: some View {
        let timeStr = focusSession.timeString
        let progress = max(0.025, focusSession.progress)
        let elapsedText = elapsedSecondsText
        let remaining = focusSession.remainingSeconds
        let isCritical = remaining > 0 && remaining <= 60
        let isPaused = focusSession.isPaused

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isCritical ? accentGold : accentGreen)
                        .frame(width: 7, height: 7)
                        .scaleEffect(pulse ? 1.35 : 1.0)
                        .opacity(pulse ? 0.48 : 1.0)
                        .shadow(color: (isCritical ? accentGold : accentGreen).opacity(0.55), radius: 6)

                    Text(isCritical ? tr("hv_ending_soon_caps") : (isPaused ? "DURAKLATILDI" : tr("hv_active_focus_caps")))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.9)
                        .foregroundStyle(isCritical ? accentGold : accentCyan)
                }

                Spacer()

                Text(activeFocusMetaText)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.48))
            }

            HStack(alignment: .center, spacing: 12) {
                PremiumCountdownView(
                    text: timeStr,
                    isCritical: isCritical,
                    isPaused: isPaused,
                    warm: accentWarm,
                    gold: accentGold,
                    accent: accentCyan,
                    pulse: pulse
                )
                .layoutPriority(1)

                Spacer(minLength: 8)

                HStack(spacing: 9) {
                    Button {
                        focusSession.togglePause()
                    } label: {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.10))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        focusSession.closeSession()
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.black)
                            .frame(width: 46, height: 46)
                            .background(
                                Circle()
                                    .fill(.white)
                                    .shadow(color: Color.black.opacity(0.22), radius: 9, y: 5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(Color.white.opacity(0.08))

                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isCritical
                                    ? [accentGold, accentWarm]
                                    : [accentPrimary, accentSecondary, accentCyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * progress)
                        .opacity(isPaused ? 0.55 : 1.0)

                    if !isPaused {
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white.opacity(0), location: 0.0),
                                        .init(color: .white.opacity(0.45), location: 0.5),
                                        .init(color: .white.opacity(0), location: 1.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 48)
                            .offset(x: proxy.size.width * shimmerPhase)
                            .frame(width: proxy.size.width * progress, alignment: .leading)
                            .clipShape(RoundedRectangle(cornerRadius: 999, style: .continuous))
                    }
                }
            }
            .frame(height: 5)

            HStack {
                Text(isPaused ? tr("hv_paused") : "Odak devam ediyor")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))

                Spacer()

                Text(elapsedText)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.46))
            }
        }
        .padding(15)
        .background(homeSurface(cornerRadius: 28, tint: isCritical ? accentGold : accentCyan, secondaryTint: accentPrimary))
        .shadow(color: Color.black.opacity(0.20), radius: 17, y: 9)
        .opacity(pageAppeared ? 1 : 0)
        .offset(y: pageAppeared ? 0 : 12)
        .animation(.spring(response: 0.6, dampingFraction: 0.86).delay(0.08), value: pageAppeared)
    }

    func homeSurface(
        cornerRadius: CGFloat,
        tint: Color,
        secondaryTint: Color
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.078),
                        tint.opacity(0.072),
                        secondaryTint.opacity(0.062),
                        Color.white.opacity(0.030)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.18),
                                secondaryTint.opacity(0.12),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Timeline Section

private extension HomeView {
    var timelineSection: some View {
        VStack(alignment: .leading, spacing: focusSession.isSessionActive ? 12 : 14) {
            HStack(spacing: 10) {
                sectionTitle(tr("hv_todays_flow_caps"))

                Spacer()

                if !todayEvents.isEmpty {
                    Button {
                        showTimelineDetail = true
                    } label: {
                        HStack(spacing: 5) {
                            Text("DETAY")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .tracking(1.4)

                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .black))
                        }
                        .foregroundStyle(accentCyan)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(
                            Capsule()
                                .fill(accentCyan.opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(accentCyan.opacity(0.20), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if todayEvents.isEmpty {
                emptyTimeline
            } else {
                filledTimeline
            }
        }
        .opacity(pageAppeared ? 1 : 0)
        .offset(y: pageAppeared ? 0 : 12)
        .animation(.spring(response: 0.6, dampingFraction: 0.86).delay(0.12), value: pageAppeared)
    }

    func sectionTitle(_ title: String) -> some View {
        SectionHeader(title, accent: accentCyan)
    }

    var filledTimeline: some View {
        Button {
            showTimelineDetail = true
        } label: {
            VStack(alignment: .leading, spacing: focusSession.isSessionActive ? 11 : 13) {
                HStack(spacing: 6) {
                    Text("\(todayEvents.count)")
                        .font(.system(size: focusSession.isSessionActive ? 19 : 21, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("etkinlik")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.white.opacity(0.62))

                    if pastEventsCount > 0 {
                        Text("·")
                            .foregroundStyle(.white.opacity(0.28))

                        Text(tr("rel_done_count", pastEventsCount))
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(accentGreen.opacity(0.92))
                    }

                    Spacer()

                    Text(timeRangeText)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(.white.opacity(0.52))
                }

                CurvedTimelineView(
                    events: todayEvents,
                    currentMinute: currentMinuteOfDay,
                    pulse: pulse,
                    shimmerPhase: shimmerPhase,
                    accentPrimary: accentPrimary,
                    accentSecondary: accentSecondary,
                    accentActive: accentCyan,
                    accentGold: accentGold
                )
                .frame(height: focusSession.isSessionActive ? 102 : 116)
            }
            .padding(focusSession.isSessionActive ? 13 : 15)
            .background(homeSurface(cornerRadius: 28, tint: accentCyan, secondaryTint: accentPrimary))
            .shadow(color: Color.black.opacity(0.20), radius: 16, y: 9)
        }
        .buttonStyle(.plain)
    }

    var emptyTimeline: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accentCyan.opacity(0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: "sparkles")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(accentCyan)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("hv_day_is_yours"))
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)

                    Text(tr("hv_shape_schedule"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.52))
                        .lineLimit(2)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    onOpenWeek()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 11, weight: .black))

                        Text("Ders ekle")
                            .font(.system(size: 12, weight: .black))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 13)
                    .frame(height: 34)
                    .background(Capsule().fill(homePrimaryGradient))
                }
                .buttonStyle(.plain)

                Button {
                    onAddTask()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11, weight: .black))

                        Text(tr("hv_add_task"))
                            .font(.system(size: 12, weight: .black))
                    }
                    .foregroundStyle(.white.opacity(0.86))
                    .padding(.horizontal, 13)
                    .frame(height: 34)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.075))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(16)
        .background(homeSurface(cornerRadius: 28, tint: accentCyan, secondaryTint: accentPrimary))
        .shadow(color: Color.black.opacity(0.20), radius: 16, y: 9)
    }
}

// MARK: - State Resolution

private extension HomeView {
    struct HeroState {
        let eyebrow: String
        let title: String
        let italicLine: String
        let metaItems: [MetaItem]
        let showLiveDot: Bool
        let accent: Color
        let liveAccent: Color
    }

    struct MetaItem {
        let icon: String
        let text: String
    }

    func resolveHomeState() -> HeroState {
        if focusSession.isSessionActive {
            return HeroState(
                eyebrow: tr("hv_now_focusing"),
                title: "Focus",
                italicLine: "devam et",
                metaItems: [
                    MetaItem(icon: "timer", text: focusSession.timeString),
                    MetaItem(icon: "scope", text: focusSession.selectedGoal.title)
                ],
                showLiveDot: true,
                accent: accentCyan,
                liveAccent: accentGreen
            )
        }

        if let active = activeNowEvent {
            let endMin = active.startMinute + active.durationMinute
            let remaining = max(0, endMin - currentMinuteOfDay)

            return HeroState(
                eyebrow: tr("hv_now_live"),
                title: active.title,
                italicLine: "aktif ders",
                metaItems: locationAndTimeMeta(
                    event: active,
                    extra: tr("rel_min_left", remaining)
                ),
                showLiveDot: true,
                accent: accentGold,
                liveAccent: accentGreen
            )
        }

        if let upcoming = upcomingEventWithin(minutes: 90) {
            let mins = upcoming.startMinute - currentMinuteOfDay

            return HeroState(
                eyebrow: tr("hv_next_class_soon"),
                title: upcoming.title,
                italicLine: timingPhrase(minutesUntil: mins),
                metaItems: locationAndTimeMeta(event: upcoming, extra: nil),
                showLiveDot: false,
                accent: accentGold,
                liveAccent: accentGold
            )
        }

        if overdueTaskCount > 0 {
            return HeroState(
                eyebrow: tr("hv_today_priority"),
                title: tr("rel_task_count", overdueTaskCount),
                italicLine: "seni bekliyor",
                metaItems: [
                    MetaItem(icon: "checklist", text: tr("rel_active_task_count", activeTaskCount))
                ],
                showLiveDot: true,
                accent: accentWarm,
                liveAccent: accentGold
            )
        }

        if streakDays > 0 && !hasFocusToday {
            return HeroState(
                eyebrow: tr("hv_streak_keep"),
                title: tr("rel_streak_days", streakDays),
                italicLine: "serini koru",
                metaItems: [
                    MetaItem(icon: "flame.fill", text: tr("hv_focus_today"))
                ],
                showLiveDot: false,
                accent: accentGold,
                liveAccent: accentGold
            )
        }

        if activeTaskCount > 0 {
            return HeroState(
                eyebrow: tr("hv_today_continue"),
                title: greetingPrefix,
                italicLine: displayName.isEmpty ? tr("hv_build_flow") : displayName,
                metaItems: [
                    MetaItem(icon: "checklist", text: tr("rel_active_task_count", activeTaskCount))
                ],
                showLiveDot: false,
                accent: accentCyan,
                liveAccent: accentCyan
            )
        }

        return HeroState(
            eyebrow: tr("hv_today_calm"),
            title: greetingPrefix,
            italicLine: displayName.isEmpty ? tr("hv_welcome") : displayName,
            metaItems: [],
            showLiveDot: false,
            accent: accentCyan,
            liveAccent: accentCyan
        )
    }

    func locationAndTimeMeta(event: EventItem, extra: String?) -> [MetaItem] {
        var items: [MetaItem] = []

        if let loc = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !loc.isEmpty {
            items.append(MetaItem(icon: "mappin.and.ellipse", text: loc))
        }

        let startStr = formatHHmm(event.startMinute)
        let endStr = formatHHmm(event.startMinute + event.durationMinute)
        items.append(MetaItem(icon: "clock", text: "\(startStr) — \(endStr)"))

        if let extra {
            items.append(MetaItem(icon: "hourglass", text: extra))
        }

        return items
    }

    func timingPhrase(minutesUntil: Int) -> String {
        if minutesUntil <= 0 { return tr("hv_starting") }
        if minutesUntil < 60 { return "\(minutesUntil) dakikada" }

        let h = minutesUntil / 60
        let m = minutesUntil % 60

        if m == 0 { return "\(h) saat sonra" }
        return "\(h)s \(m)dk sonra"
    }
}

// MARK: - Computed Helpers

private extension HomeView {
    var currentUserID: String? {
        session.currentUser?.id.uuidString
    }

    var displayName: String {
        if let user = session.currentUser {
            let first = user.fullName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: " ")
                .first
                .map(String.init)

            if let first, !first.isEmpty { return first }
            if !user.username.isEmpty { return user.username }
        }

        return ""
    }

    var userInitial: String? {
        guard let user = session.currentUser else { return nil }

        let name = user.fullName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let first = name.first {
            return String(first).uppercased()
        }

        if let first = user.username.first {
            return String(first).uppercased()
        }

        return nil
    }

    var greetingPrefix: String {
        let hour = Calendar.current.component(.hour, from: now)

        switch hour {
        case 5..<12:
            return tr("hv_good_morning")
        case 12..<18:
            return tr("hv_good_afternoon")
        default:
            return tr("hv_good_evening")
        }
    }

    var currentMinuteOfDay: Int {
        let cal = Calendar.current
        return cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
    }

    var todayWeekday: Int {
        let weekday = Calendar.current.component(.weekday, from: now)
        return (weekday + 5) % 7
    }

    func formatHHmm(_ minute: Int) -> String {
        let safeMinute = max(0, minute)
        let h = safeMinute / 60
        let m = safeMinute % 60
        return String(format: "%02d:%02d", h, m)
    }

    var todayEvents: [EventItem] {
        let uid = currentUserID

        return allEvents
            .filter { event in
                event.weekday == todayWeekday &&
                (event.ownerUserID == uid || event.ownerUserID == nil)
            }
            .sorted { $0.startMinute < $1.startMinute }
    }

    var activeNowEvent: EventItem? {
        let nowMin = currentMinuteOfDay

        return todayEvents.first {
            $0.startMinute <= nowMin && nowMin < ($0.startMinute + $0.durationMinute)
        }
    }

    func upcomingEventWithin(minutes: Int) -> EventItem? {
        let nowMin = currentMinuteOfDay

        return todayEvents.first { event in
            event.startMinute > nowMin &&
            (event.startMinute - nowMin) <= minutes
        }
    }

    var pastEventsCount: Int {
        let nowMin = currentMinuteOfDay
        return todayEvents.filter { ($0.startMinute + $0.durationMinute) <= nowMin }.count
    }

    var timeRangeText: String {
        guard let first = todayEvents.first,
              let last = todayEvents.last else {
            return "06–24"
        }

        let firstHour = first.startMinute / 60
        let lastHour = (last.startMinute + last.durationMinute) / 60

        return String(format: "%02d–%02d", firstHour, lastHour)
    }

    var activeFocusMetaText: String {
        let totalMin = focusSession.requestedMinutes
        return "\(totalMin) DK · \(focusSession.selectedGoal.title.uppercased())"
    }

    var activeFocusGoalText: String {
        switch focusSession.selectedMode {
        case .personal:
            return focusSession.selectedGoal.title
        case .crew:
            return "Crew Focus"
        case .friend:
            return "Friend Focus"
        }
    }

    var elapsedSecondsText: String {
        let total = focusSession.requestedMinutes * 60
        let remaining = focusSession.remainingSeconds
        let elapsed = max(0, total - remaining)

        if elapsed >= 3600 {
            let h = elapsed / 3600
            let m = (elapsed % 3600) / 60
            return tr("rel_hm_elapsed", h, m)
        } else if elapsed >= 60 {
            return tr("rel_min_elapsed", elapsed / 60)
        }

        return tr("rel_sec_elapsed", elapsed)
    }

    var overdueTaskCount: Int {
        store.items.filter { !$0.isDone && store.isOverdue($0) }.count
    }

    var unreadMessageCount: Int {
        let friendUnread = allFriendMessages.filter { !$0.isRead && !$0.isFromMe }.count

        let crewUnread = crewStore.crewMembers
            .filter { $0.user_id.uuidString == currentUserID }
            .compactMap(\.unread_count)
            .reduce(0, +)

        return friendUnread + crewUnread
    }

    var weeklyFocusMinutes: Int {
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? now

        let totalSeconds = ownedFocusRecords
            .filter { $0.endedAt >= weekStart && $0.countsTowardStats }
            .map(\.completedSeconds)
            .reduce(0, +)

        return totalSeconds / 60
    }

    /// Focus records belonging to the current user. Falls back to records with no
    /// owner stamped (saved while the session store was briefly unavailable) so a
    /// finished session is never silently dropped.
    var ownedFocusRecords: [FocusSessionRecord] {
        guard let uid = currentUserID else { return [] }
        let owned = allFocusRecords.filter { $0.ownerUserID == uid }
        if !owned.isEmpty { return owned + allFocusRecords.filter { $0.ownerUserID == nil } }
        return allFocusRecords.filter { $0.ownerUserID == nil }
    }

    var activeTaskCount: Int {
        store.items.filter { !$0.isDone }.count
    }

    var completedTodayCount: Int {
        let cal = Calendar.current

        return store.items.filter { task in
            guard task.isDone, let date = task.completedAt else { return false }
            return cal.isDate(date, inSameDayAs: now)
        }.count
    }

    var hasFocusToday: Bool {
        let cal = Calendar.current

        return ownedFocusRecords.contains { record in
            record.countsTowardStats &&
            cal.isDate(record.endedAt, inSameDayAs: now)
        }
    }

    var streakDays: Int {
        let cal = Calendar.current

        let userRecords = ownedFocusRecords.filter { $0.countsTowardStats }

        guard !userRecords.isEmpty else { return 0 }

        let focusDates = Set(userRecords.map { cal.startOfDay(for: $0.endedAt) })

        var streak = 0
        var cursor = cal.startOfDay(for: now)

        while focusDates.contains(cursor) {
            streak += 1

            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }

            cursor = prev
        }

        return streak
    }
}

// MARK: - Premium Countdown View (Serif Italic, native numeric transition)

private struct PremiumCountdownView: View {
    let text: String
    let isCritical: Bool
    let isPaused: Bool
    let warm: Color
    let gold: Color
    let accent: Color
    let pulse: Bool

    var body: some View {
        let parts = text.split(separator: ":").map(String.init)

        HStack(alignment: .firstTextBaseline, spacing: 0) {
            ForEach(Array(parts.enumerated()), id: \.offset) { idx, part in
                if idx > 0 {
                    Text(":")
                        .font(.system(size: 46, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(separatorColor)
                        .opacity(separatorOpacity)
                        .offset(y: -4)
                        .padding(.horizontal, 1)
                }

                Text(part)
                    .font(.system(size: 58, weight: .bold, design: .serif))
                    .italic()
                    .foregroundStyle(digitFill)
                    .kerning(-1.4)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(response: 0.40, dampingFraction: 0.86), value: part)
            }
        }
        .shadow(color: Color.black.opacity(0.45), radius: 8, y: 5)
        .shadow(color: (isCritical ? warm : accent).opacity(0.14), radius: 16)
        .opacity(isPaused ? 0.55 : 1.0)
        .animation(.easeInOut(duration: 0.30), value: isPaused)
    }

    /// Brushed-silver fill — bright crown into deep graphite with a whisper of
    /// accent at the base. Critical keeps the vivid warm alert tone.
    private var digitFill: LinearGradient {
        if isCritical {
            return LinearGradient(
                colors: [warm.opacity(0.98), gold.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        return LinearGradient(
            colors: [
                Color.white.opacity(0.96),
                Color.white.opacity(0.74),
                Color(white: 0.44),
                accent.opacity(0.45)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var separatorColor: Color {
        isCritical ? warm.opacity(0.65) : .white
    }

    private var separatorOpacity: Double {
        if isPaused { return 0.18 }
        return pulse ? 0.70 : 0.22
    }
}

// MARK: - Smart Timeline View (ana ekran küçük)

private struct CurvedTimelineView: View {
    let events: [EventItem]
    let currentMinute: Int
    let pulse: Bool
    let shimmerPhase: CGFloat

    let accentPrimary: Color
    let accentSecondary: Color
    let accentActive: Color
    let accentGold: Color

    private let dayStartMin: Double = 6 * 60
    private let dayEndMin: Double = 24 * 60

    private var trackCyan: Color { Color(arenaHex: "#2DD4FF") }
    private var trackBlue: Color { Color(arenaHex: "#1593FF") }
    private var trackViolet: Color { Color(arenaHex: "#7C3AED") }

    @State private var drawProgress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                hourMarkers(width: width, height: height)
                futureDashedPath(width: width, height: height)
                pastFilledPath(width: width, height: height)
                shimmerOverlay(width: width, height: height)
                eventDots(width: width, height: height)

                if dayContainsNow {
                    nowIndicator(width: width, height: height)
                }
            }
            // One-shot left-to-right draw reveal on appear
            .mask(alignment: .leading) {
                Rectangle().frame(width: width * drawProgress)
            }
        }
        .onAppear {
            guard drawProgress == 0 else { return }
            withAnimation(.easeOut(duration: 0.85).delay(0.15)) {
                drawProgress = 1
            }
        }
    }

    @ViewBuilder
    func hourMarkers(width: CGFloat, height: CGFloat) -> some View {
        let markers = [6, 9, 12, 15, 18, 21, 24]

        ForEach(markers, id: \.self) { hour in
            let progress = progressForHour(hour)
            let x = xForProgress(progress, width: width)

            VStack {
                Spacer()

                Text(String(format: "%02d", hour == 24 ? 0 : hour))
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(trackCyan.opacity(0.25))
            }
            .frame(width: 24)
            .position(x: x, y: height / 2)
        }
    }

    @ViewBuilder
    func futureDashedPath(width: CGFloat, height: CGFloat) -> some View {
        let path = rhythmPath(width: width, height: height)
        let progress = currentDayProgress

        path
            .trim(from: CGFloat(progress), to: 1)
            .stroke(
                trackCyan.opacity(0.18),
                style: StrokeStyle(
                    lineWidth: 2.2,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: [3, 5]
                )
            )
    }

    @ViewBuilder
    func pastFilledPath(width: CGFloat, height: CGFloat) -> some View {
        let path = rhythmPath(width: width, height: height)
        let progress = currentDayProgress

        path
            .trim(from: 0, to: CGFloat(progress))
            .stroke(
                LinearGradient(
                    colors: [trackViolet, trackBlue, trackCyan],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(
                    lineWidth: 3.5,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .shadow(color: trackCyan.opacity(0.20), radius: 6)
    }

    @ViewBuilder
    func shimmerOverlay(width: CGFloat, height: CGFloat) -> some View {
        let path = rhythmPath(width: width, height: height)
        let progress = currentDayProgress

        path
            .trim(from: 0, to: CGFloat(progress))
            .stroke(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.0), location: max(0, shimmerPhase - 0.18)),
                        .init(color: .white.opacity(0.55), location: shimmerPhase),
                        .init(color: .white.opacity(0.0), location: min(1, shimmerPhase + 0.18))
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(
                    lineWidth: 3.5,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .blendMode(.screen)
    }

    @ViewBuilder
    func eventDots(width: CGFloat, height: CGFloat) -> some View {
        ForEach(events.indices, id: \.self) { index in
            let event = events[index]
            let midMinute = event.startMinute + event.durationMinute / 2
            let p = pointForMinute(midMinute, width: width, height: height)

            let isPast = (event.startMinute + event.durationMinute) <= currentMinute
            let isActive = event.startMinute <= currentMinute &&
                           currentMinute < (event.startMinute + event.durationMinute)

            let labelOffset = labelVerticalOffset(for: index)

            ZStack {
                if isActive {
                    Circle()
                        .fill(accentActive.opacity(0.22))
                        .frame(width: 28, height: 28)
                        .scaleEffect(pulse ? 1.35 : 1.0)
                        .opacity(pulse ? 0.0 : 0.65)
                        .position(p)
                }

                Circle()
                    .fill(dotColor(isPast: isPast, isActive: isActive))
                    .frame(width: isActive ? 12 : 8, height: isActive ? 12 : 8)
                    .overlay(
                        Circle()
                            .stroke(
                                Color.white.opacity(isActive ? 0.92 : 0.18),
                                lineWidth: isActive ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isActive ? accentActive.opacity(0.45) : Color.clear,
                        radius: isActive ? 8 : 0
                    )
                    .position(p)

                Text(formatStartTime(event.startMinute))
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(
                        isActive
                            ? accentActive
                            : trackCyan.opacity(isPast ? 0.45 : 0.64)
                    )
                    .position(
                        x: p.x,
                        y: max(8, min(height - 10, p.y + labelOffset))
                    )
            }
        }
    }

    func dotColor(isPast: Bool, isActive: Bool) -> Color {
        if isActive {
            return accentActive
        }

        if isPast {
            return trackCyan.opacity(0.54)
        }

        return trackViolet.opacity(0.70)
    }

    func labelVerticalOffset(for index: Int) -> CGFloat {
        index.isMultiple(of: 2) ? -18 : 18
    }

    @ViewBuilder
    func nowIndicator(width: CGFloat, height: CGFloat) -> some View {
        let p = pointForMinute(currentMinute, width: width, height: height)

        // Outer halo
        Circle()
            .fill(accentActive.opacity(0.15))
            .frame(width: 38, height: 38)
            .scaleEffect(pulse ? 1.45 : 1.0)
            .opacity(pulse ? 0.0 : 0.50)
            .position(p)

        // Mid halo
        Circle()
            .fill(accentActive.opacity(0.22))
            .frame(width: 24, height: 24)
            .scaleEffect(pulse ? 1.18 : 1.0)
            .opacity(pulse ? 0.18 : 0.78)
            .position(p)

        // Core dot
        Circle()
            .fill(
                RadialGradient(
                    colors: [.white, accentActive],
                    center: .center,
                    startRadius: 1,
                    endRadius: 8
                )
            )
            .frame(width: 14, height: 14)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.96), lineWidth: 2)
            )
            .shadow(color: accentActive.opacity(0.55), radius: 10)
            .position(p)
    }

    func pointForMinute(_ minute: Int, width: CGFloat, height: CGFloat) -> CGPoint {
        let progress = progressForMinute(minute)
        let x = xForProgress(progress, width: width)
        let y = yForMinute(minute, height: height)

        return CGPoint(x: x, y: y)
    }

    func xForProgress(_ progress: Double, width: CGFloat) -> CGFloat {
        let padding: CGFloat = 16
        let clamped = max(0, min(1, progress))
        return padding + CGFloat(clamped) * (width - padding * 2)
    }

    func yForMinute(_ minute: Int, height: CGFloat) -> CGFloat {
        let base = height * 0.60
        let energy = workloadEnergy(at: minute)
        let lift = CGFloat(energy) * height * 0.36

        let progress = progressForMinute(minute)
        let softWave = sin(progress * Double.pi * 2.0) * Double(height) * 0.030

        let y = Double(base - lift) + softWave

        return CGFloat(max(Double(height * 0.18), min(Double(height * 0.78), y)))
    }

    func workloadEnergy(at minute: Int) -> Double {
        guard !events.isEmpty else {
            return 0.12
        }

        var total = 0.0

        for event in events {
            let start = Double(event.startMinute)
            let end = Double(event.startMinute + event.durationMinute)
            let mid = (start + end) / 2.0
            let duration = max(30.0, Double(event.durationMinute))

            let distance = abs(Double(minute) - mid)
            let spread = max(48.0, duration * 0.58)

            let influence = exp(-pow(distance / spread, 2.0))
            let durationWeight = min(1.0, duration / 120.0)

            total += influence * (0.40 + durationWeight * 0.36)
        }

        return max(0.10, min(0.95, total))
    }

    func rhythmPath(width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        let samples = 120

        for index in 0...samples {
            let progress = Double(index) / Double(samples)
            let minute = dayStartMin + progress * (dayEndMin - dayStartMin)
            let point = pointForMinute(Int(minute), width: width, height: height)

            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }

    var currentDayProgress: Double {
        progressForMinute(currentMinute)
    }

    var dayContainsNow: Bool {
        let now = Double(currentMinute)
        return now >= dayStartMin && now <= dayEndMin
    }

    func progressForMinute(_ minute: Int) -> Double {
        let raw = Double(minute)
        let clamped = max(dayStartMin, min(dayEndMin, raw))
        return (clamped - dayStartMin) / (dayEndMin - dayStartMin)
    }

    func progressForHour(_ hour: Int) -> Double {
        progressForMinute(hour * 60)
    }

    func formatStartTime(_ minute: Int) -> String {
        let h = minute / 60
        let m = minute % 60

        return String(format: "%02d:%02d", h, m)
    }
}

// MARK: - Metric Card

private enum HomeMetricKind {
    case focus
    case task
    case streak
}

private struct HomeMetricCard: View {
    let kind: HomeMetricKind
    let eyebrow: String
    let value: String
    let unit: String
    let subtitle: String
    let progress: Double
    let primaryTint: Color
    let secondaryTint: Color
    let icon: String
    let isActive: Bool
    let isCompleted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center) {
                Text(eyebrow)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.45)
                    .foregroundStyle(primaryTint.opacity(isActive ? 0.95 : 0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                iconView
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 31, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: value)

                Text(unit)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white.opacity(0.44))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }

            Text(subtitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(isActive ? 0.52 : 0.38))
                .lineLimit(2)
                .minimumScaleFactor(0.74)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(cardBackground)
        .overlay(staticCardHighlight)
        .shadow(
            color: primaryTint.opacity(isActive ? 0.10 : 0.035),
            radius: isActive ? 12 : 7,
            y: 7
        )
    }

    private var iconView: some View {
        ZStack {
            if kind == .streak && isActive {
                Circle()
                    .fill(primaryTint.opacity(0.13))
                    .frame(width: 30, height: 30)
            }

            if kind == .task && isCompleted {
                Circle()
                    .fill(primaryTint.opacity(0.12))
                    .frame(width: 30, height: 30)
            }

            if kind == .focus && isActive {
                Circle()
                    .fill(primaryTint.opacity(0.10))
                    .frame(width: 30, height: 30)
            }

            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(iconColor)
        }
    }

    private var iconColor: Color {
        switch kind {
        case .focus:
            return primaryTint.opacity(isActive ? 0.95 : 0.58)

        case .task:
            return isCompleted
            ? primaryTint.opacity(0.98)
            : primaryTint.opacity(isActive ? 0.92 : 0.58)

        case .streak:
            return isActive
            ? primaryTint.opacity(0.98)
            : primaryTint.opacity(0.46)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 23, style: .continuous)
            .fill(
                LinearGradient(
                    colors: backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                primaryTint.opacity(isActive ? 0.20 : 0.085),
                                secondaryTint.opacity(isCompleted ? 0.22 : 0.075),
                                Color.white.opacity(0.045)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    private var backgroundColors: [Color] {
        switch kind {
        case .focus:
            let level = max(0.0, min(progress, 1.0))

            return [
                Color.white.opacity(0.052),
                primaryTint.opacity(0.035 + level * 0.065),
                secondaryTint.opacity(0.030 + level * 0.050),
                Color.black.opacity(0.020)
            ]

        case .task:
            if isCompleted {
                return [
                    Color.white.opacity(0.052),
                    primaryTint.opacity(0.105),
                    Color.green.opacity(0.045),
                    Color.black.opacity(0.020)
                ]
            }

            return [
                Color.white.opacity(0.052),
                primaryTint.opacity(isActive ? 0.072 : 0.030),
                secondaryTint.opacity(isActive ? 0.055 : 0.025),
                Color.black.opacity(0.020)
            ]

        case .streak:
            return [
                Color.white.opacity(0.052),
                primaryTint.opacity(isActive ? 0.090 : 0.030),
                Color.orange.opacity(isActive ? 0.050 : 0.018),
                Color.black.opacity(0.020)
            ]
        }
    }

    @ViewBuilder
    private var staticCardHighlight: some View {
        if isCompleted || (kind == .streak && isActive) {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .stroke(primaryTint.opacity(0.13), lineWidth: 1)
        }
    }
}
// MARK: - Timeline Detail Sheet

private struct TimelineDetailSheet: View {
    let events: [EventItem]
    let currentMinute: Int
    let weeklyMinutes: Int

    let accentPrimary: Color
    let accentSecondary: Color
    let accentCyan: Color
    let accentGold: Color
    let accentGreen: Color
    let accentWarm: Color

    @Environment(\.dismiss) private var dismiss
    @State private var pulse = false
    @State private var selectedEventID: UUID?

    private let pulseTimer = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            ArenaBackground(
                primaryGlow: accentSecondary,
                secondaryGlow: accentPrimary,
                warmGlow: accentWarm,
                intensity: 0.88
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    headerSection
                    bigTimeline
                    peakInsights
                    eventListSection

                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onReceive(pulseTimer) { _ in
            withAnimation(.easeInOut(duration: 1.2)) { pulse.toggle() }
        }
    }

    // MARK: Header

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 9) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [accentCyan, accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 22, height: 1)

                Text(tr("hv_todays_flow_detail"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2.35)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentCyan, accentSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(tr("hv_your_day"))
                    .font(.system(size: 38, weight: .black))
                    .foregroundStyle(.white)

                Text("ritmi")
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentCyan, accentSecondary, accentPrimary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Spacer()
            }

            Text("\(events.count) \(tr("import_events")) · \(pastEventsCount) \(tr("done_word")) · \(tr("now_label")) \(formatHHmm(currentMinute))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.50))
        }
    }

    // MARK: Big timeline

    var bigTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tr("hv_detailed_view"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(accentCyan.opacity(0.85))

                Spacer()

                Text(timeRangeText)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.50))
            }

            CurvedTimelineView(
                events: events,
                currentMinute: currentMinute,
                pulse: pulse,
                shimmerPhase: 0.5,
                accentPrimary: accentPrimary,
                accentSecondary: accentSecondary,
                accentActive: accentCyan,
                accentGold: accentGold
            )
            .frame(height: 200)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.078),
                            accentCyan.opacity(0.072),
                            accentPrimary.opacity(0.062),
                            Color.white.opacity(0.030)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(accentCyan.opacity(0.18), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.20), radius: 16, y: 9)
    }

    // MARK: Peak insights

    var peakInsights: some View {
        HStack(spacing: 10) {
            insightCard(
                eyebrow: tr("hv_peak"),
                title: peakHourText,
                subtitle: tr("hv_peak_sub"),
                icon: "flame.fill",
                tint: accentGold
            )

            insightCard(
                eyebrow: tr("hv_calm_caps"),
                title: quietHourText,
                subtitle: tr("hv_free_window"),
                icon: "moon.zzz.fill",
                tint: accentCyan
            )
        }
    }

    func insightCard(eyebrow: String, title: String, subtitle: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(eyebrow)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(tint.opacity(0.92))

                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(tint.opacity(0.72))
            }

            Text(title)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            tint.opacity(0.04),
                            Color.black.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(tint.opacity(0.13), lineWidth: 1)
                )
        )
    }

    // MARK: Event list

    var eventListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tr("hv_events_caps"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(accentCyan.opacity(0.85))

                Spacer()

                Text("\(events.count) toplam")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.50))
            }

            VStack(spacing: 10) {
                ForEach(events, id: \.id) { event in
                    eventRow(event)
                }
            }
        }
    }

    func eventRow(_ event: EventItem) -> some View {
        let isPast = (event.startMinute + event.durationMinute) <= currentMinute
        let isActive = event.startMinute <= currentMinute &&
                       currentMinute < (event.startMinute + event.durationMinute)

        let statusText: String
        let statusColor: Color

        if isActive {
            statusText = tr("now_label_caps")
            statusColor = accentGreen
        } else if isPast {
            statusText = "TAMAM"
            statusColor = accentCyan.opacity(0.50)
        } else {
            let mins = event.startMinute - currentMinute
            if mins < 60 {
                statusText = "\(mins) DK"
            } else {
                statusText = "\(mins / 60) SA"
            }
            statusColor = accentPrimary
        }

        return HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(formatHHmm(event.startMinute))
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(isActive ? accentGreen : .white.opacity(0.85))

                Text("\(event.durationMinute)dk")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
            }
            .frame(width: 56)

            Rectangle()
                .fill(
                    isActive ? accentGreen :
                    (isPast ? accentCyan.opacity(0.35) : accentPrimary.opacity(0.55))
                )
                .frame(width: 3)
                .frame(maxHeight: 38)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(isPast ? .white.opacity(0.50) : .white)
                    .lineLimit(1)

                if let loc = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !loc.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 9, weight: .bold))

                        Text(loc)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white.opacity(0.42))
                }
            }

            Spacer()

            Text(statusText)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(statusColor)
                .padding(.horizontal, 9)
                .frame(height: 22)
                .background(
                    Capsule()
                        .fill(statusColor.opacity(0.13))
                        .overlay(
                            Capsule()
                                .stroke(statusColor.opacity(0.18), lineWidth: 1)
                        )
                )
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    isActive
                        ? accentGreen.opacity(0.08)
                        : Color.white.opacity(0.035)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isActive ? accentGreen.opacity(0.30) : Color.white.opacity(0.07),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: Helpers

    var pastEventsCount: Int {
        events.filter { ($0.startMinute + $0.durationMinute) <= currentMinute }.count
    }

    var timeRangeText: String {
        guard let first = events.first, let last = events.last else { return "06–24" }
        let firstHour = first.startMinute / 60
        let lastHour = (last.startMinute + last.durationMinute) / 60
        return String(format: "%02d–%02d", firstHour, lastHour)
    }

    var peakHourText: String {
        guard !events.isEmpty else { return "—" }

        var bestHour = 12
        var bestScore = 0.0

        for hour in 6...23 {
            let minute = hour * 60
            var score = 0.0

            for event in events {
                let mid = Double(event.startMinute + event.durationMinute / 2)
                let dist = abs(Double(minute) - mid)
                let spread = max(48.0, Double(event.durationMinute) * 0.58)
                score += exp(-pow(dist / spread, 2.0))
            }

            if score > bestScore {
                bestScore = score
                bestHour = hour
            }
        }

        return String(format: "%02d:00", bestHour)
    }

    var quietHourText: String {
        guard !events.isEmpty else { return tr("hv_all_day") }

        var bestHour = 6
        var lowestScore = Double.infinity

        for hour in 6...23 {
            let minute = hour * 60
            var score = 0.0

            for event in events {
                let mid = Double(event.startMinute + event.durationMinute / 2)
                let dist = abs(Double(minute) - mid)
                let spread = max(48.0, Double(event.durationMinute) * 0.58)
                score += exp(-pow(dist / spread, 2.0))
            }

            if score < lowestScore {
                lowestScore = score
                bestHour = hour
            }
        }

        return String(format: "%02d:00", bestHour)
    }

    func formatHHmm(_ minute: Int) -> String {
        let h = minute / 60
        let m = minute % 60
        return String(format: "%02d:%02d", h, m)
    }
}

// MARK: - Streak flame badge
//
// The home streak indicator: a small animated flame badge that lives next to
// the profile avatar. It flickers gently (30 fps, no animated blur) and the
// flame grows warmer / brighter the longer the streak runs. Tapping it opens
// the StreakBubble.

struct StreakFlameBadge: View {

    let streak: Int
    var onTap: () -> Void = {}

    // 0…1 "heat" — how hot the flame burns. Saturates around a 30-day streak.
    private var level: Double { min(Double(max(streak, 0)), 30) / 30 }

    private var isLit: Bool { streak > 0 }

    private let fGold  = Color(arenaHex: "#FBBF24")
    private let fAmber = Color(arenaHex: "#F59E0B")
    private let fCoral = Color(arenaHex: "#FF6A3D")
    private let fRed   = Color(arenaHex: "#EF4444")

    var body: some View {
        Button {
            HapticManager.shared.navigation()
            onTap()
        } label: {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                content(t: t)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr("home_streak_ax", streak))
    }

    private func content(t: TimeInterval) -> some View {
        // Two desynced sines → organic flicker. Stronger swing as the streak grows.
        let flick: Double = (sin(t * 7.3) * 0.6 + sin(t * 11.7 + 1.1) * 0.4)
        let swing: Double = isLit ? (0.04 + 0.06 * level) : 0.015
        let scale: CGFloat = 1.0 + CGFloat(flick * swing)
        let lift: CGFloat = CGFloat(flick * (isLit ? 1.2 : 0.4))
        let glowOpacity: Double = isLit ? (0.30 + 0.55 * level + 0.10 * flick) : 0.10

        return HStack(spacing: 6) {
            flameStack(scale: scale, lift: lift, glowOpacity: glowOpacity)

            Text("\(streak)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isLit ? .white : .white.opacity(0.55))
        }
        .padding(.horizontal, 11)
        .frame(height: 48)
        .background(badgeBackground(glowOpacity: glowOpacity))
    }

    private func flameStack(scale: CGFloat, lift: CGFloat, glowOpacity: Double) -> some View {
        ZStack {
            // Static-radius halo (no animated blur — only opacity reacts).
            Circle()
                .fill(
                    RadialGradient(
                        colors: [fCoral.opacity(glowOpacity), .clear],
                        center: .center, startRadius: 1, endRadius: 18
                    )
                )
                .frame(width: 34, height: 34)

            // Back layers light up as the streak climbs (more "alevli").
            if streak >= 3 {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(fRed.opacity(0.55))
                    .scaleEffect(scale * 1.12)
                    .offset(y: lift * 0.5)
                    .blur(radius: 2)
            }

            Image(systemName: "flame.fill")
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(flameGradient)
                .scaleEffect(scale)
                .offset(y: -lift)
                .shadow(color: fAmber.opacity(isLit ? 0.6 : 0.15), radius: 5)

            // Bright inner core for high streaks.
            if streak >= 7 {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color(arenaHex: "#FFF3D2").opacity(0.9))
                    .scaleEffect(scale)
                    .offset(y: -lift * 1.4)
            }
        }
        .frame(width: 26, height: 30)
    }

    private var flameGradient: LinearGradient {
        if !isLit {
            return LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.22)],
                                  startPoint: .top, endPoint: .bottom)
        }
        // Cooler (gold) at low streak → hotter (red) at high streak.
        let topColor = level > 0.5 ? Color(arenaHex: "#FFF3D2") : fGold
        return LinearGradient(
            colors: [topColor, fAmber, fCoral, fRed],
            startPoint: .top, endPoint: .bottom
        )
    }

    private func badgeBackground(glowOpacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        fCoral.opacity(isLit ? 0.16 : 0.05),
                        Color.white.opacity(0.045)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(fAmber.opacity(isLit ? (0.22 + 0.25 * level) : 0.10), lineWidth: 1)
            )
            .shadow(color: fCoral.opacity(glowOpacity * 0.5), radius: 10, y: 4)
    }
}

// MARK: - Streak bubble

enum StreakBubbleMode {
    case info       // user tapped the badge
    case increased  // streak went up since last visit
}

struct StreakBubble: View {

    let streak: Int
    let mode: StreakBubbleMode
    var onClose: () -> Void = {}

    @State private var shown = false

    private let fAmber = Color(arenaHex: "#F59E0B")
    private let fCoral = Color(arenaHex: "#FF6A3D")

    private var titleText: String {
        switch mode {
        case .increased: return tr("home_streak_up_title")
        case .info:      return streak > 0 ? tr("home_streak_count_title", streak) : tr("home_streak_start_title")
        }
    }

    private var bodyText: String {
        switch mode {
        case .increased:
            return tr("home_streak_up_body", streak)
        case .info:
            if streak > 0 {
                return tr("home_streak_info_body_active")
            }
            return tr("home_streak_info_body_start")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Little tail pointing up toward the badge.
            StreakBubbleTriangle()
                .fill(bubbleFill)
                .frame(width: 18, height: 9)
                .padding(.leading, 26)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(
                            LinearGradient(colors: [fAmber, fCoral],
                                           startPoint: .top, endPoint: .bottom)
                        )

                    Text(titleText)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer(minLength: 0)

                    if mode == .info {
                        Button {
                            close()
                        } label: {
                            Image(systemName: "xmark").accessibilityLabel(tr("event_close"))
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(.white.opacity(0.55))
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Color.white.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(bodyText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(bubbleFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(fAmber.opacity(0.28), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 18, y: 10)
            )
        }
        .frame(maxWidth: 290, alignment: .leading)
        .scaleEffect(shown ? 1 : 0.82, anchor: .topLeading)
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.74)) {
                shown = true
            }
        }
    }

    private var bubbleFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: "#241910").opacity(0.98),
                Color(arenaHex: "#16110C").opacity(0.98)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private func close() {
        withAnimation(.easeIn(duration: 0.22)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { onClose() }
    }
}

private struct StreakBubbleTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

