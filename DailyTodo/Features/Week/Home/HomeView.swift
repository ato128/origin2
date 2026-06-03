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

    @Query(sort: \EventItem.startMinute, order: .forward) private var allEvents: [EventItem]
    @Query private var allFocusRecords: [FocusSessionRecord]
    @Query(sort: \FriendMessage.createdAt, order: .reverse) private var allFriendMessages: [FriendMessage]

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
    @State private var pageAppeared = false
    @State private var now: Date = Date()

    @State private var pulse = false
    @State private var breathe = false
    @State private var shimmer = false

    private let secondTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
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
                VStack(alignment: .leading, spacing: 22) {
                    topBar
                    heroSection
                    focusCard
                    timelineSection
                    statsRow

                    Color.clear.frame(height: 92)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
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
        .onAppear {
            pageAppeared = true
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

            Spacer(minLength: 8)

            HStack(spacing: 9) {
                topBarIconButton(
                    icon: "checklist",
                    tint: overdueTaskCount > 0 ? accentGold : .white.opacity(0.88),
                    badge: overdueTaskCount > 0 ? "\(min(overdueTaskCount, 9))" : nil,
                    badgeColor: accentGold
                ) {
                    onOpenTasks()
                }

                topBarIconButton(
                    icon: "bubble.left.and.bubble.right.fill",
                    tint: unreadMessageCount > 0 ? accentWarm : .white.opacity(0.88),
                    badge: unreadMessageCount > 0 ? "\(min(unreadMessageCount, 9))" : nil,
                    badgeColor: accentWarm
                ) {
                    showMessages = true
                }
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

            VStack(alignment: .leading, spacing: -2) {
                Text(state.title)
                    .font(.system(size: 44, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.58)

                Text(state.italicLine)
                    .font(.system(size: 39, weight: .regular, design: .serif))
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
            suggestedFocusCard
        }
    }

    var activeFocusCountdownCard: some View {
        let timeStr = focusSession.timeString
        let progress = max(0.025, focusSession.progress)
        let elapsedText = elapsedSecondsText

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(accentGreen)
                        .frame(width: 7, height: 7)
                        .scaleEffect(pulse ? 1.45 : 1.0)
                        .opacity(pulse ? 0.45 : 1.0)
                        .shadow(color: accentGreen.opacity(0.70), radius: 7)

                    Text("AKTİF FOCUS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.9)
                        .foregroundStyle(accentCyan)
                }

                Spacer()

                Text(activeFocusMetaText)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.48))
            }

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    countdownDisplay(text: timeStr)

                    Text(activeFocusGoalText)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white.opacity(0.82))
                }

                Spacer(minLength: 8)

                HStack(spacing: 10) {
                    Button {
                        focusSession.togglePause()
                    } label: {
                        Image(systemName: focusSession.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
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
                            .frame(width: 48, height: 48)
                            .background(
                                Circle()
                                    .fill(.white)
                                    .shadow(color: Color.black.opacity(0.26), radius: 10, y: 5)
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
                                colors: shimmer
                                    ? [accentPrimary, accentSecondary, accentCyan]
                                    : [accentCyan, accentSecondary, accentPrimary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 5)

            HStack {
                Text("Odak devam ediyor")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.46))

                Spacer()

                Text(elapsedText)
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.46))
            }
        }
        .padding(16)
        .background(homeSurface(cornerRadius: 28, tint: accentCyan, secondaryTint: accentPrimary))
        .scaleEffect(breathe ? 1.004 : 1.0)
        .shadow(color: Color.black.opacity(0.22), radius: 18, y: 10)
        .opacity(pageAppeared ? 1 : 0)
        .offset(y: pageAppeared ? 0 : 12)
        .animation(.spring(response: 0.6, dampingFraction: 0.86).delay(0.08), value: pageAppeared)
    }

    func countdownDisplay(text: String) -> some View {
        let parts = text.split(separator: ":").map(String.init)

        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            ForEach(Array(parts.enumerated()), id: \.offset) { idx, part in
                if idx > 0 {
                    Text(":")
                        .font(.system(size: 36, weight: .black, design: .serif))
                        .italic()
                        .foregroundStyle(.white.opacity(0.38))
                        .offset(y: -2)
                }

                Text(part)
                    .font(.system(size: 58, weight: .black, design: .serif))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: idx == 0
                                ? [.white, accentCyan, accentPrimary]
                                : [.white, accentSecondary, accentPrimary],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .kerning(-2)
            }
        }
    }

    var suggestedFocusCard: some View {
        let state = resolveSuggestedFocus()

        return Button {
            Task {
                _ = await focusSession.startRequestedSession(
                    mode: .personal,
                    durationMinutes: state.minutes,
                    goal: .study,
                    style: .silent
                )
            }
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(accentCyan)
                                .frame(width: 6, height: 6)

                            Text(state.eyebrow)
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(1.9)
                                .foregroundStyle(accentCyan)
                        }

                        Text(state.title)
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(state.subtitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.48))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }

                    Spacer(minLength: 10)

                    ZStack {
                        Circle()
                            .fill(homePrimaryGradient)
                            .frame(width: 54, height: 54)

                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(.white)
                            .offset(x: 1)
                    }
                    .shadow(color: accentCyan.opacity(0.18), radius: 12, y: 7)
                }

                HStack(spacing: 8) {
                    HomeFocusMiniPill(icon: "timer", text: "\(state.minutes) dk", tint: accentCyan)
                    HomeFocusMiniPill(icon: "book.closed", text: "Study", tint: accentPrimary)
                    HomeFocusMiniPill(icon: "speaker.slash", text: "Silent", tint: accentSecondary)
                    Spacer()
                }
            }
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(homeSurface(cornerRadius: 28, tint: accentCyan, secondaryTint: accentPrimary))
            .shadow(color: Color.black.opacity(0.22), radius: 18, y: 10)
            .scaleEffect(breathe ? 1.002 : 1.0)
        }
        .buttonStyle(.plain)
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
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("BUGÜNÜN AKIŞI")

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
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.9)
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentCyan, accentSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    var filledTimeline: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 6) {
                Text("\(todayEvents.count)")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(.white)

                Text("etkinlik")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white.opacity(0.62))

                if pastEventsCount > 0 {
                    Text("·")
                        .foregroundStyle(.white.opacity(0.28))

                    Text("\(pastEventsCount) tamamlandı")
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
                accentPrimary: accentPrimary,
                accentSecondary: accentSecondary,
                accentActive: accentCyan
            )
            .frame(height: 108)
        }
        .padding(15)
        .background(homeSurface(cornerRadius: 28, tint: accentCyan, secondaryTint: accentPrimary))
        .shadow(color: Color.black.opacity(0.20), radius: 16, y: 9)
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
                    Text("Gün senin")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)

                    Text("Programına şekil ver, akış kendiliğinden gelir.")
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

                        Text("Görev ekle")
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

// MARK: - Stats Row

private extension HomeView {
    var statsRow: some View {
        HStack(spacing: 10) {
            HomeMetricCard(
                eyebrow: "FOCUS",
                value: "\(weeklyFocusMinutes)",
                unit: "dk",
                subtitle: weeklyFocusMinutes > 0 ? "bu hafta" : "başlatmaya hazır",
                tint: accentCyan,
                icon: "timer"
            )

            HomeMetricCard(
                eyebrow: "GÖREV",
                value: "\(activeTaskCount)",
                unit: "aktif",
                subtitle: completedTodayCount > 0 ? "\(completedTodayCount) yapıldı" : "ilk görevi ekle",
                tint: accentPrimary,
                icon: "checklist"
            )

            HomeMetricCard(
                eyebrow: "SERİ",
                value: "\(streakDays)",
                unit: "gün",
                subtitle: streakDays > 0 ? "devam ediyor" : "bugün başlasın",
                tint: accentGold,
                icon: "flame.fill"
            )
        }
        .opacity(pageAppeared ? 1 : 0)
        .offset(y: pageAppeared ? 0 : 12)
        .animation(.spring(response: 0.6, dampingFraction: 0.86).delay(0.18), value: pageAppeared)
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

    struct SuggestedFocusState {
        let eyebrow: String
        let title: String
        let subtitle: String
        let minutes: Int
    }

    func resolveHomeState() -> HeroState {
        if focusSession.isSessionActive {
            return HeroState(
                eyebrow: "ŞU AN · ODAKTASIN",
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
                eyebrow: "ŞU AN · CANLI",
                title: active.title,
                italicLine: "aktif ders",
                metaItems: locationAndTimeMeta(
                    event: active,
                    extra: "\(remaining) dk kaldı"
                ),
                showLiveDot: true,
                accent: accentGold,
                liveAccent: accentGreen
            )
        }

        if let upcoming = upcomingEventWithin(minutes: 90) {
            let mins = upcoming.startMinute - currentMinuteOfDay

            return HeroState(
                eyebrow: "SIRADAKİ DERS · YAKINDA",
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
                eyebrow: "BUGÜN · ÖNCELİKLİ",
                title: "\(overdueTaskCount) görev",
                italicLine: "seni bekliyor",
                metaItems: [
                    MetaItem(icon: "checklist", text: "\(activeTaskCount) aktif görev")
                ],
                showLiveDot: true,
                accent: accentWarm,
                liveAccent: accentGold
            )
        }

        if streakDays > 0 && !hasFocusToday {
            return HeroState(
                eyebrow: "SERİ · KORU",
                title: "\(streakDays) günlük",
                italicLine: "serini koru",
                metaItems: [
                    MetaItem(icon: "flame.fill", text: "bugün focus yap")
                ],
                showLiveDot: false,
                accent: accentGold,
                liveAccent: accentGold
            )
        }

        if activeTaskCount > 0 {
            return HeroState(
                eyebrow: "BUGÜN · DEVAM",
                title: greetingPrefix,
                italicLine: displayName.isEmpty ? "akışı kur" : displayName,
                metaItems: [
                    MetaItem(icon: "checklist", text: "\(activeTaskCount) aktif görev")
                ],
                showLiveDot: false,
                accent: accentCyan,
                liveAccent: accentCyan
            )
        }

        return HeroState(
            eyebrow: "BUGÜN · SAKİN",
            title: greetingPrefix,
            italicLine: displayName.isEmpty ? "hoş geldin" : displayName,
            metaItems: [],
            showLiveDot: false,
            accent: accentCyan,
            liveAccent: accentCyan
        )
    }

    func resolveSuggestedFocus() -> SuggestedFocusState {
        if let upcoming = upcomingEventWithin(minutes: 60) {
            let mins = upcoming.startMinute - currentMinuteOfDay
            let suggested: Int

            if mins >= 30 {
                suggested = 20
            } else if mins >= 15 {
                suggested = 15
            } else {
                suggested = 10
            }

            return SuggestedFocusState(
                eyebrow: "ÖNERİLEN",
                title: "\(suggested) dk hazırlık focus'u",
                subtitle: "\(upcoming.title) dersine ısın",
                minutes: suggested
            )
        }

        if streakDays > 0 && !hasFocusToday {
            return SuggestedFocusState(
                eyebrow: "SERİ KORUMA",
                title: "Hızlı 15 dk focus",
                subtitle: "\(streakDays) günlük serini koru",
                minutes: 15
            )
        }

        if overdueTaskCount > 0 {
            return SuggestedFocusState(
                eyebrow: "ÖNERİLEN",
                title: "25 dk derin çalışma",
                subtitle: "\(overdueTaskCount) bekleyen görev için",
                minutes: 25
            )
        }

        return SuggestedFocusState(
            eyebrow: "ÖNERİLEN",
            title: "15 dk hızlı focus",
            subtitle: "Sakin bir başlangıç yap",
            minutes: 15
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
        if minutesUntil <= 0 { return "başlıyor" }
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
            return "Günaydın,"
        case 12..<18:
            return "Tünaydın,"
        default:
            return "İyi akşamlar,"
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
            return "\(h)s \(m)dk geçti"
        } else if elapsed >= 60 {
            return "\(elapsed / 60) dk geçti"
        }

        return "\(elapsed) sn geçti"
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

        let totalSeconds = allFocusRecords
            .filter { record in
                guard let userID = currentUserID,
                      record.ownerUserID == userID else { return false }

                return record.endedAt >= weekStart && record.isCompleted
            }
            .map(\.completedSeconds)
            .reduce(0, +)

        return totalSeconds / 60
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

        guard let uid = currentUserID else { return false }

        return allFocusRecords.contains { record in
            record.ownerUserID == uid &&
            record.isCompleted &&
            cal.isDate(record.endedAt, inSameDayAs: now)
        }
    }

    var streakDays: Int {
        let cal = Calendar.current

        guard let uid = currentUserID else { return 0 }

        let userRecords = allFocusRecords.filter {
            $0.ownerUserID == uid && $0.isCompleted
        }

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

// MARK: - Smart Timeline View

private struct CurvedTimelineView: View {
    let events: [EventItem]
    let currentMinute: Int
    let pulse: Bool
    let accentPrimary: Color
    let accentSecondary: Color
    let accentActive: Color

    private let dayStartMin: Double = 6 * 60
    private let dayEndMin: Double = 24 * 60

    private var trackCyan: Color { Color(arenaHex: "#2DD4FF") }
    private var trackBlue: Color { Color(arenaHex: "#1593FF") }
    private var trackViolet: Color { Color(arenaHex: "#7C3AED") }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                hourMarkers(width: width, height: height)
                smartRhythmTrack(width: width, height: height)
                eventDots(width: width, height: height)

                if dayContainsNow {
                    nowIndicator(width: width, height: height)
                }
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
    func smartRhythmTrack(width: CGFloat, height: CGFloat) -> some View {
        let path = rhythmPath(width: width, height: height)

        path
            .stroke(
                trackCyan.opacity(0.115),
                style: StrokeStyle(
                    lineWidth: 3,
                    lineCap: .round,
                    lineJoin: .round
                )
            )

        path
            .trim(from: 0, to: CGFloat(currentDayProgress))
            .stroke(
                LinearGradient(
                    colors: [
                        trackViolet,
                        trackBlue,
                        trackCyan
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
            .shadow(color: trackCyan.opacity(0.16), radius: 5)
    }

    func rhythmPath(width: CGFloat, height: CGFloat) -> Path {
        var path = Path()
        let samples = 96

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
                        .fill(accentActive.opacity(0.20))
                        .frame(width: 24, height: 24)
                        .scaleEffect(pulse ? 1.32 : 1.0)
                        .opacity(pulse ? 0.0 : 0.65)
                        .position(p)
                }

                Circle()
                    .fill(dotColor(isPast: isPast, isActive: isActive))
                    .frame(width: isActive ? 11 : 8, height: isActive ? 11 : 8)
                    .overlay(
                        Circle()
                            .stroke(
                                Color.white.opacity(isActive ? 0.84 : 0.18),
                                lineWidth: isActive ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isActive ? accentActive.opacity(0.38) : Color.clear,
                        radius: isActive ? 7 : 0
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

        Circle()
            .fill(accentActive.opacity(0.18))
            .frame(width: 26, height: 26)
            .scaleEffect(pulse ? 1.32 : 1.0)
            .opacity(pulse ? 0.0 : 0.56)
            .position(p)

        Circle()
            .fill(accentActive)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.92), lineWidth: 2)
            )
            .shadow(color: accentActive.opacity(0.42), radius: 8)
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
        let base = height * 0.58
        let energy = workloadEnergy(at: minute)

        let lift = CGFloat(energy) * height * 0.34
        let progress = progressForMinute(minute)
        let softWave = sin(progress * Double.pi * 2.0) * Double(height) * 0.030

        let y = Double(base - lift) + softWave

        return CGFloat(max(Double(height * 0.20), min(Double(height * 0.76), y)))
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

            total += influence * (0.38 + durationWeight * 0.34)
        }

        return max(0.10, min(0.92, total))
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

// MARK: - Mini Pill

private struct HomeFocusMiniPill: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .black))

            Text(text)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(0.5)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            Capsule()
                .fill(tint.opacity(0.105))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.14), lineWidth: 1)
                )
        )
    }
}

// MARK: - Metric Card

private struct HomeMetricCard: View {
    let eyebrow: String
    let value: String
    let unit: String
    let subtitle: String
    let tint: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .center) {
                Text(eyebrow)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.45)
                    .foregroundStyle(tint.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 4)

                Image(systemName: icon)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(tint.opacity(0.72))
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Text(unit)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white.opacity(0.42))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }

            Text(subtitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(2)
                .minimumScaleFactor(0.74)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.052),
                            tint.opacity(0.035),
                            Color.black.opacity(0.020)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.115),
                                    Color.white.opacity(0.045)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.16), radius: 12, y: 7)
    }
}
