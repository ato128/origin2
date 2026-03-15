//
//  HomeDashboardView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 7.03.2026.
//

import SwiftUI
import SwiftData
import Combine

struct HomeDashboardView: View {
    @AppStorage("smartEngineEnabled") var smartEngineEnabled: Bool = true
    @AppStorage("appTheme")  var appTheme = AppTheme.gradient.rawValue
     let palette = ThemePalette()
    
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var store: TodoStore

    @Query(sort: \EventItem.startMinute, order: .forward)
    var allEvents: [EventItem]

    @Query(sort: \Friend.createdAt, order: .reverse)
    private var friends: [Friend]

    @Query(sort: \FriendMessage.createdAt, order: .reverse)
    private var allFriendMessages: [FriendMessage]
    
    @Query private var focusSessions: [CrewFocusSession]

    let onAddTask: () -> Void
    let onOpenWeek: () -> Void
    let onOpenInsights: () -> Void
    

    let dayTitles = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]

    @State var showingFocusSession: Bool = false
    @State var isFocusActive: Bool = false
    @State var activeFocusTaskTitle: String = ""
    @State var activeFocusRemainingSeconds: Int = 25 * 60
    @State var activeFocusStartedAt: Date? = nil
    @State var activeFocusTotalSeconds: Int = 25 * 60
    @State var pulseActiveFocus: Bool = false
    @State var liveDotPulse: Bool = false
    @State var nextClassPulse: Bool = false
    @State var nextClassSweep: Bool = false
    @State var selectedDay: Int = 0
    @State var showFriendsShortcut = false
    @State var showRecentFriendChat = false
    @State var pulseRecentFriendPill = false
    @State var crewFocusGlowPulse: Bool = false

    @State private var showHeaderCard = false
    @State private var showWeekCard = false
    @State private var showProgressCard = false
    @State private var showFocusCard = false
    @State private var showNextClassCard = false
    @State private var showTodayTasksCard = false
    @State private var showQuickActionsCard = false

    let focusRefreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var smartSuggestions: [SmartTaskSuggestion] {
        guard smartEngineEnabled else { return [] }
        return SmartTaskEngine.suggestions(
            tasks: allTasks,
            events: allEvents
        )
    }

    var allTasks: [DTTaskItem] { store.items }

    var todayTasks: [DTTaskItem] {
        let cal = Calendar.current
        return allTasks
            .filter { task in
                guard !task.isDone else { return false }
                guard let due = task.dueDate else { return false }
                return cal.isDateInToday(due)
            }
            .sorted {
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
    }
    
    private var themedCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }

    var completedTodayCount: Int {
        let cal = Calendar.current
        return allTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return cal.isDateInToday(completedAt)
        }.count
    }

    var totalTodayTaskCount: Int {
        completedTodayCount + todayTasks.count
    }

    var streakCount: Int {
        StreakEngine.currentStreak(tasks: allTasks)
    }

    var focusTask: DTTaskItem? {
        let active = allTasks.filter { !$0.isDone }
        let now = Date()

        let upcoming = active.filter {
            guard let due = $0.dueDate else { return false }
            return due >= now
        }

        if let nearestUpcoming = upcoming.sorted(by: {
            ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
        }).first {
            return nearestUpcoming
        }

        return active.sorted { a, b in
            let aDate = a.dueDate ?? .distantFuture
            let bDate = b.dueDate ?? .distantFuture
            let aDiff = abs(aDate.timeIntervalSince(now))
            let bDiff = abs(bDate.timeIntervalSince(now))
            return aDiff < bDiff
        }.first
    }

    var focusTaskStatusText: String {
        guard let task = focusTask else { return "Bugün odak görevi yok" }

        if store.isOverdue(task) {
            return "⚠️ Gecikmiş görev"
        }

        if let due = task.dueDate,
           Calendar.current.isDateInToday(due) {
            return "🔥 Bugün tamamla"
        }

        return "🎯 Öncelikli görev"
    }

    var recentChatFriend: Friend? {
        let sorted = allFriendMessages.sorted { $0.createdAt > $1.createdAt }
        guard let latestMessage = sorted.first else { return nil }
        return friends.first(where: { $0.id == latestMessage.friendID })
    }

    var nextEvent: EventItem? {
        let today = weekdayIndexToday()
        let now = currentMinuteOfDay()

        let todaysEvents = allEvents
            .filter { $0.weekday == today }
            .sorted { $0.startMinute < $1.startMinute }

        if let live = todaysEvents.first(where: {
            now >= $0.startMinute && now < ($0.startMinute + $0.durationMinute)
        }) {
            return live
        }

        return todaysEvents.first(where: { $0.startMinute > now })
    }

    var nextEventStatusText: String {
        guard let nextEvent else { return "Bugün başka ders yok" }

        let now = currentMinuteOfDay()
        let start = nextEvent.startMinute
        let end = nextEvent.startMinute + nextEvent.durationMinute

        if now >= start && now < end {
            let left = max(0, end - now)
            return "Şu an aktif • \(left) dk kaldı"
        } else {
            let remain = max(0, start - now)
            return "\(remain) dk sonra"
        }
    }

    var nextEventTimeText: String {
        guard let nextEvent else { return "--:--" }
        return "\(hm(nextEvent.startMinute)) – \(hm(nextEvent.startMinute + nextEvent.durationMinute))"
    }
    
    var activeCrewFocusSession: CrewFocusSession? {
        focusSessions
            .filter { $0.isActive }
            .sorted { $0.startedAt > $1.startedAt }
            .first
    }

    var hasAnyActiveFocusSession: Bool {
        guard let timestamp = UserDefaults.standard.object(forKey: "focus_end_date") as? Double else {
            return false
        }

        let endDate = Date(timeIntervalSince1970: timestamp)
        return endDate.timeIntervalSinceNow > 0
    }

    var isSharedFocusActive: Bool {
        UserDefaults.standard.string(forKey: "focus_mode") == "shared" && hasAnyActiveFocusSession
    }

    var activeSharedFriendName: String? {
        UserDefaults.standard.string(forKey: "focus_friend_name")
    }

    var focusCardTitle: String {
        if isSharedFocusActive {
            return "Shared Focus"
        }
        return "Focus Now"
    }

    var focusCardMainText: String {
        if isSharedFocusActive, let friendName = activeSharedFriendName {
            return "\(friendName) ile focus"
        }
        return focusTask?.title ?? "Bugün odak görevi yok"
    }

    var focusCardStatusText: String {
        if isSharedFocusActive {
            return "🟢 Shared session active"
        }
        return focusTaskStatusText
    }

    var todayProgressValue: Double {
        guard totalTodayTaskCount > 0 else { return 0 }
        return Double(completedTodayCount) / Double(totalTodayTaskCount)
    }

    var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var todayDateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM, EEEE"
        return f.string(from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                headerCard
                    .offset(y: showHeaderCard ? 0 : 18)
                    .opacity(showHeaderCard ? 1 : 0)
                    .scaleEffect(showHeaderCard ? 1 : 0.985)

                homeMiniWeekCalendar
                    .offset(y: showWeekCard ? 0 : 18)
                    .opacity(showWeekCard ? 1 : 0)
                    .scaleEffect(showWeekCard ? 1 : 0.985)

                todayProgressCard
                    .offset(y: showProgressCard ? 0 : 18)
                    .opacity(showProgressCard ? 1 : 0)
                    .scaleEffect(showProgressCard ? 1 : 0.985)

                if let session = activeCrewFocusSession {
                    crewSharedFocusCard(session: session)
                        .offset(y: showFocusCard ? 0 : 18)
                        .opacity(showFocusCard ? 1 : 0)
                        .scaleEffect(showFocusCard ? 1 : 0.985)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.98).combined(with: .opacity),
                            removal: .scale(scale: 0.96).combined(with: .opacity)
                        ))
                }
                else if hasAnyActiveFocusSession {
                    activeFocusCard
                        .offset(y: showFocusCard ? 0 : 18)
                        .opacity(showFocusCard ? 1 : 0)
                        .scaleEffect(showFocusCard ? 1 : 0.985)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.98).combined(with: .opacity),
                            removal: .scale(scale: 0.96).combined(with: .opacity)
                        ))
                } else {
                    focusCard
                        .offset(y: showFocusCard ? 0 : 18)
                        .opacity(showFocusCard ? 1 : 0)
                        .scaleEffect(showFocusCard ? 1 : 0.985)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.98).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                nextClassCard
                    .offset(y: showNextClassCard ? 0 : 18)
                    .opacity(showNextClassCard ? 1 : 0)
                    .scaleEffect(showNextClassCard ? 1 : 0.985)

                todayTasksCard
                    .offset(y: showTodayTasksCard ? 0 : 18)
                    .opacity(showTodayTasksCard ? 1 : 0)
                    .scaleEffect(showTodayTasksCard ? 1 : 0.985)
                
                if smartEngineEnabled, let firstSuggestion = smartSuggestions.first {
                    SmartTaskSuggestionCard(suggestion: firstSuggestion)
                }

                quickActionsCard
                    .offset(y: showQuickActionsCard ? 0 : 18)
                    .opacity(showQuickActionsCard ? 1 : 0)
                    .scaleEffect(showQuickActionsCard ? 1 : 0.985)
            }
            .padding(.horizontal, 16)
            .padding(.top, 0)
            .padding(.bottom, 36)
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isFocusActive)
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 90)
        }
       
        .sheet(isPresented: $showingFocusSession) {
            FocusSessionView(
                taskTitle: focusTask?.title,
                onStartFocus: { title, totalSeconds in
                    activeFocusTaskTitle = title
                    activeFocusTotalSeconds = totalSeconds
                    activeFocusRemainingSeconds = totalSeconds
                    activeFocusStartedAt = Date()
                    isFocusActive = true
                    pulseActiveFocus = true
                },
                onTick: { remaining in
                    activeFocusRemainingSeconds = remaining
                },
                onFinishFocus: { _, _, _, _, _, _ in
                    isFocusActive = false
                    activeFocusTaskTitle = ""
                    activeFocusRemainingSeconds = 25 * 60
                    activeFocusTotalSeconds = 25 * 60
                    activeFocusStartedAt = nil
                    pulseActiveFocus = false
                }
            )
        }
        .sheet(isPresented: $showRecentFriendChat) {
            if let recentFriend = recentChatFriend {
                NavigationStack {
                    FriendChatView(friend: recentFriend)
                }
            }
        }
        .sheet(isPresented: $showFriendsShortcut) {
            NavigationStack {
                CrewView(initialTab: .friends)
            }
        }
        .onAppear {
            selectedDay = weekdayIndexToday()
            syncActiveFocusCountdown()

            showHeaderCard = false
            showWeekCard = false
            showProgressCard = false
            showFocusCard = false
            showNextClassCard = false
            showTodayTasksCard = false
            showQuickActionsCard = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    showHeaderCard = true
                }
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    crewFocusGlowPulse = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    showWeekCard = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    showProgressCard = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    showFocusCard = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    showNextClassCard = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    showTodayTasksCard = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                    showQuickActionsCard = true
                }
            }
        }
        .onChange(of: isFocusActive) { _, newValue in
            pulseActiveFocus = newValue
        }
        .onReceive(focusRefreshTimer) { _ in
            syncActiveFocusCountdown()
        }
    }
    
    func focusChip(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(color.opacity(0.14))
        )
    }
    func crewFocusAccentColor(for session: CrewFocusSession) -> Color {
        let remaining = max(0, Int(session.endDate.timeIntervalSinceNow))

        if session.isPaused {
            return .orange
        }

        if remaining <= 180 {
            return .red
        }

        if remaining <= 600 {
            return .orange
        }

        return .blue
    }
    
    func crewSharedFocusCard(session: CrewFocusSession) -> some View {

        let remaining = session.isPaused
            ? max(0, session.pausedRemainingSeconds ?? 0)
            : max(0, Int(session.endDate.timeIntervalSinceNow))

        let minutes = remaining / 60
        let seconds = remaining % 60
        let timeText = String(format: "%02d:%02d", minutes, seconds)

        let total = Double(session.durationMinutes * 60)
        let progress = min(1, max(0, 1 - Double(remaining) / total))

        let accent = crewFocusAccentColor(for: session)

        return VStack(alignment: .leading, spacing: 14) {

            HStack {
                HStack(spacing: 8) {

                    Circle()
                        .fill(accent.opacity(crewFocusGlowPulse ? 1.0 : 0.75))
                        .frame(width: 10, height: 10)
                        .shadow(color: accent.opacity(crewFocusGlowPulse ? 0.45 : 0.20), radius: 8)

                    Text("Focus Running")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(palette.primaryText)
                }

                Spacer()

                Text(timeText)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .contentTransition(.numericText())
            }

            Text(session.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(accent)
                .scaleEffect(y: 1.4)
                .animation(.linear(duration: 1), value: progress)

            HStack(spacing: 10) {

                focusChip(
                    title: session.isPaused ? "Duraklatıldı" : "Odak aktif",
                    icon: session.isPaused ? "pause.fill" : "timer",
                    color: accent
                )

                focusChip(
                    title: session.isPaused ? "Bekliyor" : "Devam",
                    icon: session.isPaused ? "moon.zzz.fill" : "scope",
                    color: session.isPaused ? .orange : .green
                )
            }

            HStack(spacing: 12) {

                NavigationLink {
                    CrewFocusRoomView(session: session)
                } label: {
                    Text("Open Focus")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(accent == .red ? Color.red : accent)
                        )
                }

                Button {
                    session.isActive = false
                    try? modelContext.save()
                } label: {
                    Text("Stop")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.red.opacity(0.12))
                        )
                }
            }
        }
        .padding(18)
        .background(
            ZStack {

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(palette.cardFill)

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(accent.opacity(0.30), lineWidth: 1)

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(crewFocusGlowPulse ? 0.20 : 0.10),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 20,
                            endRadius: 260
                        )
                    )
                    .blur(radius: 22)
            }
        )
        .shadow(
            color: accent.opacity(crewFocusGlowPulse ? 0.18 : 0.08),
            radius: 18,
            y: 8
        )
    }
}
