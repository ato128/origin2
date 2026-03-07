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
    @EnvironmentObject private var store: TodoStore

    @Query(sort: \EventItem.startMinute, order: .forward)
    private var allEvents: [EventItem]

    let onAddTask: () -> Void
    let onOpenWeek: () -> Void
    let onOpenInsights: () -> Void

    @State private var showingFocusSession: Bool = false
    @State private var isFocusActive: Bool = false
    @State private var activeFocusTaskTitle: String = ""
    @State private var activeFocusRemainingSeconds: Int = 25 * 60
    @State private var activeFocusTotalSeconds: Int = 25 * 60
    @State private var pulseActiveFocus: Bool = false
    @State private var liveDotPulse: Bool = false
    @State private var nextClassPulse: Bool = false
    @State private var nextClassSweep: Bool = false

    private let focusRefreshTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var allTasks: [DTTaskItem] { store.items }

    private var todayTasks: [DTTaskItem] {
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

    private var completedTodayCount: Int {
        let cal = Calendar.current
        return allTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return cal.isDateInToday(completedAt)
        }.count
    }

    private var totalTodayTaskCount: Int {
        completedTodayCount + todayTasks.count
    }

    private var streakCount: Int {
        StreakEngine.currentStreak(tasks: allTasks)
    }

    private var focusTask: DTTaskItem? {
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

    private var focusTaskStatusText: String {
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

    private var nextEvent: EventItem? {
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

    private var nextEventStatusText: String {
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

    private var nextEventTimeText: String {
        guard let nextEvent else { return "--:--" }
        return "\(hm(nextEvent.startMinute)) – \(hm(nextEvent.startMinute + nextEvent.durationMinute))"
    }

    private var todayProgressValue: Double {
        guard totalTodayTaskCount > 0 else { return 0 }
        return Double(completedTodayCount) / Double(totalTodayTaskCount)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var todayDateText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM, EEEE"
        return f.string(from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard
                todayProgressCard

                if isFocusActive {
                    activeFocusCard
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.98).combined(with: .opacity),
                            removal: .scale(scale: 0.96).combined(with: .opacity)
                        ))
                } else {
                    focusCard
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.98).combined(with: .opacity),
                            removal: .opacity
                        ))
                }

                nextClassCard
                todayTasksCard
                quickActionsCard
            }
            .padding(16)
            .padding(.bottom, 20)
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: isFocusActive)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showingFocusSession) {
            FocusSessionView(
                taskTitle: focusTask?.title,
                onStartFocus: { title, totalSeconds in
                    activeFocusTaskTitle = title
                    activeFocusTotalSeconds = totalSeconds
                    activeFocusRemainingSeconds = totalSeconds
                    isFocusActive = true
                    pulseActiveFocus = true
                },
                onTick: { remaining in
                    activeFocusRemainingSeconds = remaining
                },
                onFinishFocus: {
                    isFocusActive = false
                    activeFocusTaskTitle = ""
                    activeFocusRemainingSeconds = 25 * 60
                    activeFocusTotalSeconds = 25 * 60
                    pulseActiveFocus = false
                }
            )
        }
        .onChange(of: isFocusActive) { _, newValue in
            pulseActiveFocus = newValue
        }
        .onReceive(focusRefreshTimer) { _ in
            syncActiveFocusCountdown()
        }
    }
}

// MARK: - Sections
private extension HomeDashboardView {

    var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(greetingText) 👋")
                .font(.title2.bold())

            Text(todayDateText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Stay productive today 🚀")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var todayProgressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today Progress")
                    .font(.headline)

                Spacer()

                Text("\(completedTodayCount)/\(totalTodayTaskCount)")
                    .font(.title2.bold())
                    .monospacedDigit()
            }

            ProgressView(value: todayProgressValue)
                .tint(.accentColor)
                .scaleEffect(y: 1.8)

            HStack(spacing: 10) {
                miniBadge(
                    icon: "flame.fill",
                    text: "\(streakCount) gün seri",
                    tint: .orange
                )

                miniBadge(
                    icon: "checkmark.circle.fill",
                    text: "\(completedTodayCount) bugün tamamlandı",
                    tint: .green
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var focusCard: some View {
        Group {
            if let task = focusTask {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Focus Now")
                            .font(.headline)

                        Spacer()

                        Image(systemName: "scope")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }

                    Text(task.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        if let due = task.dueDate {
                            Label {
                                Text(due, style: .time)
                            } icon: {
                                Image(systemName: "calendar")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(focusTaskStatusText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(store.isOverdue(task) ? .red : .secondary)
                    }

                    Button {
                        showingFocusSession = true
                    } label: {
                        Text("Start Focus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(cardBackground)
            }
        }
    }

    var activeFocusCard: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let liveRemaining = liveFocusRemaining(at: now)
            let urgencyColor = activeFocusUrgencyColor(for: liveRemaining)
            let warmState = liveRemaining > 0 && liveRemaining <= 30

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(urgencyColor)
                            .frame(width: 8, height: 8)
                            .scaleEffect(liveDotPulse ? 1.4 : 0.8)
                            .opacity(liveDotPulse ? 0.6 : 1)
                            .animation(
                                .easeInOut(duration: 1)
                                    .repeatForever(autoreverses: true),
                                value: liveDotPulse
                            )

                        Text("Focus Running")
                            .font(.headline)
                    }

                    Spacer()

                    Text(liveFocusTimeText(at: now))
                        .font(.title3.bold())
                        .monospacedDigit()
                }

                Text(activeFocusTaskTitle.isEmpty ? "Deep Work Session" : activeFocusTaskTitle)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)

                smoothActiveFocusProgressBar(at: now)

                HStack(spacing: 10) {
                    miniBadge(
                        icon: "timer",
                        text: liveRemaining <= 30 ? "Son 30 saniye" : "Odak aktif",
                        tint: urgencyColor
                    )

                    miniBadge(
                        icon: "scope",
                        text: "Devam ediyor",
                        tint: warmState ? urgencyColor : .green
                    )
                }

                HStack(spacing: 12) {
                    Button {
                        showingFocusSession = true
                    } label: {
                        Text("Open Focus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        stopActiveFocus()
                    } label: {
                        Text("Stop")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.red.opacity(0.14))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(urgencyColor.opacity(warmState ? 0.08 : 0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                urgencyColor.opacity(pulseActiveFocus ? 0.38 : 0.18),
                                lineWidth: 1.2
                            )
                    )
            )
            .shadow(
                color: urgencyColor.opacity(pulseActiveFocus ? 0.28 : 0.12),
                radius: pulseActiveFocus ? 18 : 8,
                x: 0,
                y: 6
            )
            .scaleEffect(pulseActiveFocus ? 1.01 : 1.0)
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: pulseActiveFocus
            )
        }
        .onAppear {
            liveDotPulse = true
        }
    }

    var activeFocusProgress: Double {
        guard activeFocusTotalSeconds > 0 else { return 0 }
        return Double(activeFocusTotalSeconds - activeFocusRemainingSeconds) / Double(activeFocusTotalSeconds)
    }

    func smoothActiveFocusProgressBar(at date: Date) -> some View {
        let remaining = liveFocusRemaining(at: date)
        let progress = liveFocusProgress(at: date)
        let urgencyColor = activeFocusUrgencyColor(for: remaining)

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                urgencyColor,
                                urgencyColor.opacity(0.85)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: urgencyColor.opacity(0.5), radius: 6)
                    .frame(width: max(8, geo.size.width * progress))
            }
        }
        .frame(height: 12)
    }

    func liveFocusProgress(at date: Date) -> Double {
        guard activeFocusTotalSeconds > 0 else { return 0 }

        guard let timestamp = UserDefaults.standard.object(forKey: "focus_end_date") as? Double else {
            return activeFocusProgress
        }

        let endDate = Date(timeIntervalSince1970: timestamp)
        let remaining = max(0, endDate.timeIntervalSince(date))
        let elapsed = Double(activeFocusTotalSeconds) - remaining

        return min(1, max(0, elapsed / Double(activeFocusTotalSeconds)))
    }

    func liveFocusRemaining(at date: Date) -> Int {
        guard let timestamp = UserDefaults.standard.object(forKey: "focus_end_date") as? Double else {
            return activeFocusRemainingSeconds
        }

        let endDate = Date(timeIntervalSince1970: timestamp)
        return max(0, Int(endDate.timeIntervalSince(date).rounded(.down)))
    }

    func liveFocusTimeText(at date: Date) -> String {
        let remaining = liveFocusRemaining(at: date)
        let m = remaining / 60
        let s = remaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    func activeFocusUrgencyColor(for remaining: Int) -> Color {
        if remaining <= 10 && remaining > 0 {
            return .red
        } else if remaining <= 30 && remaining > 0 {
            return .orange
        } else {
            return .blue
        }
    }

    var nextClassCard: some View {
            let classColor = nextEvent.map { Color(hex: $0.colorHex) } ?? .secondary
            let animatedClassColor = classColor

            let startsSoon: Bool = {
                guard let nextEvent else { return false }
                let now = currentMinuteOfDay()
                let diff = nextEvent.startMinute - now
                return diff > 0 && diff <= 30
            }()
            
            let startsVerySoon: Bool = {
                guard let nextEvent else { return false }
                let now = currentMinuteOfDay()
                let diff = nextEvent.startMinute - now
                return diff > 0 && diff <= 5
            }()

            let isLiveNow: Bool = {
                guard let nextEvent else { return false }
                let now = currentMinuteOfDay()
                let start = nextEvent.startMinute
                let end = nextEvent.startMinute + nextEvent.durationMinute
                return now >= start && now < end
            }()

            return VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Next Class")
                        .font(.headline)
                        .foregroundStyle(nextEvent == nil ? .primary : animatedClassColor)

                    Spacer()

                    Button {
                        onOpenWeek()
                    } label: {
                        Image(systemName: "arrow.right")
                            .font(.caption.bold())
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(animatedClassColor.opacity(0.16))
                            )
                    }
                    .buttonStyle(.plain)
                }

                if let nextEvent {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(animatedClassColor)
                            .frame(width: 12, height: 12)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(nextEvent.title)
                                .font(.title3.bold())
                                .foregroundStyle(animatedClassColor)
                                .lineLimit(1)
                                .foregroundStyle(animatedClassColor)

                            Text(nextEventTimeText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                if nextEventStatusText.contains("aktif") {
                                    Text("LIVE")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(Color.green.opacity(0.18))
                                        )
                                        .foregroundStyle(.green)
                                }

                                Text(nextEventStatusText)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .id("\(nextEvent.title)-\(nextEvent.startMinute)-\(nextEvent.weekday)-\(nextEvent.colorHex)")
                    .transition(
                        .asymmetric(
                            insertion:
                                .move(edge: .trailing)
                                .combined(with: .opacity)
                                .combined(with: .scale(scale: 0.98)),
                            removal:
                                .move(edge: .leading)
                                .combined(with: .opacity)
                        )
                    )
                } else {
                    Text("Bugün başka ders yok")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .id("no-next-class")
                        .transition(.opacity)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(animatedClassColor.opacity(nextEvent == nil ? 0.0 : 0.05))

                            if startsSoon {
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        animatedClassColor.opacity(0.03),
                                        animatedClassColor.opacity(0.10)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                )
                            }

                            if isLiveNow {
                                RadialGradient(
                                    colors: [
                                        animatedClassColor.opacity(0.10),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 180
                                )
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                )
                            }
                            if nextClassSweep {
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.22),
                                        Color.clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(width: 90)
                                .rotationEffect(.degrees(18))
                                .offset(x: nextClassSweep ? 220 : -220)
                                .blendMode(.plusLighter)
                                .animation(.easeInOut(duration: 0.9), value: nextClassSweep)
                                .clipShape(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                )
                            }
                            
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                animatedClassColor.opacity(
                                    nextEvent == nil
                                    ? 0.08
                                    : (isLiveNow ? 0.24 : (startsSoon ? 0.20 : 0.18))
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: animatedClassColor.opacity(
                    nextEvent == nil
                    ? 0.0
                    : (isLiveNow ? 0.16 : (startsSoon ? 0.10 : 0.10))
                ),
                radius: isLiveNow ? 14 : 10,
                x: 0,
                y: 4
            )
            .animation(.interactiveSpring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.25), value: nextEvent?.title)
            .animation(.interactiveSpring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.25), value: nextEvent?.startMinute)
            .animation(.interactiveSpring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.25), value: nextEventStatusText)
            .animation(.easeInOut(duration: 0.7), value: nextEvent?.colorHex)
            .scaleEffect(startsVerySoon ? (nextClassPulse ? 1.012 : 1.0) : 1.0)
            .shadow(
                color: animatedClassColor.opacity(
                    startsVerySoon
                    ? (nextClassPulse ? 0.22 : 0.12)
                    : 0.0
                ),
                radius: startsVerySoon ? (nextClassPulse ? 18 : 10) : 0,
                x: 0,
                y: 0
            )
            .animation(
                startsVerySoon
                ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                : .easeInOut(duration: 0.2),
                value: nextClassPulse
            )
            .onAppear {
                if startsVerySoon {
                    nextClassPulse = true
                }
            }
            .onChange(of: startsVerySoon) { _, newValue in
                nextClassPulse = newValue
            }
            .onChange(of: isLiveNow) { _, newValue in
                guard newValue else { return }

                nextClassSweep = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    nextClassSweep = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    nextClassSweep = false
                }
            }
        }
    var todayTasksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today Tasks")
                    .font(.headline)

                Spacer()

                Text("\(todayTasks.prefix(3).count) gösteriliyor")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if todayTasks.isEmpty {
                Text("Bugün için aktif task yok.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(todayTasks.prefix(3))) { task in
                    HStack(spacing: 10) {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)

                            if let due = task.dueDate {
                                Text(due, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                    )
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                quickActionButton(
                    title: "Add Task",
                    systemImage: "plus.circle.fill",
                    action: onAddTask
                )

                quickActionButton(
                    title: "Week",
                    systemImage: "calendar",
                    action: onOpenWeek
                )

                quickActionButton(
                    title: "Insights",
                    systemImage: "chart.bar.fill",
                    action: onOpenInsights
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    func quickActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)

                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }

    func miniBadge(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(tint.opacity(0.15)))
        .foregroundStyle(tint)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

// MARK: - Helpers
private extension HomeDashboardView {
    func currentMinuteOfDay() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    func weekdayIndexToday() -> Int {
        let w = Calendar.current.component(.weekday, from: Date())
        return (w + 5) % 7
    }

    func syncActiveFocusCountdown() {
        guard let timestamp =
            UserDefaults.standard.object(forKey: "focus_end_date") as? Double else {
            return
        }

        let savedEnd = Date(timeIntervalSince1970: timestamp)
        let remaining = max(0, Int(savedEnd.timeIntervalSinceNow.rounded(.down)))

        if remaining > 0 {
            activeFocusRemainingSeconds = remaining
            isFocusActive = true

            if let savedTotal =
                UserDefaults.standard.object(forKey: "focus_total_seconds") as? Int,
               savedTotal > 0 {
                activeFocusTotalSeconds = savedTotal
            }

            if let savedTitle =
                UserDefaults.standard.string(forKey: "focus_task_title"),
               !savedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                activeFocusTaskTitle = savedTitle
            }

        } else {
            UserDefaults.standard.removeObject(forKey: "focus_end_date")

            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                isFocusActive = false
                pulseActiveFocus = false
            }
        }
    }

    func stopActiveFocus() {
        UserDefaults.standard.removeObject(forKey: "focus_end_date")
        UserDefaults.standard.removeObject(forKey: "focus_total_seconds")
        UserDefaults.standard.removeObject(forKey: "focus_selected_minutes")
        UserDefaults.standard.removeObject(forKey: "focus_task_title")

        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            pulseActiveFocus = false
            isFocusActive = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            activeFocusTaskTitle = ""
            activeFocusRemainingSeconds = 25 * 60
            activeFocusTotalSeconds = 25 * 60
        }
    }

    func hm(_ minute: Int) -> String {
        let m = max(0, min(1439, minute))
        let h = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
    }
}
