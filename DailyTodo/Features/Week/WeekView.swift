//
//  WeekView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData
import UIKit
import Combine

enum WeekMode {
    case personal
    case crew
}

enum PlanAheadMode: String, CaseIterable {
    case personal = "Personal"
    case crew = "Crew"
}

struct WeekView: View {

    @Environment(\.modelContext) var context
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var store: TodoStore
    @EnvironmentObject var friendStore: FriendStore
    @Environment(\.locale)  var locale

    @Query(sort: \EventItem.startMinute, order: .forward)
     var allEvents: [EventItem]

    @Query var tasks: [DTTaskItem]
    @Query var workoutExercises: [WorkoutExerciseItem]

    var allCrews: [WeekCrewItem] {
        crewStore.crews.map {
            WeekCrewItem(
                id: $0.id,
                name: $0.name,
                icon: $0.icon,
                colorHex: $0.color_hex
            )
        }
    }

    var allCrewTasks: [WeekCrewTaskItem] {
        crewStore.crewTasks.map { task in
            let assignedProfile = crewStore.memberProfiles.first(where: { $0.id == task.assigned_to })
            let creatorProfile = crewStore.memberProfiles.first(where: { $0.id == task.created_by })

            let assignedName: String = {
                guard let assignedProfile else { return "Unassigned" }

                if let fullName = assignedProfile.full_name,
                   !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return fullName
                }

                if let username = assignedProfile.username,
                   !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return username
                }

                return "Unassigned"
            }()

            let createdByName =
                creatorProfile?.full_name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                ? creatorProfile!.full_name!
                : (creatorProfile?.username ?? creatorProfile?.email ?? "Unknown")

            return WeekCrewTaskItem(
                id: task.id,
                crewID: task.crew_id,
                title: task.title,
                details: task.details ?? "",
                assignedTo: assignedName,
                createdBy: createdByName,
                priority: task.priority,
                status: task.is_done ? "done" : task.status,
                showOnWeek: task.show_on_week,
                scheduledWeekday: task.scheduled_weekday,
                scheduledStartMinute: task.scheduled_start_minute,
                scheduledDurationMinute: task.scheduled_duration_minute,
                scheduledDate: nil,
                isDone: task.is_done,
                createdAt: isoDate(task.created_at) ?? Date()
            )
        }
    }

    var allCrewActivities: [WeekCrewActivityItem] {
        crewStore.crewActivities.map {
            WeekCrewActivityItem(
                id: $0.id,
                crewID: $0.crew_id,
                memberName: $0.member_name,
                actionText: $0.action_text,
                createdAt: isoDate($0.created_at) ?? Date()
            )
        }
    }

    var crewMap: [UUID: WeekCrewItem] {
        Dictionary(uniqueKeysWithValues: allCrews.map { ($0.id, $0) })
    }

    var currentUserID: UUID? {
        session.currentUser?.id
    }

    var userScopedEvents: [EventItem] {
        guard let currentUserID else { return [] }
        return allEvents.filter { $0.ownerUserID == currentUserID.uuidString }
    }

    var userScopedTasks: [DTTaskItem] {
        store.items
    }

    var allEventsAccessible: [EventItem] {
        userScopedEvents
    }

    var selectedCrew: WeekCrewItem? {
        guard let selectedCrewID else { return nil }
        return allCrews.first(where: { $0.id == selectedCrewID })
    }

    let liveTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    let dayTitles = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]

    var allEventIDs: [UUID] { userScopedEvents.map(\.id) }

    var eventsForDay: [EventItem] {
        let calendar = Calendar.current
        let targetDate = targetDateForSelectedDay()

        return userScopedEvents
            .filter { ev in
                guard !ev.isCompleted else { return false }

                if let scheduledDate = ev.scheduledDate {
                    return calendar.isDate(scheduledDate, inSameDayAs: targetDate)
                } else {
                    return ev.weekday == selectedDay
                }
            }
            .sorted { lhs, rhs in
                lhs.startMinute < rhs.startMinute
            }
    }

    var eventsForDayIDs: [UUID] { eventsForDay.map(\.id) }

    var totalMinutesForDay: Int {
        eventsForDay.reduce(0) { $0 + $1.durationMinute }
    }

    var firstEventOfDay: EventItem? {
        eventsForDay.first
    }

    var lastEventOfDay: EventItem? {
        eventsForDay.last
    }

    var isTodaySelected: Bool {
        selectedDay == weekdayIndexToday()
    }

    var liveEventForDay: EventItem? {
        guard isTodaySelected else { return nil }
        let now = currentMinuteOfDay()
        return eventsForDay.first(where: {
            now >= $0.startMinute && now < ($0.startMinute + $0.durationMinute)
        })
    }

    var currentTimeIndicatorText: String? {
        guard isTodaySelected else { return nil }

        let now = currentMinuteOfDay()

        if let live = eventsForDay.first(where: {
            now >= $0.startMinute && now < ($0.startMinute + $0.durationMinute)
        }) {
            let left = max(0, (live.startMinute + live.durationMinute) - now)
            return localizedCurrentTimeLive(now: now, title: live.title, minutesLeft: left)
        }

        if let next = eventsForDay.first(where: { $0.startMinute > now }) {
            return localizedCurrentTimeNext(now: now, nextStart: next.startMinute)
        }

        if !eventsForDay.isEmpty {
            return localizedCurrentTimeFinished(now: now)
        }

        return nil
    }

    @State var selectedDay: Int = 0
    @State var showingAdd: Bool = false
    @State var showingCreateCrewTask = false
    @State var showCrewPickerSheet = false
    @State var editingEvent: EventItem? = nil
    @State var weekMode: WeekMode = .personal
    @State var showCopied: Bool = false
    @State var crewPulse = false
    @State var commentPulse = false
    @State var selectedTaskForEdit: WeekCrewTaskItem?
    @State var selectedCrewTask: WeekCrewTaskItem?
    @State var selectedCrewForDetail: WeekCrewItem?
    @State var showCrewEntrance = false
    @State var showCrewTaskHeader = false
    @State var showCrewTaskCards = false
    @State var didAnimateCrewCards = false
    @State var didInitialAutoScroll: Bool = false
    @State var lastAutoScrollTargetID: UUID? = nil
    @State var didSetInitialDay: Bool = false
    @State var animateSummary = false
    @State var pulseTodayDot = false
    @State var showCompletedCrewTasks = false
    @State var showPersonalEntrance = false
    @State var showPersonalEventCards = false
    @State var crewScrollOffset: CGFloat = 0
    @State var personalScrollOffset: CGFloat = 0
    @State var scrollY: CGFloat = 0
    @State var selectedCrewID: UUID?
    @State var showPlanAheadSheet = false
    @State var planAheadDate: Date = Date()
    @State var planAheadMode: PlanAheadMode = .personal
    @State var selectedEventForDetail: EventItem?

    var body: some View {
        ZStack {
            AppBackground()
            weekMainContent
        }
    }
}

// MARK: - Main UI Extras
extension WeekView {

    var activeCrewTaskCount: Int {
        allCrewTasksForSelectedDay.filter { !$0.isDone }.count
    }

    var sectionCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
    }
}

// MARK: - Legacy Crew Mode
extension WeekView {

    func premiumCardFill(_ priority: String, active: Bool, soon: Bool) -> LinearGradient {
        let tint = premiumPriorityColor(priority)

        return LinearGradient(
            colors: [
                tint.opacity(priority == "urgent" ? 0.16 : (active ? 0.12 : 0.08)),
                Color.white.opacity(active ? 0.07 : 0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    func markWorkoutTaskDone(taskID: PersistentIdentifier) {
        guard let task = userScopedTasks.first(where: { $0.id == taskID }) else { return }
        task.isDone = true
        task.completedAt = Date()
    }

    func premiumBorderColor(_ priority: String, active: Bool, soon: Bool) -> Color {
        let tint = premiumPriorityColor(priority)

        if priority == "urgent" {
            return tint.opacity(active ? 0.65 : 0.42)
        }

        if active {
            return tint.opacity(0.50)
        }

        if soon {
            return tint.opacity(0.30)
        }

        return tint.opacity(0.18)
    }

    func premiumGlowColor(_ priority: String, active: Bool, soon: Bool) -> Color {
        let tint = premiumPriorityColor(priority)

        if priority == "urgent" {
            return tint.opacity(active ? 0.35 : 0.22)
        }

        if active {
            return tint.opacity(0.20)
        }

        if soon {
            return tint.opacity(0.10)
        }

        return .clear
    }

    func premiumPriorityBadge(_ priority: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            if priority == "urgent" {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.bold))
            }

            Text(priorityTitle(priority))
                .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(tint.opacity(0.16))
        )
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.28), lineWidth: 1)
        )
        .foregroundStyle(tint)
    }

    func premiumMetaPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
        )
        .foregroundStyle(tint)
    }

    func crewTimelineTaskCard(_ task: WeekCrewTaskItem, isLast: Bool) -> some View {
        let crew = allCrews.first { $0.id == task.crewID }
        let active = isTaskActive(task)
        let soon = isTaskStartingSoon(task)

        let tint = premiumPriorityColor(task.priority)
        let cardFill = premiumCardFill(task.priority, active: active, soon: soon)
        let border = premiumBorderColor(task.priority, active: active, soon: soon)
        let glow = premiumGlowColor(task.priority, active: active, soon: soon)

        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(tint)
                    .frame(
                        width: active ? 16 : (soon ? 13 : 11),
                        height: active ? 16 : (soon ? 13 : 11)
                    )
                    .shadow(color: glow, radius: active ? 14 : (soon ? 8 : 0))
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(active ? 0.30 : 0.10), lineWidth: 1)
                    )
                    .scaleEffect(active ? 1.15 : (soon ? 1.06 : 1.0))

                if !isLast {
                    LinearGradient(
                        colors: [
                            tint.opacity(active ? 0.55 : 0.22),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 6)
                }
            }
            .frame(width: 18)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    if let start = task.scheduledStartMinute {
                        HStack(spacing: 5) {
                            Image(systemName: "clock")
                            Text(hm(start))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(active ? tint : .secondary)
                    }

                    Spacer()

                    premiumPriorityBadge(task.priority, tint: tint)
                }

                Text(task.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if let crew {
                    HStack(spacing: 6) {
                        Image(systemName: "person.3.fill")
                        Text(crew.name)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    premiumMetaPill(
                        icon: "flag.fill",
                        text: statusTitle(task.status),
                        tint: .secondary
                    )

                    if !task.assignedTo.isEmpty {
                        premiumMetaPill(
                            icon: "person.fill",
                            text: task.assignedTo,
                            tint: tint.opacity(0.95)
                        )
                    }
                }

                if active {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)

                        Text("Active now")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                } else if soon {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)

                        Text("Starting soon")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(border, lineWidth: active ? 1.2 : 1)
            )
            .shadow(color: glow, radius: active ? 18 : (soon ? 10 : 0))
            .scaleEffect(active ? 1.015 : 1.0)
        }
        .animation(.spring(duration: 0.28), value: active)
        .animation(.easeInOut(duration: 0.25), value: soon)
    }
}

// MARK: - Shared Time Helpers
extension WeekView {

    func currentMinuteOfDay() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    func isoDate(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: raw)
    }

    func timeText(for ev: EventItem) -> String {
        let start = ev.startMinute
        let end = ev.startMinute + ev.durationMinute
        return "\(hm(start)) – \(hm(end))"
    }

    func hm(_ minute: Int) -> String {
        let m = max(0, min(1439, minute))
        let h = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
    }

    func durationText(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60

        if h == 0 { return "\(m) dk" }
        if m == 0 { return "\(h) sa" }
        return "\(h) sa \(m) dk"
    }

    func weekdayIndexToday() -> Int {
        let w = Calendar.current.component(.weekday, from: Date())
        return (w + 5) % 7
    }

    func animateSummaryCard() {
        animateSummary = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            animateSummary = false
        }
    }
}

// MARK: - Logic
extension WeekView {

    func delete(_ ev: EventItem) {
        context.delete(ev)

        do {
            try context.save()
            WidgetAppSync.refreshFromSwiftData(context: context)

            Task {
                await NotificationManager.shared.rescheduleAll(
                    events: userScopedEvents.filter { $0.id != ev.id }
                )
            }

            Task {
                guard let currentUserID = session.currentUser?.id else { return }

                let descriptor = FetchDescriptor<EventItem>(
                    sortBy: [SortDescriptor(\EventItem.startMinute, order: .forward)]
                )

                let all = (try? context.fetch(descriptor)) ?? []
                let currentUserEvents = all.filter { $0.ownerUserID == currentUserID.uuidString }

                await friendStore.resyncSharedWeekIfNeeded(
                    for: currentUserID,
                    events: currentUserEvents
                )
            }
        } catch {
            print("WeekView.delete save error:", error)
        }
    }

    func hasConflict(_ ev: EventItem) -> Bool {
        for other in eventsForDay {
            if other.id == ev.id { continue }
            if overlaps(ev, other) { return true }
        }
        return false
    }

    func overlaps(_ a: EventItem, _ b: EventItem) -> Bool {
        let aStart = a.startMinute
        let aEnd = a.startMinute + a.durationMinute
        let bStart = b.startMinute
        let bEnd = b.startMinute + b.durationMinute
        return max(aStart, bStart) < min(aEnd, bEnd)
    }

    func autoScrollTarget(now: Int) -> EventItem? {
        guard !eventsForDay.isEmpty else { return nil }

        if selectedDay == weekdayIndexToday() {
            if let live = eventsForDay.first(where: { ev in
                let s = ev.startMinute
                let e = ev.startMinute + ev.durationMinute
                return now >= s && now < e
            }) {
                return live
            }

            if let next = eventsForDay.first(where: { $0.startMinute > now }) {
                return next
            }
        }

        return eventsForDay.first
    }

    func autoScrollIfNeeded(proxy: ScrollViewProxy) {
        let now = currentMinuteOfDay()
        guard let target = autoScrollTarget(now: now) else { return }

        if lastAutoScrollTargetID == target.id { return }
        lastAutoScrollTargetID = target.id

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(target.id, anchor: .center)
            }
        }
    }
}

// MARK: - Share
extension WeekView {

    func shareDay() {
        presentShare(text: shareTextForSelectedDay())
    }

    func targetDateForSelectedDay() -> Date {
        targetDateFor(day: selectedDay)
    }

    func mondayStartOfCurrentWeek() -> Date {
        let calendar = Calendar.current
        let today = Date()

        let weekday = calendar.component(.weekday, from: today)
        let mondayOffset = (weekday + 5) % 7

        let startOfToday = calendar.startOfDay(for: today)
        return calendar.date(byAdding: .day, value: -mondayOffset, to: startOfToday) ?? startOfToday
    }

    func shareWeek() {
        let parts: [String] = (0..<7).map { day in shareTextForDay(day) }
        presentShare(text: parts.joined(separator: "\n\n"))
    }

    func presentShare(text: String) {
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(vc, animated: true)
        }
    }

    func shareCrewDay() {
        presentShare(text: shareTextForCrewDay())
    }

    func shareSelectedCrew() {
        presentShare(text: shareTextForSelectedCrew())
    }

    func shareTextForCrewDay() -> String {
        let tasks = allCrewTasksForSelectedDay

        if tasks.isEmpty {
            return localizedShareEmptyCrewPlan(dayName: localizedDayTitle(selectedDay))
        }

        let lines = tasks.map { task in
            let timeText: String
            if let start = task.scheduledStartMinute {
                timeText = hm(start)
            } else {
                timeText = "--:--"
            }

            let assigneeText = task.assignedTo.isEmpty ? "" : " • \(task.assignedTo)"
            let crewNameText = crewMap[task.crewID]?.name ?? String(localized: "week_crew_fallback")

            return "• \(timeText)  \(task.title) • \(crewNameText)\(assigneeText)"
        }

        return """
        👥 \(localizedDayTitle(selectedDay)) \(String(localized: "week_share_crew_plan_title"))

        \(lines.joined(separator: "\n"))

        \(localizedDailyTodoFooter())
        """
    }

    func shareTextForSelectedCrew() -> String {
        if let crew = selectedCrew {
            if locale.language.languageCode?.identifier == "tr" {
                return "DailyTodo'da '\(crew.name)' crew'üme katıl 🚀"
            } else {
                return "Join my crew '\(crew.name)' on DailyTodo 🚀"
            }
        }

        if locale.language.languageCode?.identifier == "tr" {
            return "DailyTodo'da crew'üme katıl 🚀"
        } else {
            return "Join my crew on DailyTodo 🚀"
        }
    }

    func shareTextForSelectedDay() -> String {
        shareTextForDay(selectedDay)
    }

    func priorityTitle(_ value: String) -> String {
        let isTR = locale.language.languageCode?.identifier == "tr"

        switch value {
        case "low": return isTR ? "Düşük" : "Low"
        case "medium": return isTR ? "Orta" : "Medium"
        case "high": return isTR ? "Yüksek" : "High"
        case "urgent": return isTR ? "Acil" : "Urgent"
        default: return value.capitalized
        }
    }

    func statusTitle(_ value: String) -> String {
        let isTR = locale.language.languageCode?.identifier == "tr"

        switch value {
        case "todo": return isTR ? "Yapılacak" : "Todo"
        case "inProgress": return isTR ? "Devam Ediyor" : "In Progress"
        case "review": return isTR ? "İncelemede" : "Review"
        case "done": return isTR ? "Tamamlandı" : "Done"
        default: return value.capitalized
        }
    }

    func shareTextForDay(_ day: Int) -> String {
        let d = max(0, min(6, day))
        let dayName = localizedDayTitle(d)

        let calendar = Calendar.current
        let targetDate = targetDateFor(day: d)

        let items = userScopedEvents
            .filter { ev in
                if let scheduledDate = ev.scheduledDate {
                    return calendar.isDate(scheduledDate, inSameDayAs: targetDate)
                } else {
                    return ev.weekday == d
                }
            }
            .sorted { $0.startMinute < $1.startMinute }

        if items.isEmpty {
            return localizedShareEmptyDay(dayName: dayName)
        }

        let lines = items.map { ev in
            let start = hm(ev.startMinute)
            let end = hm(ev.startMinute + ev.durationMinute)
            let loc = (ev.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let locText = loc.isEmpty ? "" : " • \(loc)"
            return "• \(start)–\(end)  \(ev.title)\(locText)"
        }

        return """
        📅 \(dayName) \(String(localized: "week_share_my_schedule"))

        \(lines.joined(separator: "\n"))

        \(localizedDailyTodoFooter())
        """
    }

    func showCopiedToast() {
        withAnimation { showCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { showCopied = false }
        }
    }
    func localizedDayTitle(_ day: Int) -> String {
        let safeDay = max(0, min(6, day))
        let isTR = locale.language.languageCode?.identifier == "tr"

        if isTR {
            switch safeDay {
            case 0: return "Pzt"
            case 1: return "Sal"
            case 2: return "Çar"
            case 3: return "Per"
            case 4: return "Cum"
            case 5: return "Cmt"
            default: return "Paz"
            }
        } else {
            switch safeDay {
            case 0: return "Mon"
            case 1: return "Tue"
            case 2: return "Wed"
            case 3: return "Thu"
            case 4: return "Fri"
            case 5: return "Sat"
            default: return "Sun"
            }
        }
    }
    func localizedCurrentTimeLive(now: Int, title: String, minutesLeft: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "Şu an \(hm(now)) • \(title) devam ediyor • \(minutesLeft) dk kaldı"
        } else {
            return "Now \(hm(now)) • \(title) is ongoing • \(minutesLeft) min left"
        }
    }

    func localizedCurrentTimeNext(now: Int, nextStart: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "Şu an \(hm(now)) • Sıradaki ders \(hm(nextStart))"
        } else {
            return "Now \(hm(now)) • Next class \(hm(nextStart))"
        }
    }

    func localizedCurrentTimeFinished(now: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "Şu an \(hm(now)) • Bugünkü dersler bitti"
        } else {
            return "Now \(hm(now)) • Today's classes are over"
        }
    }

    func localizedShareEmptyCrewPlan(dayName: String) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "👥 \(dayName) crew planı — görev yok"
        } else {
            return "👥 \(dayName) crew plan — no tasks"
        }
    }

    func localizedShareEmptyDay(dayName: String) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "📅 \(dayName) — Ders yok"
        } else {
            return "📅 \(dayName) — No classes"
        }
    }

    func localizedDailyTodoFooter() -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "(DailyTodo ile oluşturuldu)"
        } else {
            return "(Created with DailyTodo)"
        }
    }
}
