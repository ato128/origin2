//
//  CoachSheet.swift
//  DailyTodo
//

import SwiftUI
import SwiftData
import Charts

// MARK: - CoachSheet

struct CoachSheet: View {
    let courses: [Course]
    let ownerUserID: String?
    let languageCode: String
    let weeklyGoalMinutes: Int

    @StateObject private var store = StudyCoachStore()
    @StateObject private var creditMgr = CreditManager()

    @Query(sort: \FocusSessionRecord.startedAt, order: .reverse)
    private var allSessions: [FocusSessionRecord]

    @Environment(\.dismiss) private var dismiss
    @State private var showChat = false
    @State private var expandedTipIndex: Int? = nil

    private var mySessions: [FocusSessionRecord] {
        guard let uid = ownerUserID else { return allSessions }
        let scoped = allSessions.filter { $0.ownerUserID == uid }
        return scoped.isEmpty ? allSessions.filter { $0.ownerUserID == nil } : scoped
    }

    private var weeklyTotalMinutes: Int { weekDays.reduce(0) { $0 + $1.minutes } }

    private var weekDays: [(label: String, minutes: Int, isToday: Bool)] {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        let mondayOffset = weekday == 1 ? -6 : 2 - weekday
        guard let monday = cal.date(byAdding: .day, value: mondayOffset, to: today) else { return [] }
        let labels = (0..<7).map { localizedWeekdayShort($0) }
        return (0..<7).map { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: monday),
                  let dayEnd = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: day)) else {
                return (labels[offset], 0, false)
            }
            let start = cal.startOfDay(for: day)
            let mins = mySessions
                .filter { $0.startedAt >= start && $0.startedAt < dayEnd }
                .reduce(0) { $0 + $1.completedSeconds / 60 }
            return (labels[offset], mins, cal.isDateInToday(day))
        }
    }

    private var sevenDaysAgo: Date { Date().addingTimeInterval(-7 * 24 * 3600) }

    private var coachTips: [(icon: String, title: String, detail: String)] {
        var tips: [(icon: String, title: String, detail: String)] = []

        // Tip 1: Weekly progress
        let total = weeklyTotalMinutes
        let goal = weeklyGoalMinutes
        let pct = goal > 0 ? Int(Double(total) / Double(goal) * 100) : 0
        if pct >= 80 {
            tips.append(("flame.fill", "Harika hafta — hedefin %\(pct)'inde",
                tr("cs_strong_week", total)))
        } else if pct >= 40 {
            tips.append(("flame", tr("cs_goal_left", goal - total),
                tr("cs_progress", total, goal)))
        } else {
            tips.append(("target", tr("cs_finish_strong"),
                tr("cs_low", total)))
        }

        // Tip 2: Peak hour
        let hourBuckets = mySessions
            .filter { $0.startedAt >= sevenDaysAgo }
            .reduce(into: [Int: Int]()) {
                $0[Calendar.current.component(.hour, from: $1.startedAt), default: 0] += $1.completedSeconds / 60
            }
        if let bestHour = hourBuckets.max(by: { $0.value < $1.value })?.key {
            let period = bestHour < 12 ? "sabah" : bestHour < 17 ? tr("cs_afternoon") : tr("cs_evening")
            tips.append(("clock.fill", "En verimli saatin \(bestHour):00",
                tr("cs_best_hours", period)))
        } else {
            tips.append(("clock", tr("cs_discover_hours"),
                tr("cs_discover_sub")))
        }

        // Tip 3: Subject balance (based on session titles)
        let titleBuckets = mySessions
            .filter { $0.startedAt >= sevenDaysAgo && !$0.title.isEmpty }
            .reduce(into: [String: Int]()) {
                $0[$1.title, default: 0] += $1.completedSeconds / 60
            }
        if let top = titleBuckets.max(by: { $0.value < $1.value }), titleBuckets.count > 1 {
            tips.append(("book.fill", "\(top.key): \(top.value) dk bu hafta",
                tr("cs_top_area", top.key)))
        } else {
            tips.append(("book", tr("cs_course_tracking"),
                tr("cs_course_sub")))
        }

        return Array(tips.prefix(3))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ArenaBackground(primaryGlow: .cyan, secondaryGlow: .purple, warmGlow: .clear)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        chartsSection
                        tipsSection
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationTitle(tr("cs_study_coach"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .safeAreaInset(edge: .bottom) {
                koçaSorButton
            }
        }
        .sheet(isPresented: $showChat) {
            CoachChatOverlay(
                store: store,
                creditMgr: creditMgr,
                courses: courses.map(\.name),
                ownerUserID: ownerUserID,
                languageCode: languageCode
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            if let uid = ownerUserID {
                Task { await creditMgr.loadCredits(userID: uid) }
            }
        }
    }

    // MARK: - Charts section

    private var chartsSection: some View {
        HStack(alignment: .top, spacing: 16) {
            // Weekly ring
            VStack(spacing: 8) {
                Text("HAFTALIK HEDEF")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.5))

                ZStack {
                    Chart {
                        let prog = min(Double(weeklyTotalMinutes) / Double(max(weeklyGoalMinutes, 1)), 1.0)
                        SectorMark(
                            angle: .value("Tamamlanan", prog),
                            innerRadius: .ratio(0.64),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color(arenaHex: AppArenaPalette.cyan))
                        .cornerRadius(3)

                        SectorMark(
                            angle: .value("Kalan", max(1.0 - prog, 0.001)),
                            innerRadius: .ratio(0.64),
                            angularInset: 1.5
                        )
                        .foregroundStyle(.white.opacity(0.1))
                        .cornerRadius(3)
                    }
                    .frame(width: 110, height: 110)

                    VStack(spacing: 2) {
                        Text("\(weeklyTotalMinutes)")
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text("/ \(weeklyGoalMinutes) dk")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                }
            }
            .frame(maxWidth: 130)

            // Daily bar chart
            VStack(alignment: .leading, spacing: 8) {
                Text(tr("cs_daily_minutes_caps"))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.5))

                Chart(weekDays, id: \.label) { day in
                    BarMark(
                        x: .value(tr("cs_day"), day.label),
                        y: .value("Dakika", day.minutes)
                    )
                    .foregroundStyle(
                        day.isToday
                            ? Color(arenaHex: AppArenaPalette.cyan)
                            : Color.white.opacity(0.28)
                    )
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                }
                .chartYAxis(.hidden)
                .frame(height: 100)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Tips section

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(arenaHex: AppArenaPalette.gold))
                Text(tr("cs_coach_tips_caps"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.55))
            }

            ForEach(coachTips.indices, id: \.self) { i in
                CoachTipCard(
                    icon: coachTips[i].icon,
                    title: coachTips[i].title,
                    detail: coachTips[i].detail,
                    isExpanded: expandedTipIndex == i,
                    onTap: { expandedTipIndex = expandedTipIndex == i ? nil : i }
                )
            }
        }
    }

    // MARK: - Koça Sor button

    private var koçaSorButton: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.15)
            Button {
                showChat = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(tr("cs_ask_coach"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(creditMgr.credits) kredi")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(arenaHex: AppArenaPalette.cyan).opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(arenaHex: AppArenaPalette.cyan).opacity(0.5), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .background(.black.opacity(0.3))
    }
}

// MARK: - CoachTipCard

private struct CoachTipCard: View {
    let icon: String
    let title: String
    let detail: String
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(arenaHex: AppArenaPalette.cyan))
                        .frame(width: 28)

                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.vertical, 14)

                if isExpanded {
                    Text(detail)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                        .padding(.bottom, 14)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isExpanded)
    }
}

// MARK: - CoachChatOverlay

struct CoachChatOverlay: View {
    @ObservedObject var store: StudyCoachStore
    @ObservedObject var creditMgr: CreditManager
    let courses: [String]
    let ownerUserID: String?
    let languageCode: String

    @State private var inputText = ""
    @State private var showCreditAlert = false
    @State private var pendingMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.opacity(0.95).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Chat messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(store.messages.suffix(10)) { msg in
                                    chatBubble(msg)
                                        .id(msg.id)
                                }
                                if store.isThinking {
                                    streamingBubble
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .onChange(of: store.messages.count) { _, _ in
                            if let last = store.messages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                        .onChange(of: store.streamingText) { _, _ in
                            if let last = store.messages.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }

                    Divider().opacity(0.15)

                    // Input bar
                    inputBar
                }
            }
            .navigationTitle(tr("cs_ask_coach"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                if !store.messages.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .destructive) { store.clearHistory() } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                    }
                }
            }
        }
        .alert(tr("cs_spend_credit"), isPresented: $showCreditAlert) {
            Button(tr("common_cancel"), role: .cancel) {}
            Button(tr("cs_send_credits", creditMgr.credits, creditMgr.credits - 1)) {
                sendMessage(pendingMessage)
            }
        } message: {
            Text(tr("cs_credit_info", creditMgr.credits))
        }
        .onAppear {
            if store.messages.isEmpty {
                // Initial greeting is free — no credit charge
                Task { await store.startCoaching(courses: courses, goals: "", languageCode: languageCode) }
            }
        }
    }

    private var inputBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let block = creditMgr.blockMessage {
                Text(block)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.orange.opacity(0.9))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            HStack(spacing: 10) {
                TextField(tr("cs_ask_placeholder"), text: $inputText, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .tint(Color(arenaHex: AppArenaPalette.cyan))
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.white.opacity(0.08))
                    )
                    .disabled(store.isThinking)

                Button {
                    submitInput()
                } label: {
                    Image(systemName: "arrow.up.circle.fill").accessibilityLabel(tr("a11y_send"))
                        .font(.system(size: 34))
                        .foregroundStyle(
                            canSubmit
                                ? Color(arenaHex: AppArenaPalette.cyan)
                                : Color.white.opacity(0.2)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.black.opacity(0.6))
    }

    private var canSubmit: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
            && !store.isThinking
            && creditMgr.canSend
    }

    private func submitInput() {
        let msg = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard msg.count >= 10 else { return }

        // If cached, send for free; else show confirmation
        let hash = MessageCacheManager.shared.hash(for: msg)
        if MessageCacheManager.shared.lookup(hash) != nil {
            sendMessage(msg)
        } else {
            pendingMessage = msg
            showCreditAlert = true
        }
    }

    private func sendMessage(_ msg: String) {
        let text = msg
        inputText = ""
        Task {
            await store.sendMessage(text)
            creditMgr.recordSend(wasCached: store.lastWasCached)
            if let uid = ownerUserID {
                let hash = MessageCacheManager.shared.hash(for: text)
                await creditMgr.syncUsage(
                    userID: uid,
                    feature: "coach",
                    messageHash: hash,
                    wasCached: store.lastWasCached
                )
            }
        }
    }

    // MARK: - Bubble views

    private func chatBubble(_ msg: CoachMessage) -> some View {
        let isUser = msg.role == "user"
        let displayText = msg.text
            .replacingOccurrences(of: "<routine>[\\s\\S]*?</routine>",
                                  with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return HStack {
            if isUser { Spacer(minLength: 48) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(displayText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(isUser
                                  ? Color(arenaHex: AppArenaPalette.cyan).opacity(0.3)
                                  : Color.white.opacity(0.1))
                    )
                if msg.wasCached {
                    Label(tr("cs_from_cache"), systemImage: "bolt.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            if !isUser { Spacer(minLength: 48) }
        }
    }

    private var streamingBubble: some View {
        HStack {
            Text(store.streamingText.isEmpty ? "…" : store.streamingText)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.white.opacity(0.1))
                )
            Spacer(minLength: 48)
        }
    }
}
