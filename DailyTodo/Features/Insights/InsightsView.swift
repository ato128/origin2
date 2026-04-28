//
//  InsightsView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData

struct InsightsView: View {
    @EnvironmentObject var session: SessionStore
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    
    @EnvironmentObject var studentStore: StudentStore
    @State private var showExamPlannerSheet = false

    @AppStorage("smartEngineEnabled") private var smartEngineEnabled: Bool = true
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    @State private var scrollOffset: CGFloat = 0
    @State private var insightSelectedTab: AppTab = .tasks

    @State private var goTasks = false
    @State private var goWeek = false
    @State private var goFocus = false
    @State private var isStudyMode = false
    @State private var showAchievements = false
    @State private var identityExpanded = false
    
    @State private var showPremium = false
    @State private var showStudyWindowDetail = false
    
    @State private var premiumState: PremiumState = .free
    
    @State private var showCoachDetail = false
    
    @State private var showWeeklySignalDetail = false
    @State private var showIdentityLevelSheet = false

   
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
    

    @State private var showLevelUpCelebration = false
    @State private var showLevelUpBanner = false
    
   
    
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
            streakDays: vm.streakValueForUI
        )
    }

    private var filteredTasks: [DTTaskItem] {
        guard let currentUserIDString else { return [] }
        return tasks.filter { $0.ownerUserID == currentUserIDString }
    }

    private var filteredFocusSessions: [FocusSessionRecord] {
        guard let currentUserIDString else { return [] }

        let scoped = focusSessions.filter {
            $0.ownerUserID == currentUserIDString
        }

        if !scoped.isEmpty {
            return scoped
        }

        // Eski kayıtlarda ownerUserID nil kaldıysa onları da say
        return focusSessions.filter {
            $0.ownerUserID == nil
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

    var body: some View {
        ZStack(alignment: .top) {
            stableBackground

            if showTopBlur {
                Rectangle()
                    .fill(Color.black.opacity(0.50))
                    .frame(height: 98)
                    .ignoresSafeArea(edges: .top)
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 0.5),
                        alignment: .bottom
                    )
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
        }
        .sheet(isPresented: $showAchievements) {
            InsightsAchievementsView(badges: vm.allAchievementBadges)
        }
        .sheet(isPresented: $showPremium) {
            InsightsPremiumView {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    premiumState = .premium
                }
            }
        }
        .sheet(isPresented: $showStudyWindowDetail) {
            InsightsStudyWindowDetailView(
                data: vm.studyWindowDetailData,
                onOpenWeek: {
                    goWeek = true
                },
                onOpenFocus: {
                    goFocus = true
                }
            )
        }
        .sheet(isPresented: $showCoachDetail) {
            InsightsCoachDetailView(
                data: vm.coachDetailData,
                onAction: { action in
                    handleInsightAction(action)
                }
            )
        }
        .sheet(isPresented: $showWeeklySignalDetail) {
            InsightsWeeklySignalDetailView(
                data: vm.weeklySignalDetailData,
                onOpenWeek: {
                    goWeek = true
                },
                onOpenFocus: {
                    goFocus = true
                }
            )
        }
        .sheet(isPresented: $showExamPlannerSheet) {
            ExamPlannerSheet(
                courses: studentStore.courses,
                ownerUserID: currentUserIDString
            )
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
        .background(
            Group {
                NavigationLink("", isActive: $goTasks) {
                    TodoListView(selectedTab: $insightSelectedTab)
                }

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
            .hidden()
        )
    }
    
    private func handleFocusRecordSaved(_ record: FocusSessionRecord) {
        guard record.isCompleted else { return }

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
    
    
    private var identityCompletedTasks: Int {
        filteredTasks.filter(\.isDone).count
    }

    private var identityFocusSessions: Int {
        filteredFocusSessions.count
    }

    private var stableBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.purple.opacity(0.20),
                    .clear
                ],
                center: .topLeading,
                startRadius: 10,
                endRadius: 360
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.indigo.opacity(0.24),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.blue.opacity(0.12),
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.94),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Insights")
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Personal performance center")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    isStudyMode.toggle()
                }
            } label: {
                ZStack {
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 58, height: 42)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    Image(systemName: isStudyMode ? "chart.bar.fill" : "graduationcap.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(isStudyMode ? .white.opacity(0.88) : Color.accentColor)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var contentSection: some View {
        VStack(spacing: 14) {
            InsightsHeroCardV2(
                data: vm.studyHeroPremium,
                isStudyMode: isStudyMode,
                action: handleInsightAction
            )

            HStack(spacing: 12) {
                InsightsIdentityCardV2(
                    snapshot: identitySnapshot,
                    isExpanded: identityExpanded,
                    hasPendingLevelUp: pendingLevelUp != nil || identitySnapshot.isReadyForLevelUp,
                    onTap: {
                        if pendingLevelUp != nil || identitySnapshot.isReadyForLevelUp {
                            preparePendingLevelUpIfNeeded()
                            showLevelUpCelebration = true
                        } else {
                            showIdentityLevelSheet = true
                        }
                    }
                )

                InsightsAchievementMiniCard(
                    badges: vm.achievementBadges,
                    onTap: { showAchievements = true }
                )
            }

            if premiumState != .free {
                InsightsPlusWeeklySignalCardV2(
                    data: vm.plusWeeklySignalCard,
                    action: handleInsightAction,
                    onTap: {
                        showWeeklySignalDetail = true
                    }
                )

                InsightsExamPlannerCTA {
                    showExamPlannerSheet = true
                }
            }

            InsightsPremiumCardV4(
                state: premiumState,
                action: {
                    if premiumState == .free {
                        showPremium = true
                    } else {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                            premiumState = .free
                        }
                    }
                },
                titleOverride: premiumState == .free ? nil : "Insights+ active",
                subtitleOverride: premiumState == .free ? nil : "Weekly Signal ve Exam Planner aktif.",
                buttonTitleOverride: premiumState == .free ? nil : "Return to Free",
                eyebrowOverride: premiumState == .free ? nil : "Insights+"
            )
        }
    }

    private var freeContentSection: some View {
        VStack(spacing: 14) {
            InsightsHeroCardV2(
                data: vm.studyHeroPremium,
                isStudyMode: isStudyMode,
                action: handleInsightAction
            )

            
            InsightsIdentityCardV2(
                snapshot: identitySnapshot,
                isExpanded: identityExpanded,
                hasPendingLevelUp: pendingLevelUp != nil || identitySnapshot.progress >= 1,
                onTap: {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        identityExpanded.toggle()
                    }
                }
            )

            InsightsAchievementsSectionV2(
                badges: vm.achievementBadges,
                onSeeAll: { showAchievements = true }
            )

            InsightsPremiumCardV4(state: .free) {
                showPremium = true
            }
        }
    }

    private var premiumContentSection: some View {
        VStack(spacing: 14) {
            deepHeroCard
            bestStudyWindowCard
            weeklyReviewCard
            identityEvolutionCard
            examReadinessCard
            patternAlertsSection

            InsightsPremiumCardV4(
                state: .premium,
                action: {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        premiumState = .free
                    }
                },
                titleOverride: "Back to free Insights",
                subtitleOverride: "This is a temporary premium preview. Tap below to return to the standard Insights screen.",
                buttonTitleOverride: "Return to Free",
                eyebrowOverride: "Insights+ Preview"
            )
        }
    }

    private var collapsedTopTitle: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("Insights")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(smallTitleOpacity)

                if isStudyMode {
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                        .opacity(smallTitleOpacity)
                }
            }
            .padding(.top, 10)

            Spacer()
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: collapseProgress)
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: isStudyMode)
    }

    private func handleInsightAction(_ action: SmartSuggestionAction) {
        switch action {
        case .openTasks:
            goTasks = true
        case .openWeek:
            goWeek = true
        case .openFocus:
            goFocus = true
        case .none:
            break
        }
    }
    private var deepHeroCard: some View {
        premiumSurface(tint: .purple) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Insights+")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))

                Text("Deeper rhythm")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Premium coaching, pattern analysis, and stronger guidance.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.74))

                HStack(spacing: 8) {
                    chip("AI Coach")
                    chip("Study Window")
                    chip("Streak Save")
                }
            }
        }
    }

    private var bestStudyWindowCard: some View {
        premiumSurface(tint: .purple) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Best Study Window")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.60))

                Text(vm.deepBestStudyWindow.timeRange)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(vm.deepBestStudyWindow.confidenceText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.68))

                Text(vm.deepBestStudyWindow.summary)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.76))
            }
        }
    }

    private var weeklyReviewCard: some View {
        premiumSurface(tint: .blue) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Weekly Deep Review")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Strongest: \(vm.deepWeeklyReview.strongestDay)")
                    .foregroundStyle(.white)

                Text("Weakest: \(vm.deepWeeklyReview.weakestDay)")
                    .foregroundStyle(.white.opacity(0.82))

                Text(vm.deepWeeklyReview.deltaText)
                    .foregroundStyle(.white.opacity(0.78))

                Text(vm.deepWeeklyReview.recommendation)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.74))
            }
        }
    }

    private var identityEvolutionCard: some View {
        premiumSurface(tint: .orange) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Identity Evolution")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(vm.deepIdentityEvolution.currentIdentity)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Next: \(vm.deepIdentityEvolution.nextIdentity)")
                    .foregroundStyle(.white.opacity(0.82))

                ProgressView(value: vm.deepIdentityEvolution.progress)
                    .tint(.white.opacity(0.88))

                Text(vm.deepIdentityEvolution.progressText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.70))
            }
        }
    }

    private var examReadinessCard: some View {
        premiumSurface(tint: .pink) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Exam Readiness Pro")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                ForEach(vm.deepExamRows) { exam in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(exam.title)
                                .foregroundStyle(.white)
                            Spacer()
                            Text(exam.readinessText)
                                .foregroundStyle(.white.opacity(0.76))
                        }

                        ProgressView(value: exam.progress)
                            .tint(.white.opacity(0.86))

                        Text(exam.riskText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.60))
                    }
                }
            }
        }
    }

    private var patternAlertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pattern Alerts")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            ForEach(vm.deepPatternAlerts) { alert in
                premiumSurface(tint: alert.tint) {
                    HStack(spacing: 12) {
                        Image(systemName: alert.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(alert.title)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text(alert.message)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.72))
                        }

                        Spacer()
                    }
                }
            }
        }
    }

    private func premiumSurface<Content: View>(
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.14),
                            Color.white.opacity(0.03),
                            Color.black.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )

            content()
                .padding(18)
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
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Yeni seviyeye hazırsın")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text("Lv.\(pending.pendingLevel) • \(pending.pendingTitle)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Spacer()

            Text("Aç")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white, in: Capsule())
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.black.opacity(0.86))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
        )
        .onTapGesture {
            showLevelUpCelebration = true
        }
    }
    
    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.84))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08), in: Capsule())
    }
}
struct InsightsExamPlannerCTA: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.orange.opacity(0.16))
                        .frame(width: 54, height: 54)

                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Sınav Çalışma Programı")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Yaklaşan sınavlara göre plan oluştur")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.56))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.48))
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(0.16),
                                Color.purple.opacity(0.08),
                                Color.black.opacity(0.90)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RadialGradient(
                            colors: [
                                Color.orange.opacity(0.18),
                                .clear
                            ],
                            center: .topTrailing,
                            startRadius: 4,
                            endRadius: 130
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
