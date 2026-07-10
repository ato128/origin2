//
//  InsightsView.swift
//  DailyTodo
//
//  Yeniden yazıldı — kişisel gelişim merkezi.
//  Yapı: Header → Identity F1 → Journey → Achievement → Premium Lab
//

import SwiftUI
import SwiftData
import Combine

struct InsightsView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext

    @EnvironmentObject var studentStore: StudentStore
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var friendStore: FriendStore

    @ObservedObject private var progression = ProgressionManager.shared
    @ObservedObject private var subscription = SubscriptionManager.shared
    @ObservedObject private var avatarStore = ProfileAvatarStore.shared
    @State private var showStreakRestorePaywall = false

    // Profile (Instagram-style identity page)
    @State private var showProfileEdit = false
    @State private var showProfileShare = false

    @AppStorage("smartEngineEnabled") private var smartEngineEnabled: Bool = true
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    @State private var scrollOffset: CGFloat = 0

    @State private var goWeek = false
    @State private var goFocus = false

    @State private var showSettingsHub = false

    // Premium
    @State private var premiumState: PremiumState = .free
    @State private var showPremium = false

    // Sheet'ler
    @State private var showExamPlannerSheet = false
    @State private var comingSoonTool: PremiumLabTool?
    @State private var showIdentityLevelSheet = false

    // Identity level-up flow
    @State private var showLevelUpCelebration = false
    @State private var showLevelUpBanner = false

    @Query(sort: \DTTaskItem.createdAt, order: .reverse)
    private var tasks: [DTTaskItem]

    @Query(sort: \FocusSessionRecord.startedAt, order: .reverse)
    private var focusSessions: [FocusSessionRecord]

    @Query(sort: \EventItem.startMinute, order: .forward)
    private var events: [EventItem]

    @Query(sort: \ExamItem.examDate, order: .forward)
    private var exams: [ExamItem]

    @Query(sort: \IdentityProgressState.updatedAt, order: .reverse)
    private var identityProgressStates: [IdentityProgressState]

    @Query(sort: \IdentityLevelUpState.createdAt, order: .reverse)
    private var identityLevelUpStates: [IdentityLevelUpState]

    @Query(sort: \Friend.createdAt, order: .reverse)
    private var localFriends: [Friend]

    // MARK: - Identity helpers

    private var pendingLevelUp: IdentityLevelUpState? {
        identityLevelUpStates.first {
            $0.ownerUserID == currentUserIDString && $0.isPending
        }
    }

    private var nextIdentityLevel: IdentityLevelInfo {
        identitySnapshot.nextRequirement
    }

    private var currentUserIDString: String? {
        session.currentUser?.id.uuidString
    }

    private var storedIdentityState: IdentityProgressState? {
        identityProgressStates.first {
            $0.ownerUserID == currentUserIDString
        }
    }

    private var storedIdentityLevel: Int {
        storedIdentityState?.level ?? storedIdentityState?.currentLevel ?? 1
    }

    private var identitySnapshot: IdentityLevelSnapshot {
        IdentityXPLevelEngine.snapshot(
            currentLevel: storedIdentityLevel,
            tasks: filteredTasks,
            focusSessions: filteredFocusSessions,
            streakDays: progression.currentStreak
        )
    }

    // MARK: - Filtered data

    private var filteredTasks: [DTTaskItem] {
        guard let currentUserIDString else { return [] }
        return tasks.filter { $0.ownerUserID == currentUserIDString }
    }

    private var filteredFocusSessions: [FocusSessionRecord] {
        // Match FocusStats everywhere: the current user's records PLUS any un-owned
        // records (saved before the session store was ready). Using an either/or
        // filter here previously dropped those orphans, so Insights under-counted
        // vs the widget. Now they always agree.
        guard let currentUserIDString else {
            return focusSessions.filter { $0.ownerUserID == nil }
        }
        return focusSessions.filter {
            $0.ownerUserID == currentUserIDString || $0.ownerUserID == nil
        }
    }

    private var filteredEvents: [EventItem] {
        guard let currentUserIDString else { return [] }
        return events.filter { $0.ownerUserID == currentUserIDString }
    }

    private var filteredExams: [ExamItem] {
        guard let currentUserIDString else { return [] }
        return exams.filter { $0.ownerUserID == currentUserIDString }
    }

    private var vm: InsightsViewModel {
        InsightsViewModel(
            tasks: filteredTasks,
            focusSessions: filteredFocusSessions,
            events: filteredEvents,
            exams: filteredExams,
            userID: currentUserIDString,
            localeIdentifier: locale.identifier
        )
    }

    // MARK: - Scroll/header animation

    private var collapseProgress: CGFloat {
        let progress = (-scrollOffset - 20) / 70
        return min(max(progress, 0), 1)
    }

    private var smallTitleOpacity: CGFloat {
        min(max((collapseProgress - 0.15) / 0.55, 0), 1)
    }

    private var showTopBlur: Bool {
        collapseProgress > 0.16
    }

    private var insightsAccent: Color {
        if pendingLevelUp != nil || identitySnapshot.isReadyForLevelUp {
            return Color(arenaHex: AppArenaPalette.gold)
        }

        return Color(arenaHex: AppArenaPalette.cyan)
    }

    private var insightsSecondaryAccent: Color {
        if pendingLevelUp != nil || identitySnapshot.isReadyForLevelUp {
            return Color(arenaHex: AppArenaPalette.coral)
        }

        return Color(arenaHex: AppArenaPalette.purple)
    }

    private var resolvedUserName: String {
        let full = session.currentUser?.fullName ?? ""
        let trimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.isEmpty { return trimmed }

        if let username = session.currentUser?.username,
           !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return username
        }

        return "Driver"
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            stableBackground

            if showTopBlur {
                ArenaHeaderScrim(height: 128, materialHeight: 82)
                    .ignoresSafeArea(edges: .top)
                    .transition(.opacity)
            }

            ScrollView {
                ScrollOffsetReader(coordinateSpaceName: "insightsScroll")

                LazyVStack(spacing: 14) {
                    headerSection
                    identityHeroSection

                    // Each analytics card animates itself in as it enters the
                    // viewport (scrollTransition inside) — no offset math, no
                    // fragile preference plumbing.
                    contentSection

                    Spacer(minLength: 110)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .coordinateSpace(name: "insightsScroll")
            .onPreferenceChange(ScrollOffsetPreference.self) { value in
                scrollOffset = value
            }
            .modifier(InsightsScrollOffsetBridge(offset: $scrollOffset))
            .scrollIndicators(.hidden)

            collapsedTopTitle

            hiddenNavigationLinks
                .hidden()
        }
        .sheet(isPresented: $showSettingsHub) {
            NavigationStack {
                ProfileHubView()
            }
        }
        .sheet(isPresented: $showProfileEdit) {
            UpdoProfileEditSheet()
        }
        .sheet(isPresented: $showProfileShare) {
            UpdoProfileShareSheet(data: profileShareCardData)
        }
        .sheet(isPresented: $showStreakRestorePaywall) {
            PaywallView(context: "streak_restore")
        }
        .sheet(isPresented: $showPremium) {
            PaywallView(context: "insights_premium")
        }
        .onReceive(SubscriptionManager.shared.$isPro) { isPro in
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                premiumState = isPro ? .premium : .free
            }
        }
        .sheet(isPresented: $showExamPlannerSheet) {
            ExamPlannerSheet(
                courses: studentStore.courses,
                ownerUserID: currentUserIDString
            )
        }
        .sheet(item: $comingSoonTool) { tool in
            InsightsComingSoonSheet(tool: tool)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showIdentityLevelSheet) {
            InsightsIdentityLevelSheet(
                snapshot: identitySnapshot,
                onLevelUp: {
                    preparePendingLevelUpIfNeeded()
                    showLevelUpCelebration = true
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showLevelUpCelebration) {
            let targetLevel = pendingLevelUp?.pendingLevel ?? identitySnapshot.nextRequirement.level
            let info = InsightsIdentityLevelSystem.info(for: targetLevel)

            IdentityLevelUpCelebrationView(
                oldLevel: identitySnapshot.level,
                newLevel: targetLevel,
                title: info.title,
                accent: info.accent
            ) {
                completeLevelUpDirectly(to: targetLevel)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            syncIdentityProgressState()
        }
        .onChange(of: focusSessions.count) { _, _ in
            syncIdentityProgressState()
        }
        .onChange(of: filteredTasks.filter(\.isDone).count) { _, _ in
            syncIdentityProgressState()
        }
        .overlay(alignment: .top) {
            if showLevelUpBanner, let pending = pendingLevelUp {
                levelUpBanner(pending)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSessionRecordSaved)) { output in
            guard let record = output.object as? FocusSessionRecord else { return }
            handleFocusRecordSaved(record)
        }
    }

    // MARK: - Hidden Nav Links

    private var hiddenNavigationLinks: some View {
        Group {
            NavigationLink("", isActive: $goWeek) {
                WeekView()
            }

            NavigationLink("", isActive: $goFocus) {
                FocusSessionView(
                    taskID: nil,
                    taskTitle: String(localized: "insights_quick_focus_title"),
                    onStartFocus: { _, _ in },
                    onTick: { _ in },
                    onFinishFocus: { _, _, _, _, _, _ in },
                    workoutExercises: nil
                )
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(insightsAccent)
                        .frame(width: 20, height: 1)

                    Text(tr("ins_hdr_eyebrow"))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(2.4)
                        .foregroundStyle(insightsAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Text(tr("ins_title"))
                    .font(.system(size: 39, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 8)

            // Settings (the old Home profile hub) — the only chrome up here.
            Button {
                HapticManager.shared.navigation()
                showSettingsHub = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.090),
                                        Color.white.opacity(0.050)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.22), radius: 12, y: 6)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Identity hero (fills the first screen; analytics live below)
    //
    // The page opens as pure identity. Scrolling doesn't just push it away:
    // the ring parallaxes slower, everything scales down toward the top and
    // dissolves in stages — Apple-style collapse choreography driven by the
    // live scroll offset.

    @State private var heroRingFilled = false
    @State private var heroCueBounce = false
    @State private var heroEntered = false

    /// 0 = hero fully on screen, 1 = scrolled past. Drives the collapse.
    private var heroCollapse: CGFloat {
        min(max((-scrollOffset) / 320, 0), 1)
    }


    private var identityHeroSection: some View {
        let snapshot = identitySnapshot
        let hasPending = pendingLevelUp != nil || snapshot.isReadyForLevelUp
        let accent = hasPending ? Color(arenaHex: AppArenaPalette.gold) : snapshot.accent
        let secondary = hasPending ? Color(arenaHex: AppArenaPalette.coral) : Color(arenaHex: AppArenaPalette.blue)
        let progress = min(max(snapshot.progress, 0), 1)
        let collapse = heroCollapse

        return VStack(spacing: 0) {
            Spacer(minLength: 12)

            // Ring + avatar + name + title open the level sheet — the profile
            // actions below are their own buttons.
            Button(action: handleIdentityTap) {
                VStack(spacing: 0) {
                    heroRing(accent: accent, secondary: secondary, progress: progress)
                        // Parallax: the ring trails the scroll and gently shrinks.
                        .offset(y: -scrollOffset * 0.22)
                        .scaleEffect(1 - 0.16 * collapse)
                        .opacity(1 - Double(collapse) * 1.15)
                        .padding(.bottom, 26)

                    Group {
                        Text(resolvedUserName)
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .opacity(heroEntered ? 1 : 0)
                            .offset(y: heroEntered ? 0 : 10)
                            .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.30), value: heroEntered)

                        Text(snapshot.title)
                            .font(.system(size: 27, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accent, secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.top, 2)
                            .opacity(heroEntered ? 1 : 0)
                            .offset(y: heroEntered ? 0 : 12)
                            .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.42), value: heroEntered)

                        if let school = ProfileSchoolLine.text(for: studentStore.profile) {
                            Text(school.uppercased())
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .tracking(1.4)
                                .foregroundStyle(.white.opacity(0.42))
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .padding(.top, 7)
                                .opacity(heroEntered ? 1 : 0)
                                .animation(.easeOut(duration: 0.5).delay(0.50), value: heroEntered)
                        }

                        heroMetaRow(snapshot: snapshot, hasPending: hasPending)
                            .padding(.top, 10)
                            .opacity(heroEntered ? 1 : 0)
                            .animation(.easeOut(duration: 0.5).delay(0.55), value: heroEntered)
                    }
                }
            }
            .buttonStyle(.plain)

            Group {
                heroStatsRow
                    .padding(.top, 18)
                    .opacity(heroEntered ? 1 : 0)
                    .offset(y: heroEntered ? 0 : 8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.62), value: heroEntered)

                Button(action: handleIdentityTap) {
                    nextStepCapsule(snapshot: snapshot, hasPending: hasPending, accent: accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
                .opacity(heroEntered ? 1 : 0)
                .offset(y: heroEntered ? 0 : 8)
                .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.70), value: heroEntered)

                heroActionButtons
                    .padding(.top, 14)
                    .opacity(heroEntered ? 1 : 0)
                    .offset(y: heroEntered ? 0 : 8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.78), value: heroEntered)
            }

            Spacer(minLength: 12)

            // Scroll cue — first thing to melt away on scroll.
            VStack(spacing: 3) {
                Text(tr("ins_hero_scroll_cue"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))

                Image(systemName: "chevron.compact.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
                    .offset(y: heroCueBounce ? 3 : -1)
            }
            .padding(.bottom, 6)
            .opacity((1 - Double(collapse) * 3.2))
        }
        // Text/action block dissolves a beat after the ring while sliding up.
        .offset(y: -scrollOffset * 0.10)
        .opacity(1 - Double(min(max((collapse - 0.12) / 0.55, 0), 1)))
        .frame(maxWidth: .infinity)
        .frame(minHeight: max(440, UIScreen.main.bounds.height - 320))
        .scaleEffect(1 - 0.05 * collapse, anchor: .top)
        .onAppear {
            heroEntered = true
            avatarStore.load(for: currentUserIDString)

            // Real counts even when the crew tab was never opened this
            // session — both loads are internally cached/cheap.
            Task {
                await crewStore.loadCrews()
                if friendStore.friendships.isEmpty, let uid = session.currentUser?.id {
                    await friendStore.loadAllFriendships(currentUserID: uid)
                }
            }

            if !heroRingFilled {
                withAnimation(.spring(response: 1.1, dampingFraction: 0.76).delay(0.20)) {
                    heroRingFilled = true
                }
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                heroCueBounce = true
            }
        }
    }

    // MARK: - Profile pieces (friends · crews · streak, edit/share)

    private var heroFriendCount: Int {
        // Backend data loaded → honest live count (loads on hero appear).
        if !friendStore.friendships.isEmpty {
            return friendStore.friendships.filter { $0.status == "accepted" }.count
        }

        // Offline fallback: the locally synced friend list from the last visit.
        return localFriends.filter {
            $0.ownerUserID == nil || $0.ownerUserID == currentUserIDString
        }.count
    }

    /// Instagram-style counts, Updo-style chrome: three hairline-divided cells.
    private var heroStatsRow: some View {
        HStack(spacing: 0) {
            heroStatCell(value: "\(heroFriendCount)", label: tr("iid_stat_friends_caps"))

            heroStatDivider

            heroStatCell(value: "\(crewStore.crews.count)", label: tr("iid_stat_crews_caps"))

            heroStatDivider

            heroStatCell(
                value: "\(progression.currentStreak)",
                label: tr("iid_stat_streak_caps"),
                icon: progression.currentStreak > 0 ? "flame.fill" : nil,
                iconTint: Color(arenaHex: AppArenaPalette.gold)
            )
        }
        .frame(maxWidth: 320)
    }

    private var heroStatDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1, height: 26)
    }

    private func heroStatCell(
        value: String,
        label: String,
        icon: String? = nil,
        iconTint: Color = .white
    ) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(iconTint)
                }

                Text(value)
                    .font(.system(size: 19, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }

            Text(label)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.3)
                .foregroundStyle(.white.opacity(0.40))
        }
        .frame(maxWidth: .infinity)
    }

    private var heroActionButtons: some View {
        HStack(spacing: 10) {
            heroActionButton(icon: "pencil", title: tr("iid_edit_profile")) {
                HapticManager.shared.navigation()
                showProfileEdit = true
            }

            heroActionButton(icon: "square.and.arrow.up", title: tr("iid_share_profile")) {
                shareProfile()
            }
        }
        .frame(maxWidth: 320)
    }

    private func heroActionButton(
        icon: String,
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))

                Text(title)
                    .font(.system(size: 13.5, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.05))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.11), lineWidth: 1))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func shareProfile() {
        HapticManager.shared.action()
        showProfileShare = true
    }

    /// Live data snapshot for the staged share card.
    private var profileShareCardData: ProfileShareCardData {
        let snapshot = identitySnapshot

        return ProfileShareCardData(
            name: resolvedUserName,
            title: snapshot.title,
            school: ProfileSchoolLine.text(for: studentStore.profile),
            level: snapshot.level,
            progress: min(max(snapshot.progress, 0), 1),
            accent: snapshot.accent,
            secondary: Color(arenaHex: AppArenaPalette.blue),
            friendCount: heroFriendCount,
            crewCount: crewStore.crews.count,
            streak: progression.currentStreak,
            avatar: avatarStore.image
        )
    }

    /// The ring: hairline track, angular-gradient progress with a glowing knob
    /// at its tip, the user's photo (or serif monogram) at the heart, the level
    /// riding the bottom of the ring as a badge, breathing glow behind.
    private func heroRing(accent: Color, secondary: Color, progress: CGFloat) -> some View {
        ZStack {
            // Breathing background glow. The blur input is CONSTANT (opacity is
            // applied after the blur), so Core Animation caches the blurred
            // texture and each 12fps frame only recomposites alpha — near-zero
            // GPU cost instead of re-blurring a 250pt circle every frame.
            TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let breathe = 0.10 + 0.035 * sin(t * 0.9)

                Circle()
                    .fill(accent)
                    .frame(width: 250, height: 250)
                    .blur(radius: 54)
                    .opacity(breathe)
            }

            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: 9)
                .frame(width: 168, height: 168)

            // Progress arc + tip knob share one -90° container so the knob
            // always rides exactly on the arc's end.
            ZStack {
                Circle()
                    .trim(from: 0, to: heroRingFilled ? progress : 0.02)
                    .stroke(
                        AngularGradient(
                            colors: [accent.opacity(0.55), secondary, accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .shadow(color: accent.opacity(0.38), radius: 12)

                Circle()
                    .fill(.white)
                    .frame(width: 7, height: 7)
                    .shadow(color: accent.opacity(0.9), radius: 5)
                    .offset(x: 84)
                    .rotationEffect(.degrees(Double(heroRingFilled ? progress : 0.02) * 360))
            }
            .rotationEffect(.degrees(-90))
            .frame(width: 168, height: 168)

            // The person at the heart of the ring — photo, or a serif monogram
            // tinted by the level until one is set.
            ProfileAvatarCircle(
                image: avatarStore.image,
                name: resolvedUserName,
                accent: accent,
                size: 142
            )

            // Level badge straddling the ring's bottom edge — focus-timer
            // serif typography, filled with the level's own gradient.
            HStack(spacing: 6) {
                Text(tr("iid_level_caps"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(.black.opacity(0.6))

                Text("\(identitySnapshot.level)")
                    .font(.system(size: 19, weight: .semibold, design: .serif))
                    .italic()
                    .monospacedDigit()
                    .foregroundStyle(.black)
            }
            .padding(.horizontal, 13)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent, secondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(Capsule().strokeBorder(Color.black.opacity(0.30), lineWidth: 1))
            .shadow(color: accent.opacity(0.45), radius: 9, y: 3)
            .offset(y: 84)
        }
    }

    /// What still stands between the user and the next level, as a quiet
    /// tappable capsule — nobody should have to guess that tapping opens the
    /// requirements. Ready state flips it into a golden call-to-action.
    @ViewBuilder
    private func nextStepCapsule(snapshot: IdentityLevelSnapshot, hasPending: Bool, accent: Color) -> some View {
        let gold = Color(arenaHex: AppArenaPalette.gold)

        if hasPending {
            HStack(spacing: 7) {
                Image(systemName: "arrow.up.forward.circle.fill")
                    .font(.system(size: 12, weight: .black))

                Text(tr("iid_step_ready"))
                    .font(.system(size: 12.5, weight: .black, design: .rounded))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 15)
            .frame(height: 34)
            .background(Capsule().fill(gold))
            .shadow(color: gold.opacity(0.35), radius: 10, y: 4)
        } else if !snapshot.isMaxLevel, !missingRequirementsText(snapshot).isEmpty {
            HStack(spacing: 7) {
                Text(tr("iid_step_prefix"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.42))

                Text(missingRequirementsText(snapshot))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(accent.opacity(0.8))
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        Capsule().strokeBorder(accent.opacity(0.22), lineWidth: 1)
                    )
            )
        }
    }

    /// "2 focus · 5 görev · 1 gün seri" — only the parts that are still short.
    private func missingRequirementsText(_ snapshot: IdentityLevelSnapshot) -> String {
        let next = snapshot.nextRequirement
        var parts: [String] = []

        let focusLeft = max(0, next.requiredFocusSessions - snapshot.focusSessions)
        if focusLeft > 0 { parts.append(tr("iid_need_focus_n", focusLeft)) }

        let tasksLeft = max(0, next.requiredCompletedTasks - snapshot.completedTasks)
        if tasksLeft > 0 { parts.append(tr("iid_need_tasks_n", tasksLeft)) }

        let streakLeft = max(0, next.requiredStreakDays - snapshot.streakDays)
        if streakLeft > 0 { parts.append(tr("iid_need_streak_n", streakLeft)) }

        return parts.prefix(2).joined(separator: " · ")
    }

    /// Progress line: level road + live percent. (Streak moved into the
    /// profile stats row; ready state lives in the golden capsule below.)
    private func heroMetaRow(snapshot: IdentityLevelSnapshot, hasPending: Bool) -> some View {
        HStack(spacing: 8) {
            Text(tr("iid_next_level_fmt", snapshot.level + 1))
                .font(.system(size: 10.5, weight: .black, design: .monospaced))
                .tracking(1.0)
                .foregroundStyle(.white.opacity(0.42))

            if !snapshot.isMaxLevel {
                Text("·")
                    .foregroundStyle(.white.opacity(0.25))

                Text(snapshot.percentText)
                    .font(.system(size: 10.5, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    // MARK: - Content Section (yeni 4 component)

    @ViewBuilder
    private var contentSection: some View {
        VStack(spacing: 14) {
            if progression.pendingStreakBreak {
                streakBreakBand
                    .insightsCardReveal()
            }

            // Clean, data-first focus + tasks (tap focus for full history).
            InsightsDataDashboard(
                focusSessions: filteredFocusSessions,
                tasks: filteredTasks,
                accent: insightsAccent
            )

            // Which days actually fed the streak (task AND focus), this month.
            InsightsStreakCalendarCard(
                tasks: filteredTasks,
                focusSessions: filteredFocusSessions,
                accent: insightsAccent
            )
            .insightsCardReveal()

            // Exam planner.
            InsightsPremiumLabCard(
                isPremium: premiumState != .free,
                onExamPlanner: { showExamPlannerSheet = true },
                onCoach: { },
                onSmartInsights: { },
                onUpgrade: { showPremium = true }
            )
            .insightsCardReveal()
        }
    }

    // MARK: - Streak break / restore band

    private var streakBreakBand: some View {
        let coral = Color(arenaHex: AppArenaPalette.coral)
        let gold = Color(arenaHex: AppArenaPalette.gold)
        let restoresLeft = progression.restoresLeftThisMonth
        let canRestore = subscription.isPro && restoresLeft > 0

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "flame.slash.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(coral)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("ins_streak_broken_title"))
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)

                    Text(tr("ins_streak_broken_sub", progression.brokenStreakValue))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)
            }

            Button {
                if canRestore {
                    HapticManager.shared.success()
                    _ = progression.restoreStreak(context: modelContext)
                } else if !subscription.isPro {
                    showStreakRestorePaywall = true
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: subscription.isPro ? "arrow.uturn.backward.circle.fill" : "lock.fill")
                        .font(.system(size: 13, weight: .black))

                    Text(restoreButtonTitle(canRestore: canRestore, restoresLeft: restoresLeft))
                        .font(.system(size: 13, weight: .black))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    Capsule().fill(
                        LinearGradient(colors: [gold, Color(arenaHex: AppArenaPalette.coral)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                )
            }
            .buttonStyle(.plain)
            .disabled(subscription.isPro && restoresLeft == 0)
            .opacity(subscription.isPro && restoresLeft == 0 ? 0.5 : 1)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(coral.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private func restoreButtonTitle(canRestore: Bool, restoresLeft: Int) -> String {
        if !subscription.isPro {
            return tr("ins_restore_with_pro")
        }
        if restoresLeft > 0 {
            return tr("ins_restore_with_count", restoresLeft, ProgressionManager.monthlyRestoreLimit)
        }
        return tr("ins_restore_exhausted")
    }

    // MARK: - Identity tap

    private func handleIdentityTap() {
        if pendingLevelUp != nil || identitySnapshot.isReadyForLevelUp {
            preparePendingLevelUpIfNeeded()
            showLevelUpCelebration = true
        } else {
            showIdentityLevelSheet = true
        }
    }

    // MARK: - Collapsed Top Title

    private var collapsedTopTitle: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                Circle()
                    .fill(insightsAccent)
                    .frame(width: 7, height: 7)
                    .opacity(smallTitleOpacity)

                Text(tr("ins_title_caps"))
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(.white)
                    .opacity(smallTitleOpacity)
            }
            .padding(.top, 12)

            Spacer()
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: collapseProgress)
    }

    // MARK: - Background

    private var stableBackground: some View {
        ArenaBackground(
            primaryGlow: Color(arenaHex: AppArenaPalette.blue),
            secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
            warmGlow: Color(arenaHex: AppArenaPalette.gold),
            intensity: 0.92
        )
    }

    // MARK: - Identity flow (level-up)

    private func handleFocusRecordSaved(_ record: FocusSessionRecord) {
        guard record.countsTowardStats else { return }

        syncIdentityProgressState()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func completeLevelUpDirectly(to newLevel: Int) {
        guard let currentUserIDString else {
            showLevelUpCelebration = false
            return
        }

        let safeLevel = min(max(newLevel, 1), InsightsIdentityLevelSystem.maxLevel)

        if let pending = identityLevelUpStates.first(where: {
            $0.ownerUserID == currentUserIDString &&
            $0.isPending &&
            $0.pendingLevel == safeLevel
        }) {
            pending.isPending = false
            pending.completedAt = Date()
        }

        if let state = identityProgressStates.first(where: {
            $0.ownerUserID == currentUserIDString
        }) {
            state.level = safeLevel
            state.currentLevel = safeLevel
            state.totalXP = 0
            state.focusSessions = identitySnapshot.focusSessions
            state.completedTasks = identitySnapshot.completedTasks
            state.streakDays = identitySnapshot.streakDays
            state.updatedAt = Date()
        } else {
            let state = IdentityProgressState(
                ownerUserID: currentUserIDString,
                level: safeLevel,
                totalXP: 0,
                focusSessions: identitySnapshot.focusSessions,
                completedTasks: identitySnapshot.completedTasks,
                streakDays: identitySnapshot.streakDays,
                currentLevel: safeLevel
            )

            modelContext.insert(state)
        }

        try? modelContext.save()

        showLevelUpCelebration = false
        showIdentityLevelSheet = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            syncIdentityProgressState()
        }
    }

    private func syncIdentityProgressState() {
        guard let currentUserIDString else { return }

        if let existing = identityProgressStates.first(where: { $0.ownerUserID == currentUserIDString }) {
            existing.totalXP = 0
            existing.focusSessions = identitySnapshot.focusSessions
            existing.completedTasks = identitySnapshot.completedTasks
            existing.streakDays = identitySnapshot.streakDays
            existing.currentLevel = existing.level
            existing.updatedAt = Date()
        } else {
            let state = IdentityProgressState(
                ownerUserID: currentUserIDString,
                level: 1,
                totalXP: 0,
                focusSessions: identitySnapshot.focusSessions,
                completedTasks: identitySnapshot.completedTasks,
                streakDays: identitySnapshot.streakDays,
                currentLevel: 1
            )

            modelContext.insert(state)
        }

        preparePendingLevelUpIfNeeded(showBanner: false)

        try? modelContext.save()
    }

    private func preparePendingLevelUpIfNeeded(showBanner: Bool = true) {
        guard let currentUserIDString else { return }
        guard identitySnapshot.isReadyForLevelUp else { return }
        guard !identitySnapshot.isMaxLevel else { return }

        let targetLevel = identitySnapshot.nextRequirement.level

        let alreadyPending = identityLevelUpStates.contains {
            $0.ownerUserID == currentUserIDString &&
            $0.isPending &&
            $0.pendingLevel == targetLevel
        }

        guard !alreadyPending else { return }

        let pending = IdentityLevelUpState(
            ownerUserID: currentUserIDString,
            pendingLevel: targetLevel,
            pendingTitle: identitySnapshot.nextRequirement.title
        )

        modelContext.insert(pending)
        try? modelContext.save()

        guard showBanner else { return }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            showLevelUpBanner = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.25)) {
                showLevelUpBanner = false
            }
        }
    }

    private func levelUpBanner(_ pending: IdentityLevelUpState) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.up.forward.circle.fill")
                .font(.system(size: 23, weight: .black))
                .foregroundStyle(Color(arenaHex: AppArenaPalette.gold))

            VStack(alignment: .leading, spacing: 3) {
                Text("LEVEL READY")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(Color(arenaHex: AppArenaPalette.gold))

                Text("Lv.\(pending.pendingLevel) • \(pending.pendingTitle)")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()

            Text(tr("ins_open_caps"))
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(
                    Capsule()
                        .fill(Color(arenaHex: AppArenaPalette.gold))
                )
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: AppArenaPalette.gold).opacity(0.12),
                            Color(arenaHex: AppArenaPalette.coral).opacity(0.06),
                            Color.black.opacity(0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(arenaHex: AppArenaPalette.gold).opacity(0.20), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.26), radius: 16, y: 8)
        )
        .onTapGesture {
            showLevelUpCelebration = true
        }
    }
}

// MARK: - PremiumLabTool Identifiable extension (sheet item)

extension PremiumLabTool: Identifiable {
    var id: String {
        switch self {
        case .examPlanner: return "examPlanner"
        case .aiCoach: return "aiCoach"
        case .smartInsights: return "smartInsights"
        }
    }
}

// MARK: - Card reveal + scroll offset bridge

extension View {
    /// Analytics cards rise 44pt and fade in as they enter the viewport —
    /// native scrollTransition, fully interactive in both directions.
    func insightsCardReveal() -> some View {
        scrollTransition(.interactive(timingCurve: .easeOut)) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0)
                .offset(y: phase.isIdentity ? 0 : (phase.value > 0 ? 44 : -16))
                .scaleEffect(phase.isIdentity ? 1 : 0.98)
        }
    }
}

/// Feeds the hero's collapse choreography from the modern scroll-geometry API
/// on iOS 18+ (the GeometryReader/preference path can go quiet on newer OSes);
/// older systems keep the preference-based value.
private struct InsightsScrollOffsetBridge: ViewModifier {
    @Binding var offset: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, newValue in
                offset = -newValue
            }
        } else {
            content
        }
    }
}
