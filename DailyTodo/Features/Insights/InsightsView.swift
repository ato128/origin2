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

    @ObservedObject private var progression = ProgressionManager.shared
    @ObservedObject private var subscription = SubscriptionManager.shared
    @State private var showStreakRestorePaywall = false

    @AppStorage("smartEngineEnabled") private var smartEngineEnabled: Bool = true
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    @State private var scrollOffset: CGFloat = 0

    @State private var goWeek = false
    @State private var goFocus = false

    @State private var isStudyMode = false
    @State private var showAchievements = false

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
        if isStudyMode {
            return Color(arenaHex: AppArenaPalette.gold)
        }

        if pendingLevelUp != nil || identitySnapshot.isReadyForLevelUp {
            return Color(arenaHex: AppArenaPalette.gold)
        }

        return Color(arenaHex: AppArenaPalette.cyan)
    }

    private var insightsSecondaryAccent: Color {
        if isStudyMode {
            return Color(arenaHex: AppArenaPalette.coral)
        }

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

    private var isTurkish: Bool {
        !appLanguageIsEnglish()
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
            .scrollIndicators(.hidden)

            collapsedTopTitle

            hiddenNavigationLinks
                .hidden()
        }
        .sheet(isPresented: $showAchievements) {
            InsightsAchievementsView(badges: vm.allAchievementBadges)
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

                    Text(isStudyMode ? "STUDY SIGNAL" : "PERFORMANCE CENTER")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(2.4)
                        .foregroundStyle(insightsAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("Insights")
                        .font(.system(size: 39, weight: .black))
                        .foregroundStyle(.white)

                    Text(isStudyMode ? "study" : "arena")
                        .font(.system(size: 36, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [insightsAccent, insightsSecondaryAccent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 8)

            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    isStudyMode.toggle()
                }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: isStudyMode ? "chart.bar.fill" : "graduationcap.fill")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(isStudyMode ? .black : insightsAccent)
                        .frame(width: 46, height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(
                                    isStudyMode
                                    ? AnyShapeStyle(
                                        LinearGradient(
                                            colors: [insightsAccent, insightsSecondaryAccent],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    : AnyShapeStyle(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.090),
                                                Color.white.opacity(0.050)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .stroke(Color.white.opacity(0.11), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.22), radius: 12, y: 6)
                        )

                    if pendingLevelUp != nil || identitySnapshot.isReadyForLevelUp {
                        Circle()
                            .fill(Color(arenaHex: AppArenaPalette.gold))
                            .frame(width: 11, height: 11)
                            .overlay(
                                Circle()
                                    .stroke(Color.black.opacity(0.80), lineWidth: 2)
                            )
                            .offset(x: 3, y: -3)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: - Content Section (yeni 4 component)

    @ViewBuilder
    private var contentSection: some View {
        VStack(spacing: 14) {
            // Identity (driver profile) — fed by real tasks / focus / streak.
            InsightsIdentityCardV3(
                snapshot: identitySnapshot,
                userName: resolvedUserName,
                hasPendingLevelUp: pendingLevelUp != nil || identitySnapshot.isReadyForLevelUp,
                onTap: handleIdentityTap
            )

            if progression.pendingStreakBreak {
                streakBreakBand
            }

            // Clean, data-first focus + tasks (tap focus for full history).
            InsightsDataDashboard(
                focusSessions: filteredFocusSessions,
                tasks: filteredTasks,
                accent: insightsAccent
            )

            // Exam planner.
            InsightsPremiumLabCard(
                isPremium: premiumState != .free,
                onExamPlanner: { showExamPlannerSheet = true },
                onCoach: { },
                onSmartInsights: { },
                onUpgrade: { showPremium = true }
            )
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

                Text("INSIGHTS")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(.white)
                    .opacity(smallTitleOpacity)

                if isStudyMode {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(insightsAccent)
                        .opacity(smallTitleOpacity)
                }
            }
            .padding(.top, 12)

            Spacer()
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: collapseProgress)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isStudyMode)
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
