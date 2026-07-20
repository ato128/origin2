//
//  UpdoAIView.swift
//  DailyTodo
//

import SwiftUI
import SwiftData
import Combine
import Supabase

struct UpdoAIView: View {
    var seedPrompt: String? = nil
    let onDismissAndOpenWeek: () -> Void
    let onDismissAndAddTask: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var store: TodoStore
    @EnvironmentObject private var studentStore: StudentStore

    @Query(sort: \DTTaskItem.createdAt, order: .reverse) private var allTasks: [DTTaskItem]
    @Query(sort: \FocusSessionRecord.startedAt, order: .reverse) private var allFocus: [FocusSessionRecord]

    @StateObject private var chatStore = UpdoAIChatStore()
    @ObservedObject private var credits = DailyCreditsManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var inputText = ""
    @State private var showFocusHistory = false
    @State private var showExamPlanner = false
    @State private var showClearAlert = false
    @State private var showToast = false
    @State private var toastText = ""
    @State private var emptyStateAppeared = false
    @State private var executedActionIDs: Set<UUID> = []
    @State private var dismissedActionIDs: Set<UUID> = []
    @State private var showPaywall = false
    @State private var showBYOKeySheet = false

    private let hapticSend = UIImpactFeedbackGenerator(style: .light)
    private let hapticResponse = UINotificationFeedbackGenerator()

    // MARK: - Context

    private var currentUserID: String? { session.currentUser?.id.uuidString }

    private var recentTasks: [DTTaskItem] {
        allTasks.filter { !$0.isDone && $0.ownerUserID == currentUserID }.prefix(10).map { $0 }
    }

    private var last7DaysFocus: [FocusSessionRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return allFocus.filter {
            $0.ownerUserID == currentUserID && $0.startedAt >= cutoff && $0.countsTowardStats
        }
    }

    private var contextSystemPrompt: String {
        var parts = [
            tr("ai_system_prompt"),
            personalContextBlock
        ]
        if !recentTasks.isEmpty {
            let taskList = recentTasks.prefix(5).map { taskContextLine($0) }.joined(separator: "\n")
            parts.append("\(tr("ai_active_tasks")):\n\(taskList)")
        }
        let totalFocusMins = last7DaysFocus.map { $0.completedSeconds / 60 }.reduce(0, +)
        if totalFocusMins > 0 {
            parts.append(tr("ai_focus_summary", totalFocusMins, last7DaysFocus.count))
        }
        return parts.joined(separator: "\n\n")
    }

    /// A compact, real snapshot of the user's day so the coach answers
    /// personally instead of generically. ~10 short lines, cheap on Haiku.
    private var personalContextBlock: String {
        let cal = Calendar.current
        let now = Date()
        var lines: [String] = []

        // The model has no clock — give it today's date so "yarın"/"pazartesi" land right.
        let weekdayIdx = (cal.component(.weekday, from: now) + 5) % 7
        lines.append(tr("ai_ctx_today", cal.component(.day, from: now),
                        localizedMonthShort(cal.component(.month, from: now) - 1),
                        localizedWeekdayFull(weekdayIdx)))

        // Today's task state.
        let doneToday = allTasks.filter {
            $0.ownerUserID == currentUserID && $0.isDone
            && $0.completedAt.map { cal.isDateInToday($0) } == true
        }.count
        let dueToday = allTasks.filter {
            $0.ownerUserID == currentUserID && !$0.isDone
            && $0.dueDate.map { cal.isDateInToday($0) } == true
        }.count
        lines.append(tr("ai_ctx_tasks_today", doneToday, dueToday))

        // Streak + today's two requirements (task AND focus).
        let streak = ProgressionManager.shared.currentStreak
        if streak > 0 {
            let hasFocusToday = allFocus.contains {
                $0.ownerUserID == currentUserID && $0.countsTowardStats && cal.isDateInToday($0.endedAt)
            }
            lines.append(tr("ai_ctx_streak", streak,
                            doneToday > 0 ? "✓" : "✗",
                            hasFocusToday ? "✓" : "✗"))
        }

        // Nearest upcoming exam.
        let exams = (try? modelContext.fetch(FetchDescriptor<ExamItem>())) ?? []
        let upcoming = exams
            .filter { ($0.ownerUserID == currentUserID || $0.ownerUserID == nil) && $0.examDate >= cal.startOfDay(for: now) }
            .min(by: { $0.examDate < $1.examDate })
        if let exam = upcoming {
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: now),
                                          to: cal.startOfDay(for: exam.examDate)).day ?? 0
            let name = exam.title.isEmpty ? exam.courseName : exam.title
            lines.append(tr("ai_ctx_exam", name, days))
        }

        return "\(tr("ai_ctx_header")):\n" + lines.map { "• \($0)" }.joined(separator: "\n")
    }

    /// "• Matematik çalış (yarın)" — a due date makes the plan advice concrete.
    private func taskContextLine(_ task: DTTaskItem) -> String {
        guard let due = task.dueDate else { return "• \(task.title)" }
        let cal = Calendar.current
        let dayText: String
        if cal.isDateInToday(due) { dayText = tr("ai_cmd_today") }
        else if cal.isDateInTomorrow(due) { dayText = tr("ai_cmd_tomorrow") }
        else {
            dayText = "\(cal.component(.day, from: due)) \(localizedMonthShort(cal.component(.month, from: due) - 1))"
        }
        return "• \(task.title) (\(dayText))"
    }

    // MARK: - Suggestions

    private struct Suggestion: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let subtitle: String
        let prompt: String
    }

    private let suggestions = [
        Suggestion(icon: "calendar.badge.clock", title: tr("ai_exam_plan"), subtitle: tr("ai_exam_plan_sub"), prompt: tr("ai_create_exam_plan")),
        Suggestion(icon: "checklist", title: tr("ai_plan_week"), subtitle: tr("ai_task_focus_sug"), prompt: tr("ai_plan_week")),
        Suggestion(icon: "chart.bar.fill", title: tr("ai_focus_analysis"), subtitle: tr("ai_review_7days"), prompt: tr("ai_show_analysis"))
    ]

    // MARK: - Computed

    private var showSmartChips: Bool { chatStore.messages.isEmpty && inputText.isEmpty }

    private var canSend: Bool {
        // Credits are checked in `routeUserInput` for the LLM path only — local
        // add/remove commands are free, so the button stays usable at 0 credits.
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !chatStore.isSending
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ArenaBackground(
                    primaryGlow: Color(arenaHex: "#7C3AED"),
                    secondaryGlow: Color(arenaHex: "#2DD4FF"),
                    warmGlow: Color(arenaHex: "#FF5A44")
                )
                .ignoresSafeArea()

                messagesScrollView

                if showToast {
                    toastBanner
                        .padding(.bottom, 96)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { dismissButton }
                ToolbarItem(placement: .principal) { navTitle }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        Button {
                            showBYOKeySheet = true
                        } label: {
                            Image(systemName: "key.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(
                                    BYOKeyStore.shared.hasKey
                                    ? Color(arenaHex: "#34D44A")
                                    : .white.opacity(0.7)
                                )
                                .frame(width: 34, height: 34)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().strokeBorder(UpdoTheme.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tr("byo_title"))

                        trashButton
                    }
                }
            }
            // Floating chrome: content flows behind; each element carries its own material
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .alert(tr("ai_clear_title"), isPresented: $showClearAlert) {
            Button(tr("ai_clear"), role: .destructive) {
                chatStore.clearHistory()
                executedActionIDs.removeAll()
                dismissedActionIDs.removeAll()
            }
            Button(tr("common_cancel"), role: .cancel) {}
        } message: {
            Text(tr("ai_clear_confirm"))
        }
        .sheet(isPresented: $showBYOKeySheet) {
            BYOKeySheet()
        }
        .sheet(isPresented: $showFocusHistory) {
            FocusHistorySheet(sessions: last7DaysFocus)
        }
        .sheet(isPresented: $showExamPlanner) {
            ExamPlannerSheet(courses: studentStore.courses, ownerUserID: currentUserID)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: "ai_exhausted")
        }
        .onAppear {
            hapticSend.prepare()
            hapticResponse.prepare()
            Task { await credits.refreshIfStale() }
            sendSeedIfNeeded()
        }
    }

    @State private var didSendSeed = false

    /// When the chat is opened from the Home "what do you want to do today?" bar,
    /// auto-send the user's typed intention as the first message.
    private func sendSeedIfNeeded() {
        guard !didSendSeed,
              let seed = seedPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
              !seed.isEmpty else { return }
        didSendSeed = true
        // Slight delay so the view is settled and credits had a tick to load.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            sendQuickMessage(seed)
        }
    }

    // MARK: - Toolbar Items

    private var dismissButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(UpdoTheme.border, lineWidth: 1))
        }
    }

    private var trashButton: some View {
        Button { showClearAlert = true } label: {
            Image(systemName: "trash")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(UpdoTheme.border, lineWidth: 1))
        }
    }

    /// Floating title pill — content scrolls behind it, like iMessage. The orb
    /// is alive: it talks while the AI is thinking/streaming.
    private var navTitle: some View {
        HStack(spacing: 7) {
            UpdoAIOrb(mode: chatStore.isSending ? .speaking : .idle, size: 17)

            Text("Updo")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(.white)
            +
            Text(" AI")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .italic()
                .foregroundStyle(UpdoTheme.cyan)

            if credits.isLoaded {
                Text("· \(tr("hv_ai_credit_n", credits.tokensRemaining))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: credits.tokensRemaining)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(UpdoTheme.border, lineWidth: 1))
    }

    // MARK: - Messages Scroll View

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if chatStore.messages.isEmpty {
                        // Empty state lives centered in the conversation area
                        emptyStateView
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 460)
                    } else {
                        let visible = Array(chatStore.messages.suffix(50))
                        ForEach(visible) { msg in
                            messageRow(msg)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 3)
                        }

                        if chatStore.isSending {
                            typingOrStreamingRow
                                .padding(.horizontal, 16)
                                .padding(.vertical, 3)
                                .id("typing")
                        }
                    }

                    Color.clear.frame(height: 8).id("bottom")
                }
                .animation(.default, value: showSmartChips)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: chatStore.messages.count)
            }
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(chatStore.messages.isEmpty ? .center : .bottom)
            .safeAreaInset(edge: .bottom) { bottomBar }
            .onChange(of: chatStore.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.22)) { proxy.scrollTo("bottom", anchor: .bottom) }
                if let last = chatStore.messages.last, last.role == "assistant" {
                    hapticResponse.notificationOccurred(.success)
                }
            }
            .onChange(of: chatStore.isSending) { _, sending in
                if sending { withAnimation(.easeOut(duration: 0.22)) { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
            .onChange(of: chatStore.streamingText) { _, text in
                if !text.isEmpty { withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo("typing", anchor: .bottom) } }
            }
        }
    }

    // MARK: - Message Row

    @ViewBuilder
    private func messageRow(_ msg: AIMessage) -> some View {
        messageBubble(msg)
            .transition(
                .asymmetric(
                    insertion: .move(edge: .bottom)
                        .combined(with: .opacity)
                        .combined(with: .scale(scale: 0.97, anchor: msg.role == "user" ? .bottomTrailing : .bottomLeading)),
                    removal: .opacity
                )
            )

        if msg.role == "assistant" {
            let items = UpdoAIPlanParser.parse(msg.text)
            if items.count >= 2
                && !executedActionIDs.contains(msg.id)
                && !dismissedActionIDs.contains(msg.id)
            {
                actionCard(items: items, msgID: msg.id)
                    .padding(.top, 6)
                    .padding(.leading, 32)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
            }
        }
    }

    // MARK: - Message Bubble

    @ViewBuilder
    private func messageBubble(_ msg: AIMessage) -> some View {
        let isUser = msg.role == "user"

        HStack(alignment: .bottom, spacing: 6) {
            if isUser {
                Spacer(minLength: 64)
            } else {
                aiAvatar
            }

            richText(msg.text)
                .font(.body)
                .lineSpacing(2)
                .foregroundStyle(isUser ? Color.white : UpdoTheme.textPrimary)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background {
                    if isUser {
                        LinearGradient(
                            colors: [UpdoTheme.cyan, UpdoTheme.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        UpdoTheme.surfaceHigh
                    }
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 18,
                        bottomLeadingRadius: isUser ? 18 : 5,
                        bottomTrailingRadius: isUser ? 5 : 18,
                        topTrailingRadius: 18
                    )
                )
                .overlay {
                    if !isUser {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 18,
                            bottomLeadingRadius: 5,
                            bottomTrailingRadius: 18,
                            topTrailingRadius: 18
                        )
                        .strokeBorder(UpdoTheme.border, lineWidth: 1)
                    }
                }

            if !isUser {
                Spacer(minLength: 64)
            }
        }
    }

    private var aiAvatar: some View {
        UpdoAIOrb(mode: .idle, size: 24)
    }

    // MARK: - Typing / Streaming

    @ViewBuilder
    private var typingOrStreamingRow: some View {
        HStack(alignment: .bottom, spacing: 6) {
            UpdoAIOrb(mode: .speaking, size: 24)

            if chatStore.streamingText.isEmpty {
                TypingIndicatorBubble()
            } else {
                richText(chatStore.streamingText)
                    .font(.body)
                    .lineSpacing(2)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(UpdoTheme.surfaceHigh)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 18,
                            bottomLeadingRadius: 5,
                            bottomTrailingRadius: 18,
                            topTrailingRadius: 18
                        )
                    )
            }

            Spacer(minLength: 64)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 30) {
            VStack(spacing: 16) {
                UpdoAIOrb(mode: .idle, size: 92)
                    .scaleEffect(emptyStateAppeared ? 1 : 0.7)
                    .opacity(emptyStateAppeared ? 1 : 0)

                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        Text("Updo")
                            .font(.system(size: 27, weight: .black))
                            .foregroundStyle(.white)

                        Text(" AI")
                            .font(.system(size: 26, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [UpdoTheme.cyan, UpdoTheme.purple],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                    }

                    Text(tr("ai_empty_sub"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .opacity(emptyStateAppeared ? 1 : 0)
                .offset(y: emptyStateAppeared ? 0 : 6)
            }

            VStack(spacing: 10) {
                ForEach(suggestions) { s in
                    Button { sendQuickMessage(s.prompt) } label: {
                        HStack(spacing: 13) {
                            Image(systemName: s.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(UpdoTheme.cyan)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(UpdoTheme.cyan.opacity(0.12))
                                        .overlay(Circle().strokeBorder(UpdoTheme.cyan.opacity(0.2), lineWidth: 1))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(s.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(UpdoTheme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .opacity(emptyStateAppeared ? 1 : 0)
                    .offset(y: emptyStateAppeared ? 0 : 10)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !emptyStateAppeared else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                emptyStateAppeared = true
            }
        }
        .onDisappear { emptyStateAppeared = false }
    }

    // MARK: - Smart Chips

    private var smartChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                smartChip(icon: "calendar", label: tr("ai_chip_week"), action: onDismissAndOpenWeek)
                smartChip(icon: "plus.circle.fill", label: tr("hv_add_task"), action: onDismissAndAddTask)
                smartChip(icon: "timer", label: tr("ai_chip_history")) { showFocusHistory = true }
                smartChip(icon: "calendar.badge.clock", label: tr("ai_exam_plan")) { showExamPlanner = true }
            }
        }
    }

    private func smartChip(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.primary.opacity(0.85))
            .padding(.horizontal, 13)
            .frame(height: 36)
            .background(
                Capsule().fill(UpdoTheme.surfaceHigh)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Bar (chips + iMessage-style input)

    /// Floating bottom unit: chips + input capsule hover over the conversation,
    /// no full-width bar — the content flows behind them (iMessage feel).
    private var bottomBar: some View {
        VStack(spacing: 8) {
            if showSmartChips {
                smartChipsRow
                    .padding(.horizontal, 12)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            inputBar
        }
        .padding(.bottom, 6)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showSmartChips)
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                if credits.isLoaded && !credits.canSendChatMessage {
                    Button {
                        Analytics.shared.track("ai_credits_exhausted")
                        Analytics.shared.track("feature_gate_triggered", properties: ["gate": "ai_exhausted"])
                        showPaywall = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill")
                                .font(.caption.bold())
                            Text("\(tr("ai_limit_full")) · \(tr("ai_go_pro_lc"))")
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(UpdoTheme.cyan)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 21, style: .continuous)
                                .strokeBorder(UpdoTheme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    // Alternatif yol: kendi OpenAI anahtarını ekle → sınırsız devam.
                    Button {
                        showBYOKeySheet = true
                    } label: {
                        Image(systemName: "key.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(UpdoTheme.cyan)
                            .frame(width: 42, height: 42)
                            .background(.ultraThinMaterial, in: Circle())
                            .overlay(Circle().strokeBorder(UpdoTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("byo_title"))
                } else {
                    // iMessage-style capsule: field with send button inside, trailing
                    HStack(alignment: .bottom, spacing: 4) {
                        TextField(tr("ai_input_placeholder"), text: $inputText, axis: .vertical)
                            .font(.body)
                            .lineLimit(1...5)
                            .padding(.leading, 14)
                            .padding(.vertical, 8)

                        Button(action: sendMessage) {
                            ZStack {
                                Circle().fill(
                                    chatStore.isSending || canSend
                                        ? UpdoTheme.cyan
                                        : Color(.systemFill)
                                )

                                if chatStore.isSending {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.black)
                                } else {
                                    Image(systemName: "arrow.up").accessibilityLabel(tr("a11y_send"))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(canSend ? .black : .secondary)
                                }
                            }
                            .frame(width: 30, height: 30)
                            .animation(.easeInOut(duration: 0.15), value: canSend)
                            .animation(.easeInOut(duration: 0.15), value: chatStore.isSending)
                        }
                        .disabled(!canSend)
                        .padding(.trailing, 4)
                        .padding(.bottom, 4)
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 21, style: .continuous)
                            .strokeBorder(UpdoTheme.border, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Action Card

    @ViewBuilder
    private func actionCard(items: [UpdoAIPlanItem], msgID: UUID) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(tr("ai_plan_ready"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(tr("rel_task_count", items.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { _ = dismissedActionIDs.insert(msgID) }
                } label: {
                    Text(tr("event_close"))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Button {
                    for item in items {
                        store.add(
                            title: item.title,
                            dueDate: item.dueDate,
                            scheduledWeekDate: item.dueDate,
                            scheduledWeekDurationMinutes: item.durationMinutes
                        )
                    }
                    withAnimation(.easeInOut(duration: 0.18)) { _ = executedActionIDs.insert(msgID) }
                    triggerToast(tr("ai_tasks_added"))
                } label: {
                    Text(tr("common_add"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(Capsule().fill(Color.green))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(UpdoTheme.surfaceHigh)
        )
    }

    // MARK: - Toast

    private var toastBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(toastText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(UpdoTheme.surfaceHigh)
                .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
        )
    }

    private func triggerToast(_ text: String) {
        toastText = text
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.22)) { showToast = false }
        }
    }

    // MARK: - Helpers

    /// Renders `**bold**` / `*italic*` inline markdown instead of showing the raw
    /// asterisks; falls back to plain text when parsing fails. Newlines preserved.
    private func richText(_ s: String) -> Text {
        if let attr = try? AttributedString(
            markdown: s,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attr)
        }
        return Text(s)
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !chatStore.isSending, currentUserID != nil else { return }
        hapticSend.impactOccurred()
        inputText = ""
        routeUserInput(text)
    }

    private func sendQuickMessage(_ prompt: String) {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !chatStore.isSending, currentUserID != nil else { return }
        hapticSend.impactOccurred()
        routeUserInput(text)
    }

    /// Tries the token-free local command interpreter first (add / remove /
    /// complete task). Only falls through to the paid LLM for real conversation.
    private func routeUserInput(_ text: String) {
        guard let uid = currentUserID else { return }

        if let result = UpdoAICommandInterpreter.interpret(
            text, store: store, context: modelContext, ownerUserID: uid
        ) {
            result.apply()
            chatStore.appendLocalExchange(userText: text, assistantText: result.reply)
            hapticResponse.notificationOccurred(.success)
            return
        }

        // Token'sız yerel koç: sık sorular kullanıcının gerçek verisiyle
        // anında cevaplanır — API'ye ve kotaya hiç dokunmaz.
        let intentContext = UpdoAIIntentResponder.Context(
            openTasks: recentTasks.prefix(5).map(\.title),
            todayFocusMinutes: last7DaysFocus
                .filter { Calendar.current.isDateInToday($0.endedAt) }
                .map { $0.completedSeconds / 60 }
                .reduce(0, +),
            weekFocusMinutes: last7DaysFocus.map { $0.completedSeconds / 60 }.reduce(0, +),
            weekSessionCount: last7DaysFocus.count,
            streak: ProgressionManager.shared.currentStreak
        )

        if let localReply = UpdoAIIntentResponder.answer(text, context: intentContext) {
            chatStore.appendLocalExchange(userText: text, assistantText: localReply)
            hapticResponse.notificationOccurred(.success)
            return
        }

        guard credits.canSendChatMessage else {
            chatStore.error = credits.limitMessage
            return
        }

        Task {
            await chatStore.send(text: text, contextPrompt: contextSystemPrompt, credits: credits, userID: uid)
        }
    }
}

// MARK: - Typing Indicator Bubble

private struct TypingIndicatorBubble: View {
    @State private var dotPhase = 0
    @State private var isActive = false

    private let dotTimer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 7, height: 7)
                    .opacity(isActive && dotPhase == i ? 0.9 : 0.3)
                    .animation(.linear(duration: 0.1), value: dotPhase)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(UpdoTheme.surfaceHigh)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 5,
                bottomTrailingRadius: 18,
                topTrailingRadius: 18
            )
        )
        .onAppear { isActive = true }
        .onDisappear { isActive = false }
        .onReceive(dotTimer) { _ in
            guard isActive else { return }
            dotPhase = (dotPhase + 1) % 3
        }
    }
}

// MARK: - Focus History Sheet

private struct FocusHistorySheet: View {
    let sessions: [FocusSessionRecord]
    @Environment(\.dismiss) private var dismiss

    private var totalMinutes: Int { sessions.map { $0.completedSeconds / 60 }.reduce(0, +) }
    private var avgMinutes: Int { sessions.isEmpty ? 0 : totalMinutes / sessions.count }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 0) {
                        statCell(value: "\(totalMinutes)", label: "Toplam dk")
                        Divider()
                        statCell(value: "\(sessions.count)", label: "Oturum")
                        Divider()
                        statCell(value: "\(avgMinutes)", label: "Ort. dk")
                    }
                    .listRowInsets(.init())
                    .listRowBackground(Color.clear)
                }

                if sessions.isEmpty {
                    EmptyStateView(
                        icon: "timer",
                        title: tr("ai_no_focus_session"),
                        subtitle: tr("ai_no_sessions")
                    )
                    .listRowInsets(.init())
                    .listRowBackground(Color.clear)
                } else {
                    Section("Oturumlar") {
                        ForEach(sessions.prefix(20)) { record in
                            sessionRow(record)
                        }
                    }
                }
            }
            .navigationTitle(tr("ai_focus_history"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("event_close")) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func sessionRow(_ record: FocusSessionRecord) -> some View {
        let mins = record.completedSeconds / 60
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.title.isEmpty ? "Focus oturumu" : record.title)
                    .font(.body.weight(.medium))
                Text(record.startedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(mins) dk")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
