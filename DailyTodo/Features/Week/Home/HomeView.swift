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
    @State private var showTimelineDetail = false
    @State private var pageAppeared = false
    @State private var now: Date = Date()

    @State private var pulse = false
    @State private var breathe = false
    @State private var shimmer = false
    @State private var shimmerPhase: CGFloat = -1.2

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
                VStack(alignment: .leading, spacing: focusSession.isSessionActive ? 18 : 22) {
                    topBar
                    heroSection
                    focusCard
                    timelineSection
                    statsRow

                    Color.clear.frame(height: focusSession.isSessionActive ? 168 : 96)
                }
                .padding(.horizontal, 16)
                .padding(.top, focusSession.isSessionActive ? 4 : 6)
            }
            .animation(.spring(response: 0.44, dampingFraction: 0.88), value: focusSession.isSessionActive)
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
            suggestedFocusCard
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

                    Text(isCritical ? "BİTMEK ÜZERE" : (isPaused ? "DURAKLATILDI" : "AKTİF FOCUS"))
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
                Text(isPaused ? "Duraklatıldı" : "Odak devam ediyor")
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
        VStack(alignment: .leading, spacing: focusSession.isSessionActive ? 12 : 14) {
            HStack(spacing: 10) {
                sectionTitle("BUGÜNÜN AKIŞI")

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
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 28, height: 1)

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
        }
    }

    var filledTimeline: some View {
        Button {
            showTimelineDetail = true
        } label: {
            VStack(alignment: .leading, spacing: focusSession.isSessionActive ? 11 : 13) {
                HStack(spacing: 6) {
                    Text("\(todayEvents.count)")
                        .font(.system(size: focusSession.isSessionActive ? 19 : 21, weight: .black))
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
                kind: .focus,
                eyebrow: "FOCUS",
                value: "\(weeklyFocusMinutes)",
                unit: "dk",
                subtitle: focusMetricSubtitle,
                progress: min(Double(weeklyFocusMinutes) / 120.0, 1.0),
                primaryTint: accentCyan,
                secondaryTint: accentSecondary,
                icon: "timer",
                isActive: weeklyFocusMinutes > 0,
                isCompleted: weeklyFocusMinutes >= 120
            )

            HomeMetricCard(
                kind: .task,
                eyebrow: "GÖREV",
                value: "\(activeTaskCount)",
                unit: activeTaskCount == 0 ? "aktif" : "aktif",
                subtitle: taskMetricSubtitle,
                progress: taskMetricProgress,
                primaryTint: taskMetricTint,
                secondaryTint: accentPrimary,
                icon: taskMetricIcon,
                isActive: activeTaskCount > 0,
                isCompleted: taskMetricCompleted
            )

            HomeMetricCard(
                kind: .streak,
                eyebrow: "SERİ",
                value: "\(streakDays)",
                unit: "gün",
                subtitle: streakMetricSubtitle,
                progress: min(Double(streakDays) / 7.0, 1.0),
                primaryTint: streakMetricTint,
                secondaryTint: accentWarm,
                icon: "flame.fill",
                isActive: streakDays > 0,
                isCompleted: streakDays >= 7
            )
        }
        .opacity(pageAppeared ? 1 : 0)
        .offset(y: pageAppeared ? 0 : 12)
        .animation(.spring(response: 0.6, dampingFraction: 0.86).delay(0.18), value: pageAppeared)
    }
    var focusMetricSubtitle: String {
        if weeklyFocusMinutes >= 120 {
            return "güçlü hafta"
        }

        if weeklyFocusMinutes >= 60 {
            return "iyi odak"
        }

        if weeklyFocusMinutes >= 15 {
            return "ritim başladı"
        }

        return "başlatmaya hazır"
    }

    var taskMetricCompleted: Bool {
        let totalTodayRelevant = activeTaskCount + completedTodayCount
        return totalTodayRelevant > 0 && activeTaskCount == 0 && completedTodayCount > 0
    }

    var taskMetricProgress: Double {
        let total = activeTaskCount + completedTodayCount
        guard total > 0 else { return 0 }
        return min(Double(completedTodayCount) / Double(total), 1.0)
    }

    var taskMetricTint: Color {
        if taskMetricCompleted {
            return accentGreen
        }

        if completedTodayCount > 0 {
            return accentGreen
        }

        if activeTaskCount > 0 {
            return accentPrimary
        }

        return accentPrimary.opacity(0.78)
    }

    var taskMetricIcon: String {
        if taskMetricCompleted {
            return "checkmark.circle.fill"
        }

        if activeTaskCount > 0 {
            return "slider.horizontal.3"
        }

        return "checklist"
    }

    var taskMetricSubtitle: String {
        if taskMetricCompleted {
            return "görevler tamam"
        }

        if completedTodayCount > 0 {
            return "\(completedTodayCount) tamamlandı"
        }

        if activeTaskCount > 0 {
            return "akış hazır"
        }

        return "ilk görevi ekle"
    }

    var streakMetricTint: Color {
        if streakDays >= 7 {
            return accentGold
        }

        if streakDays > 0 {
            return accentWarm
        }

        return accentGold.opacity(0.72)
    }

    var streakMetricSubtitle: String {
        if streakDays >= 7 {
            return "ateş gibi"
        }

        if streakDays >= 3 {
            return "ritim oluşuyor"
        }

        if streakDays > 0 {
            return "seri başladı"
        }

        return "bugün başlasın"
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

            if mins >= 35 {
                suggested = 25
            } else if mins >= 20 {
                suggested = 15
            } else {
                suggested = 10
            }

            return SuggestedFocusState(
                eyebrow: "DERS ÖNCESİ",
                title: "\(suggested) dk hazırlık focus'u",
                subtitle: "\(upcoming.title) için zihnini hazırla",
                minutes: suggested
            )
        }

        if streakDays > 0 && !hasFocusToday {
            return SuggestedFocusState(
                eyebrow: "SERİ KORUMA",
                title: "Bugün 15 dk yeter",
                subtitle: "\(streakDays) günlük ritmini kaybetme",
                minutes: 15
            )
        }

        if overdueTaskCount > 0 {
            return SuggestedFocusState(
                eyebrow: "ÖNCELİK",
                title: "25 dk derin çalışma",
                subtitle: "\(overdueTaskCount) bekleyen görevi erit",
                minutes: 25
            )
        }

        if activeTaskCount > 0 {
            return SuggestedFocusState(
                eyebrow: "SIRADAKİ",
                title: "20 dk görev focus'u",
                subtitle: "Aktif görevlerden birini ilerlet",
                minutes: 20
            )
        }

        if weeklyFocusMinutes >= 90 {
            return SuggestedFocusState(
                eyebrow: "RİTİM",
                title: "10 dk hafif focus",
                subtitle: "Bugünü küçük bir kapanışla tamamla",
                minutes: 10
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

// MARK: - Premium Countdown View (Serif Italic, native numeric transition)

private struct PremiumCountdownView: View {
    let text: String
    let isCritical: Bool
    let isPaused: Bool
    let warm: Color
    let gold: Color
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
                    .foregroundStyle(digitColor)
                    .kerning(-1.4)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(response: 0.40, dampingFraction: 0.86), value: part)
            }
        }
        .opacity(isPaused ? 0.55 : 1.0)
        .animation(.easeInOut(duration: 0.30), value: isPaused)
    }

    private var digitColor: Color {
        isCritical ? warm : .white
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
                    .font(.system(size: 31, weight: .black))
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

                Text("BUGÜNÜN AKIŞI · DETAY")
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
                Text("Günün")
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

            Text("\(events.count) etkinlik · \(pastEventsCount) tamamlandı · şu an \(formatHHmm(currentMinute))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.50))
        }
    }

    // MARK: Big timeline

    var bigTimeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("DETAYLI GÖRÜNÜM")
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
                eyebrow: "ZİRVE",
                title: peakHourText,
                subtitle: "yoğunluğun zirvesi",
                icon: "flame.fill",
                tint: accentGold
            )

            insightCard(
                eyebrow: "SAKİN",
                title: quietHourText,
                subtitle: "boş zaman penceresi",
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
                Text("ETKİNLİKLER")
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
            statusText = "ŞU AN"
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
        guard !events.isEmpty else { return "Tüm gün" }

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

