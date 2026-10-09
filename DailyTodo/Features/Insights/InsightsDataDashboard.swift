//
//  InsightsDataDashboard.swift
//  DailyTodo
//
//  Clean, data-first Insights cards built from the user's own in-app data:
//    • Focus, last 7 days — total + 7-day chart + today/sessions/all-time.
//      Tapping it opens the full focus history.
//    • Tasks, last 7 days — completed count + day dots.
//
//  Identity and exam planner live in InsightsView around these.
//

import SwiftUI
import Combine

// MARK: - Shared focus math
//
// The dashboard card and the history sheet both read from here, so the same
// question ("peak hour", "vs last week") can never get two different answers.

enum InsightsFocusMath {
    /// Peak hours need this many sessions in the window — an honest hide
    /// beats a noisy guess.
    static let peakHoursMinSessions = 5
    static let peakHoursWindowDays = 30

    /// Focus minutes per calendar day for the last `days` days (oldest → today),
    /// bucketed by the day a session ended. One pass over the sessions.
    static func dailyMinutes(_ sessions: [FocusSessionRecord], days: Int, now: Date = Date()) -> [(date: Date, minutes: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let dates = (0..<days).reversed().map { cal.date(byAdding: .day, value: -$0, to: today) ?? today }

        var indexByDay: [Date: Int] = [:]
        for (i, day) in dates.enumerated() { indexByDay[day] = i }

        var seconds = Array(repeating: 0, count: days)
        for session in sessions {
            if let i = indexByDay[cal.startOfDay(for: session.endedAt)] {
                seconds[i] += session.completedSeconds
            }
        }
        return zip(dates, seconds).map { (date: $0, minutes: $1 / 60) }
    }

    /// "+42" — percent change vs the previous window. Nil when there is no
    /// previous window to compare with (a "+100%" from zero says nothing).
    static func trendPercent(current: Int, previous: Int) -> Int? {
        guard previous > 0 else { return nil }
        let pct = Int((Double(current - previous) / Double(previous) * 100).rounded())
        return pct == 0 ? nil : pct
    }

    /// Hour-of-day focus over the last 30 days. Each session's minutes are
    /// spread over the clock hours it actually covered (a 21:30–22:15 run
    /// counts for both 21 and 22). Nil until there are enough sessions.
    static func peakHours(_ sessions: [FocusSessionRecord], now: Date = Date()) -> (byHour: [Int], peakHour: Int)? {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -peakHoursWindowDays, to: now) else { return nil }

        let recent = sessions.filter { $0.startedAt >= cutoff }
        guard recent.count >= peakHoursMinSessions else { return nil }

        var secondsByHour = Array(repeating: 0, count: 24)
        for session in recent {
            var cursor = session.startedAt
            var remaining = max(session.completedSeconds, 0)
            while remaining > 0 {
                let parts = cal.dateComponents([.hour, .minute, .second], from: cursor)
                let hour = parts.hour ?? 0
                let intoHour = (parts.minute ?? 0) * 60 + (parts.second ?? 0)
                let chunk = min(remaining, 3600 - intoHour)
                secondsByHour[hour] += chunk
                remaining -= chunk
                cursor = cursor.addingTimeInterval(TimeInterval(chunk))
            }
        }

        let byHour = secondsByHour.map { $0 / 60 }
        guard let peakMinutes = byHour.max(), peakMinutes > 0,
              let peakHour = byHour.firstIndex(of: peakMinutes) else { return nil }
        return (byHour, peakHour)
    }

    // MARK: Weekly goal (calendar week, Monday-based)

    private static var weekCalendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        return cal
    }

    /// Monday 00:00 of the week containing `now`.
    static func weekStart(_ now: Date = Date()) -> Date {
        weekCalendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? Calendar.current.startOfDay(for: now)
    }

    /// Days left in this week, today included (Sunday → 1).
    static func daysLeftInWeek(_ now: Date = Date()) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        guard let nextWeek = cal.date(byAdding: .day, value: 7, to: weekStart(now)) else { return 1 }
        return max(1, cal.dateComponents([.day], from: today, to: nextWeek).day ?? 1)
    }

    /// Focus minutes since Monday.
    static func thisWeekMinutes(_ sessions: [FocusSessionRecord], now: Date = Date()) -> Int {
        let start = weekStart(now)
        return sessions.filter { $0.endedAt >= start }.reduce(0) { $0 + $1.completedSeconds } / 60
    }

    static let goalStepMinutes = 30
    static let goalRange = 60...(40 * 60)
    static let defaultGoalMinutes = 5 * 60

    /// A goal that stretches the user a little: the average of their active
    /// weeks among the last 4 (+10%), rounded to 30 min. 5h with no history.
    static func suggestedWeeklyGoal(_ sessions: [FocusSessionRecord], now: Date = Date()) -> Int {
        let cal = Calendar.current
        let thisWeek = weekStart(now)
        var weekly: [Int] = []
        for back in 1...4 {
            guard let start = cal.date(byAdding: .day, value: -7 * back, to: thisWeek),
                  let end = cal.date(byAdding: .day, value: 7, to: start) else { continue }
            let minutes = sessions
                .filter { $0.endedAt >= start && $0.endedAt < end }
                .reduce(0) { $0 + $1.completedSeconds } / 60
            if minutes > 0 { weekly.append(minutes) }
        }
        guard !weekly.isEmpty else { return defaultGoalMinutes }

        let average = Double(weekly.reduce(0, +)) / Double(weekly.count)
        let stretched = Int((average * 1.1 / Double(goalStepMinutes)).rounded()) * goalStepMinutes
        return min(max(stretched, goalRange.lowerBound), goalRange.upperBound)
    }

    // MARK: Per-course split (last 7 days)

    struct CourseSlice: Identifiable {
        let name: String
        let minutes: Int
        let colorHex: String?
        let isOther: Bool
        var id: String { isOther ? "__other__" : name }
    }

    /// Minutes per course over the last 7 days, biggest first. Top four
    /// courses keep their own row; the rest plus untagged time is "Other".
    static func courseSplit(
        _ sessions: [FocusSessionRecord],
        courses: [InsightsCourseInfo],
        now: Date = Date()
    ) -> (slices: [CourseSlice], taggedMinutes: Int) {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) else { return ([], 0) }

        var secondsByCourse: [String: Int] = [:]
        var untaggedSeconds = 0
        for session in sessions where session.endedAt >= cutoff {
            if let course = session.courseName?.trimmingCharacters(in: .whitespacesAndNewlines), !course.isEmpty {
                secondsByCourse[course, default: 0] += session.completedSeconds
            } else {
                untaggedSeconds += session.completedSeconds
            }
        }

        let ranked = secondsByCourse
            .map { (name: $0.key, minutes: $0.value / 60) }
            .filter { $0.minutes > 0 }
            .sorted { $0.minutes > $1.minutes }
        let tagged = ranked.reduce(0) { $0 + $1.minutes }

        var slices = ranked.prefix(4).map { entry in
            CourseSlice(
                name: entry.name,
                minutes: entry.minutes,
                colorHex: courses.first { $0.name.caseInsensitiveCompare(entry.name) == .orderedSame }?.colorHex,
                isOther: false
            )
        }
        let otherMinutes = ranked.dropFirst(4).reduce(0) { $0 + $1.minutes } + untaggedSeconds / 60
        if otherMinutes > 0, !slices.isEmpty {
            slices.append(CourseSlice(name: tr("insd_courses_other"), minutes: otherMinutes, colorHex: nil, isOther: true))
        }
        return (slices, tagged)
    }

    /// The nearest exam (within 3 weeks) whose course got no focus in the
    /// last 7 days. Only once course tagging has been in use for a week —
    /// before that, "no focus" may just mean "not tagged yet".
    static func neglectedExamCourse(
        _ sessions: [FocusSessionRecord],
        exams: [InsightsExamInfo],
        now: Date = Date()
    ) -> (course: String, daysLeft: Int)? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        guard let weekAgo = cal.date(byAdding: .day, value: -7, to: now) else { return nil }

        let tagged = sessions.filter { !($0.courseName ?? "").isEmpty }
        guard let firstTagged = tagged.map(\.endedAt).min(), firstTagged <= weekAgo else { return nil }

        let recentCourses = Set(
            tagged.filter { $0.endedAt >= weekAgo }.compactMap { $0.courseName?.lowercased() }
        )

        return exams
            .compactMap { exam -> (course: String, daysLeft: Int)? in
                let course = exam.courseName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !course.isEmpty,
                      let days = cal.dateComponents([.day], from: today, to: cal.startOfDay(for: exam.date)).day,
                      (1...21).contains(days),
                      !recentCourses.contains(course.lowercased()) else { return nil }
                return (course, days)
            }
            .min { $0.daysLeft < $1.daysLeft }
    }

    // MARK: Weekly summary (local, zero tokens)

    /// Two or three plain sentences about the last 7 days, most useful first.
    /// Every sentence is backed by the same numbers the cards show.
    static func weeklySummary(
        week: [(date: Date, minutes: Int)],
        trend: Int?,
        peakHour: Int?,
        tasksDone: Int
    ) -> [String] {
        let total = week.reduce(0) { $0 + $1.minutes }
        let activeDays = week.filter { $0.minutes > 0 }.count

        guard total > 0 else {
            var lines = [tr("insd_sum_none")]
            if tasksDone > 0 { lines.append(tasksSentence(tasksDone)) }
            return lines
        }

        var lines: [String] = []

        if let trend, trend > 0 {
            lines.append(tr("insd_sum_up", durationText(total), trend))
        } else if let trend, trend < 0 {
            lines.append(tr("insd_sum_down", durationText(total), -trend))
        } else {
            lines.append(tr("insd_sum_total", durationText(total)))
        }

        if activeDays >= 2, let best = week.max(by: { $0.minutes < $1.minutes }) {
            lines.append(tr("insd_sum_best_day", weekdayName(best.date), durationText(best.minutes)))
        } else {
            lines.append(tr("insd_sum_days", activeDays))
        }

        if let peakHour {
            lines.append(tr("insd_sum_peak", peakHour))
        } else if activeDays >= 2 {
            lines.append(tr("insd_sum_days", activeDays))
        } else if tasksDone > 0 {
            lines.append(tasksSentence(tasksDone))
        }

        return Array(lines.prefix(3))
    }

    private static func tasksSentence(_ count: Int) -> String {
        count == 1 ? tr("insd_sum_tasks_one") : tr("insd_sum_tasks", count)
    }

    /// "Salı" / "Tuesday"
    static func weekdayName(_ date: Date) -> String {
        let cal = appLanguageIsEnglish() ? enCalendar : trCalendar
        let symbols = cal.standaloneWeekdaySymbols
        let index = Calendar.current.component(.weekday, from: date) - 1
        return symbols.indices.contains(index) ? symbols[index].capitalized(with: cal.locale) : ""
    }

    // MARK: Formatting

    static func durationText(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) \(tr("insd_min"))" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h)\(tr("insd_h"))" : "\(h)\(tr("insd_h")) \(m)\(tr("insd_min"))"
    }

    private static let trCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "tr")
        return cal
    }()

    private static let enCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en")
        return cal
    }()

    // Two letters, Sunday-first (Calendar weekday order). One-letter symbols
    // are ambiguous — Turkish has three "P" days, English two "T" and "S".
    private static let trWeekdayShort = ["Pz", "Pt", "Sa", "Ça", "Pe", "Cu", "Ct"]
    private static let enWeekdayShort = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    /// "Pt", "Sa", "Ça"… — unambiguous day labels for the 7-day strips.
    static func weekdayLetter(_ date: Date) -> String {
        let symbols = appLanguageIsEnglish() ? enWeekdayShort : trWeekdayShort
        let index = Calendar.current.component(.weekday, from: date) - 1
        return symbols.indices.contains(index) ? symbols[index] : ""
    }

    private static let trSessionDateFormatter = sessionDateFormatter("tr")
    private static let enSessionDateFormatter = sessionDateFormatter("en")

    private static func sessionDateFormatter(_ locale: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: locale)
        f.dateFormat = "d MMM · HH:mm"
        return f
    }

    /// "9 Eki · 21:40"
    static func sessionDateText(_ date: Date) -> String {
        (appLanguageIsEnglish() ? enSessionDateFormatter : trSessionDateFormatter).string(from: date)
    }
}

// MARK: - Course / exam context (value types — cheap to compare)

struct InsightsCourseInfo: Equatable {
    let name: String
    let colorHex: String
}

struct InsightsExamInfo: Equatable {
    let courseName: String
    let date: Date
}

// MARK: - Redraw signature
//
// InsightsView re-renders on every scroll frame (the hero collapse reads the
// offset). Wrapping the analytics in an Equatable view keyed by this cheap
// signature means scroll frames skip the dashboard entirely, while any real
// change (a session saved or extended, a task closed, a new day) still redraws.

struct InsightsDataSignature: Equatable {
    let focusCount: Int
    let focusSeconds: Int
    let lastFocusEnd: Date?
    let doneTaskCount: Int
    let lastTaskDone: Date?
    let friendCount: Int
    let courses: [InsightsCourseInfo]
    let exams: [InsightsExamInfo]
    let taggedCount: Int
    let day: Date
    let isEnglish: Bool

    init(
        focusSessions: [FocusSessionRecord],
        tasks: [DTTaskItem],
        friends: [Friend],
        courses: [InsightsCourseInfo] = [],
        exams: [InsightsExamInfo] = []
    ) {
        var seconds = 0
        var lastEnd: Date?
        var tagged = 0
        for session in focusSessions {
            seconds += session.completedSeconds
            if !(session.courseName ?? "").isEmpty { tagged += 1 }
            if lastEnd == nil || session.endedAt > lastEnd! { lastEnd = session.endedAt }
        }

        var done = 0
        var lastDone: Date?
        for task in tasks where task.isDone {
            done += 1
            if let completed = task.completedAt, lastDone == nil || completed > lastDone! { lastDone = completed }
        }

        focusCount = focusSessions.count
        focusSeconds = seconds
        lastFocusEnd = lastEnd
        doneTaskCount = done
        lastTaskDone = lastDone
        friendCount = friends.count
        self.courses = courses
        self.exams = exams
        taggedCount = tagged
        day = Calendar.current.startOfDay(for: Date())
        isEnglish = appLanguageIsEnglish()
    }
}

// MARK: - Weekly focus goal store
//
// Device-local, per account (same model as the crew weekly goal). Nil means
// the user never picked one — the card then runs on the suggested goal.

@MainActor
final class FocusGoalStore: ObservableObject {
    static let shared = FocusGoalStore()

    @Published private(set) var revision = 0

    private func key(_ ownerID: String?) -> String {
        "updo.focusWeeklyGoalMinutes.\(ownerID ?? "local")"
    }

    func goalMinutes(for ownerID: String?) -> Int? {
        let value = UserDefaults.standard.integer(forKey: key(ownerID))
        return value > 0 ? value : nil
    }

    func setGoal(_ minutes: Int, for ownerID: String?) {
        let clamped = min(max(minutes, InsightsFocusMath.goalRange.lowerBound),
                          InsightsFocusMath.goalRange.upperBound)
        UserDefaults.standard.set(clamped, forKey: key(ownerID))
        revision += 1
    }
}

// MARK: - Dashboard

struct InsightsDataDashboard: View {
    let focusSessions: [FocusSessionRecord]
    let tasks: [DTTaskItem]
    var accent: Color = Color(arenaHex: AppArenaPalette.cyan)

    /// Account the weekly goal belongs to.
    var ownerID: String? = nil

    /// Active courses (colors) and upcoming exams for the per-course card.
    var courses: [InsightsCourseInfo] = []
    var exams: [InsightsExamInfo] = []

    // Comparison context for the focus detail sheet.
    var friends: [Friend] = []
    var myName: String = ""
    var myStreak: Int = 0
    var myLevel: Int = 1

    // When false (locked/blurred teaser) the per-card scroll-reveal is skipped
    // so the whole stack can be rasterized once — no per-frame blur churn.
    var revealOnScroll: Bool = true

    private let green = Color(arenaHex: AppArenaPalette.green)

    @State private var showFocusDetail = false
    @State private var showGoalEditor = false
    @ObservedObject private var goalStore = FocusGoalStore.shared

    /// Everything the cards show, computed in one pass per render.
    private struct Summary {
        let thisWeekMinutes: Int
        let suggestedGoal: Int
        let summaryLines: [String]
        let courseSlices: [InsightsFocusMath.CourseSlice]
        let courseTaggedMinutes: Int
        let neglected: (course: String, daysLeft: Int)?
        let week: [(date: Date, minutes: Int)]
        let weekMinutes: Int
        let todayMinutes: Int
        let trend: Int?
        let totalMinutes: Int
        let sessionCount: Int
        let peak: (byHour: [Int], peakHour: Int)?
        let taskDays: [(date: Date, count: Int)]
        let tasksThisWeek: Int
    }

    private var summary: Summary {
        let completed = focusSessions.filter { $0.countsTowardStats }
        let fortnight = InsightsFocusMath.dailyMinutes(completed, days: 14)
        let week = Array(fortnight.suffix(7))
        let weekMinutes = week.reduce(0) { $0 + $1.minutes }
        let prevMinutes = fortnight.prefix(7).reduce(0) { $0 + $1.minutes }

        let cal = Calendar.current
        var tasksByDay: [Date: Int] = [:]
        for task in tasks {
            guard task.isDone, let done = task.completedAt else { continue }
            tasksByDay[cal.startOfDay(for: done), default: 0] += 1
        }
        let taskDays = week.map { (date: $0.date, count: tasksByDay[$0.date] ?? 0) }
        let trend = InsightsFocusMath.trendPercent(current: weekMinutes, previous: prevMinutes)
        let peak = InsightsFocusMath.peakHours(completed)
        let tasksThisWeek = taskDays.reduce(0) { $0 + $1.count }
        let split = InsightsFocusMath.courseSplit(completed, courses: courses)

        return Summary(
            thisWeekMinutes: InsightsFocusMath.thisWeekMinutes(completed),
            suggestedGoal: InsightsFocusMath.suggestedWeeklyGoal(completed),
            summaryLines: InsightsFocusMath.weeklySummary(
                week: week,
                trend: trend,
                peakHour: peak?.peakHour,
                tasksDone: tasksThisWeek
            ),
            courseSlices: split.slices,
            courseTaggedMinutes: split.taggedMinutes,
            neglected: InsightsFocusMath.neglectedExamCourse(completed, exams: exams),
            week: week,
            weekMinutes: weekMinutes,
            todayMinutes: week.last?.minutes ?? 0,
            trend: trend,
            totalMinutes: completed.reduce(0) { $0 + $1.completedSeconds } / 60,
            sessionCount: completed.count,
            peak: peak,
            taskDays: taskDays,
            tasksThisWeek: tasksThisWeek
        )
    }

    var body: some View {
        let data = summary

        let savedGoal = goalStore.goalMinutes(for: ownerID)

        VStack(spacing: 14) {
            weeklySummaryCard(data.summaryLines)
                .insightsReveal(revealOnScroll)

            weeklyGoalCard(
                minutes: data.thisWeekMinutes,
                goal: savedGoal ?? data.suggestedGoal,
                isSuggested: savedGoal == nil
            )
            .insightsReveal(revealOnScroll)

            focusHeroCard(data)
                .insightsReveal(revealOnScroll)

            if data.courseTaggedMinutes > 0 || !courses.isEmpty || data.neglected != nil {
                coursesCard(data)
                    .insightsReveal(revealOnScroll)
            }

            tasksCard(data)
                .insightsReveal(revealOnScroll)
        }
        .sheet(isPresented: $showGoalEditor) {
            InsightsWeeklyGoalSheet(
                initialGoal: savedGoal ?? data.suggestedGoal,
                suggestedGoal: data.suggestedGoal,
                accent: accent
            ) { minutes in
                goalStore.setGoal(minutes, for: ownerID)
            }
        }
        .sheet(isPresented: $showFocusDetail) {
            InsightsFocusHistorySheet(
                sessions: focusSessions,
                accent: accent,
                friends: friends,
                myName: myName,
                myStreak: myStreak,
                myLevel: myLevel
            )
        }
    }

    // MARK: - Focus hero (tappable)

    private func focusHeroCard(_ data: Summary) -> some View {
        Button {
            HapticManager.shared.navigation()
            showFocusDetail = true
        } label: {
            InsightsGlassCard(tint: accent) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(tr("insd_focus_week_caps"))
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .tracking(1.6)
                                .foregroundStyle(accent.opacity(0.92))

                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(InsightsFocusMath.durationText(data.weekMinutes))
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(UpdoTheme.textPrimary)
                                    .monospacedDigit()

                                if let trend = data.trend {
                                    weekDeltaPill(trend)
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(UpdoTheme.filmy(0.35))
                    }

                    barChart(data.week, tint: accent)

                    HStack(spacing: 0) {
                        heroStat(value: InsightsFocusMath.durationText(data.todayMinutes), label: tr("insd_today"))
                        statDivider
                        heroStat(value: "\(data.sessionCount)", label: tr("insd_sessions_label"))
                        statDivider
                        heroStat(value: InsightsFocusMath.durationText(data.totalMinutes), label: tr("insd_total"))
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// "+42%" — how the last 7 days compare to the 7 before.
    private func weekDeltaPill(_ pct: Int) -> some View {
        let isUp = pct > 0
        return HStack(spacing: 3) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .black))
            Text(String(format: "%+d%%", pct))
                .font(.system(size: 11, weight: .bold))
                .monospacedDigit()
        }
        .foregroundStyle(isUp ? green : UpdoTheme.filmy(0.5))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isUp ? green.opacity(0.13) : UpdoTheme.filmy(0.06))
        )
    }

    // MARK: - Weekly summary (two or three sentences, local)

    private func weeklySummaryCard(_ lines: [String]) -> some View {
        InsightsGlassCard(tint: accent) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 10.5, weight: .bold))
                    Text(tr("insd_sum_caps"))
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .tracking(1.6)
                }
                .foregroundStyle(accent.opacity(0.92))

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line)
                            .font(.system(size: index == 0 ? 15.5 : 14, weight: index == 0 ? .semibold : .medium))
                            .foregroundStyle(UpdoTheme.filmy(index == 0 ? 0.92 : 0.66))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: - Weekly goal ring (this calendar week)

    private func weeklyGoalCard(minutes: Int, goal: Int, isSuggested: Bool) -> some View {
        let progress = goal > 0 ? min(Double(minutes) / Double(goal), 1) : 0
        let reached = minutes >= goal
        let ringColor = reached ? green : accent
        let remaining = max(goal - minutes, 0)
        let daysLeft = InsightsFocusMath.daysLeftInWeek()

        let paceText: String = {
            if reached { return tr("insd_goal_reached") }
            if daysLeft == 1 { return tr("insd_goal_last_day", InsightsFocusMath.durationText(remaining)) }
            let perDay = Int((Double(remaining) / Double(daysLeft)).rounded(.up))
            return tr("insd_goal_pace", daysLeft, InsightsFocusMath.durationText(perDay))
        }()

        return Button {
            HapticManager.shared.navigation()
            showGoalEditor = true
        } label: {
            InsightsGlassCard(tint: ringColor) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(UpdoTheme.filmy(0.08), lineWidth: 7)
                        Circle()
                            .trim(from: 0, to: max(progress, 0.001))
                            .stroke(
                                LinearGradient(colors: [ringColor, ringColor.opacity(0.6)],
                                               startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 7, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        if reached {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(green)
                        } else {
                            Text("\(Int((progress * 100).rounded(.down)))%")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(UpdoTheme.textPrimary)
                                .monospacedDigit()
                        }
                    }
                    .frame(width: 62, height: 62)
                    .animation(.easeOut(duration: 0.5), value: progress)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("insd_goal_caps"))
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(ringColor.opacity(0.92))

                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(InsightsFocusMath.durationText(minutes))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(UpdoTheme.textPrimary)
                                .monospacedDigit()
                            Text("/ \(InsightsFocusMath.durationText(goal))")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(UpdoTheme.filmy(0.5))
                                .monospacedDigit()
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                        Text(isSuggested ? tr("insd_goal_suggested_hint") : paceText)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(reached && !isSuggested ? green : UpdoTheme.filmy(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(UpdoTheme.filmy(0.35))
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Per-course split (last 7 days)

    private func courseColor(_ slice: InsightsFocusMath.CourseSlice, index: Int) -> Color {
        if slice.isOther { return UpdoTheme.filmy(0.22) }
        if let hex = slice.colorHex { return Color(arenaHex: hex) }
        let fallback = [AppArenaPalette.cyan, AppArenaPalette.purple, AppArenaPalette.gold, AppArenaPalette.green]
        return Color(arenaHex: fallback[index % fallback.count])
    }

    private func coursesCard(_ data: Summary) -> some View {
        let slices = data.courseSlices
        let total = max(slices.reduce(0) { $0 + $1.minutes }, 1)
        let coral = Color(arenaHex: AppArenaPalette.coral)

        return InsightsGlassCard(tint: accent) {
            VStack(alignment: .leading, spacing: 14) {
                Text(tr("insd_courses_caps"))
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(accent.opacity(0.92))

                if data.courseTaggedMinutes > 0 {
                    // One stacked bar: the whole week at a glance.
                    GeometryReader { geo in
                        HStack(spacing: 2) {
                            ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                                Rectangle()
                                    .fill(courseColor(slice, index: index))
                                    .frame(width: max(3, (geo.size.width - CGFloat(slices.count - 1) * 2) * CGFloat(slice.minutes) / CGFloat(total)))
                            }
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 10)

                    VStack(spacing: 10) {
                        ForEach(Array(slices.enumerated()), id: \.element.id) { index, slice in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(courseColor(slice, index: index))
                                    .frame(width: 9, height: 9)
                                Text(slice.name)
                                    .font(.system(size: 14, weight: slice.isOther ? .medium : .semibold))
                                    .foregroundStyle(UpdoTheme.filmy(slice.isOther ? 0.55 : 0.9))
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Text(InsightsFocusMath.durationText(slice.minutes))
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundStyle(UpdoTheme.textPrimary)
                                    .monospacedDigit()
                                Text("\(Int((Double(slice.minutes) / Double(total) * 100).rounded()))%")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(UpdoTheme.filmy(0.42))
                                    .monospacedDigit()
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                } else {
                    Text(tr("insd_courses_hint"))
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundStyle(UpdoTheme.filmy(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let neglected = data.neglected {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(coral)
                            .padding(.top, 1)
                        Text(neglected.daysLeft == 1
                             ? tr("insd_courses_neglect_tomorrow", neglected.course)
                             : tr("insd_courses_neglect", neglected.course, neglected.daysLeft))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(UpdoTheme.filmy(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(coral.opacity(0.12))
                    )
                }
            }
        }
    }

    // MARK: - Tasks card

    private func tasksCard(_ data: Summary) -> some View {
        // Compact: one number plus a quiet day-dot strip reads in a single glance.
        InsightsGlassCard(tint: green) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(green.opacity(0.14)).frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(green)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("insd_tasks_caps"))
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(green.opacity(0.92))

                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(data.tasksThisWeek)")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(UpdoTheme.textPrimary)
                            .monospacedDigit()
                        Text(tr("insd_completed_label"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(UpdoTheme.filmy(0.5))
                    }
                }

                Spacer(minLength: 10)

                taskDayDots(data.taskDays)
            }
        }
    }

    /// Seven small dots — filled when that day closed at least one task.
    private func taskDayDots(_ days: [(date: Date, count: Int)]) -> some View {
        HStack(spacing: 3) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 4) {
                    Circle()
                        .fill(day.count > 0 ? green : UpdoTheme.filmy(0.10))
                        .frame(width: 7, height: 7)
                    Text(InsightsFocusMath.weekdayLetter(day.date))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(UpdoTheme.filmy(isToday(day.date) ? 0.85 : 0.32))
                        .fixedSize()
                }
                .frame(width: 13)
            }
        }
    }

    // MARK: - 7-day bar chart

    private func barChart(_ days: [(date: Date, minutes: Int)], tint: Color) -> some View {
        let maxValue = max(days.map(\.minutes).max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 7) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(UpdoTheme.filmy(0.05))
                            .frame(height: 60)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(LinearGradient(colors: [tint, tint.opacity(0.55)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(height: max(day.minutes == 0 ? 0 : 6, 60 * CGFloat(day.minutes) / CGFloat(maxValue)))
                    }
                    Text(InsightsFocusMath.weekdayLetter(day.date))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(UpdoTheme.filmy(isToday(day.date) ? 0.9 : 0.4))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(UpdoTheme.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(UpdoTheme.filmy(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle().fill(UpdoTheme.filmy(0.08)).frame(width: 1, height: 26)
    }

    private func isToday(_ date: Date) -> Bool { Calendar.current.isDateInToday(date) }
}

// MARK: - Weekly goal editor

struct InsightsWeeklyGoalSheet: View {
    let initialGoal: Int
    let suggestedGoal: Int
    var accent: Color = Color(arenaHex: AppArenaPalette.cyan)
    let onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var goal: Int = InsightsFocusMath.defaultGoalMinutes

    private let presets = [3, 5, 10, 15, 20].map { $0 * 60 }
    private var step: Int { InsightsFocusMath.goalStepMinutes }
    private var range: ClosedRange<Int> { InsightsFocusMath.goalRange }

    var body: some View {
        VStack(spacing: 20) {
            Text(tr("insd_goal_sheet_title"))
                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(accent.opacity(0.92))
                .padding(.top, 22)

            HStack(spacing: 22) {
                stepButton("minus", enabled: goal > range.lowerBound) {
                    goal = max(goal - step, range.lowerBound)
                }

                Text(InsightsFocusMath.durationText(goal))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(UpdoTheme.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .frame(minWidth: 150)

                stepButton("plus", enabled: goal < range.upperBound) {
                    goal = min(goal + step, range.upperBound)
                }
            }

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        HapticManager.shared.subtle()
                        withAnimation(.snappy) { goal = preset }
                    } label: {
                        Text(InsightsFocusMath.durationText(preset))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(goal == preset ? Color.black.opacity(0.85) : UpdoTheme.filmy(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(goal == preset ? accent : UpdoTheme.filmy(0.07)))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                HapticManager.shared.subtle()
                withAnimation(.snappy) { goal = suggestedGoal }
            } label: {
                Text(tr("insd_goal_suggestion", InsightsFocusMath.durationText(suggestedGoal)))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UpdoTheme.filmy(goal == suggestedGoal ? 0.4 : 0.65))
                    .underline(goal != suggestedGoal)
            }
            .buttonStyle(.plain)
            .disabled(goal == suggestedGoal)

            Spacer(minLength: 0)

            Button {
                HapticManager.shared.success()
                onSave(goal)
                dismiss()
            } label: {
                Text(tr("insd_goal_save"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(accent))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .onAppear { goal = initialGoal }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
        .updoColorScheme()
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.subtle()
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(enabled ? UpdoTheme.textPrimary : UpdoTheme.filmy(0.25))
                .frame(width: 48, height: 48)
                .background(Circle().fill(UpdoTheme.filmy(0.07)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Focus history sheet

struct InsightsFocusHistorySheet: View {
    var accent: Color = Color(arenaHex: AppArenaPalette.cyan)
    var friends: [Friend] = []
    var myName: String = ""
    var myStreak: Int = 0
    var myLevel: Int = 1

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var socialStats = SocialStatsStore.shared
    @ObservedObject private var subscription = SubscriptionManager.shared

    @State private var showAllSessions = false

    /// Counted sessions, newest first — sorted once, not per card.
    private let completed: [FocusSessionRecord]
    private let totalMinutes: Int
    private let fortnight: [(date: Date, minutes: Int)]
    private let peak: (byHour: [Int], peakHour: Int)?

    private static let initialSessionRows = 40

    init(
        sessions: [FocusSessionRecord],
        accent: Color = Color(arenaHex: AppArenaPalette.cyan),
        friends: [Friend] = [],
        myName: String = "",
        myStreak: Int = 0,
        myLevel: Int = 1
    ) {
        self.accent = accent
        self.friends = friends
        self.myName = myName
        self.myStreak = myStreak
        self.myLevel = myLevel

        let counted = sessions.filter { $0.countsTowardStats }
        completed = counted.sorted { $0.endedAt > $1.endedAt }
        totalMinutes = counted.reduce(0) { $0 + $1.completedSeconds } / 60
        fortnight = InsightsFocusMath.dailyMinutes(counted, days: 14)
        peak = InsightsFocusMath.peakHours(counted)
    }

    private var count: Int { completed.count }
    private var avgMinutes: Int { count == 0 ? 0 : totalMinutes / count }

    var body: some View {
        NavigationStack {
            ZStack {
                ArenaBackground(
                    primaryGlow: accent,
                    secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
                    warmGlow: Color(arenaHex: AppArenaPalette.gold),
                    intensity: 0.85
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        summaryCard
                        dailyChartCard
                        peakHoursCard
                        friendCompareCard
                        sessionsCard
                        Color.clear.frame(height: 16)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationTitle(tr("insd_focus_detail_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(UpdoTheme.filmy(0.5))
                    }
                }
            }
            .updoColorScheme()
            .onAppear {
                let ids = friends.compactMap { $0.backendUserID }
                if !ids.isEmpty {
                    socialStats.refresh(userIDs: ids, isPro: subscription.isPro)
                }
            }
        }
    }

    private var summaryCard: some View {
        InsightsGlassCard(tint: accent) {
            HStack(spacing: 0) {
                stat(value: InsightsFocusMath.durationText(totalMinutes), label: tr("insd_total"))
                divider
                stat(value: "\(count)", label: tr("insd_sessions_label"))
                divider
                stat(value: InsightsFocusMath.durationText(avgMinutes), label: tr("insd_avg"))
            }
        }
    }

    // MARK: - Daily chart (last 14 days) + trend

    private var trend: Int? {
        InsightsFocusMath.trendPercent(
            current: fortnight.suffix(7).reduce(0) { $0 + $1.minutes },
            previous: fortnight.prefix(7).reduce(0) { $0 + $1.minutes }
        )
    }

    private var dailyChartCard: some View {
        let buckets = fortnight
        let maxV = max(buckets.map { $0.minutes }.max() ?? 0, 1)
        let cal = Calendar.current

        return InsightsGlassCard(tint: accent) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    cardHeader(tr("insd_last14_caps"))
                    Spacer()
                    if let pct = trend {
                        Text(String(format: "%+d%%", pct))
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(pct < 0 ? Color(arenaHex: AppArenaPalette.coral) : Color(arenaHex: AppArenaPalette.green))
                    }
                }

                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(buckets.enumerated()), id: \.offset) { i, b in
                        let isToday = cal.isDateInToday(b.date)
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(isToday
                                      ? AnyShapeStyle(LinearGradient(colors: [accent, Color(arenaHex: AppArenaPalette.purple)], startPoint: .top, endPoint: .bottom))
                                      : AnyShapeStyle(accent.opacity(b.minutes > 0 ? 0.45 : 0.10)))
                                .frame(maxWidth: .infinity)
                                .frame(height: 6 + CGFloat(Double(b.minutes) / Double(maxV)) * 78)
                            if i % 2 == 0 || isToday {
                                Text("\(cal.component(.day, from: b.date))")
                                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(UpdoTheme.filmy(isToday ? 0.75 : 0.3))
                            } else {
                                Text(" ").font(.system(size: 7.5))
                            }
                        }
                    }
                }
                .frame(height: 100, alignment: .bottom)
            }
        }
    }

    // MARK: - Peak hours (same rule as the dashboard card: last 30 days)

    private var peakHoursCard: some View {
        InsightsGlassCard(tint: accent) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    cardHeader(tr("insd_hours_caps"))
                    Spacer()
                    Text(tr("insd_hours_window"))
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(UpdoTheme.filmy(0.35))
                }

                if let peak {
                    Text(tr("insd_hours_peak", peak.peakHour))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(UpdoTheme.filmy(0.72))

                    hourHistogram(peak.byHour, peakHour: peak.peakHour)
                } else {
                    Text(tr("insd_hours_empty", InsightsFocusMath.peakHoursMinSessions))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(UpdoTheme.filmy(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func hourHistogram(_ byHour: [Int], peakHour: Int) -> some View {
        let maxV = max(byHour.max() ?? 0, 1)

        return VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<24, id: \.self) { h in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(h == peakHour
                              ? AnyShapeStyle(accent)
                              : AnyShapeStyle(accent.opacity(byHour[h] > 0 ? 0.35 : 0.08)))
                        .frame(maxWidth: .infinity)
                        .frame(height: 4 + CGFloat(Double(byHour[h]) / Double(maxV)) * 44)
                }
            }
            .frame(height: 48, alignment: .bottom)

            HStack {
                ForEach([0, 6, 12, 18], id: \.self) { h in
                    Text(String(format: "%02d", h))
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(UpdoTheme.filmy(0.3))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("24").font(.system(size: 7.5, weight: .bold, design: .monospaced)).foregroundStyle(UpdoTheme.filmy(0.3))
            }
        }
    }

    // MARK: - Friend comparison (leaderboard by all-time focus)

    private struct RankEntry: Identifiable {
        let id = UUID()
        let name: String
        let minutes: Int
        let streak: Int
        let level: Int
        let isMe: Bool
    }

    private var leaderboard: [RankEntry] {
        var entries: [RankEntry] = [
            RankEntry(name: myName.isEmpty ? tr("insd_you") : myName,
                      minutes: totalMinutes, streak: myStreak, level: myLevel, isMe: true)
        ]
        for f in friends {
            guard let uid = f.backendUserID,
                  let s = socialStats.stat(for: uid),
                  s.sharingEnabled else { continue }
            entries.append(RankEntry(name: f.name, minutes: s.totalFocusMinutes,
                                     streak: s.currentStreak, level: s.level, isMe: false))
        }
        return entries.sorted { $0.minutes > $1.minutes }
    }

    private var friendCompareCard: some View {
        let board = leaderboard
        let maxV = max(board.map { $0.minutes }.max() ?? 0, 1)
        let gold = Color(arenaHex: AppArenaPalette.gold)

        return InsightsGlassCard(tint: accent) {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader(tr("insd_vs_friends_caps"))

                if board.count <= 1 {
                    Text(tr("insd_vs_friends_empty"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(UpdoTheme.filmy(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    VStack(spacing: 9) {
                        ForEach(Array(board.prefix(6).enumerated()), id: \.element.id) { rank, e in
                            HStack(spacing: 10) {
                                Text("\(rank + 1)")
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundStyle(rank == 0 ? gold : UpdoTheme.filmy(0.4))
                                    .frame(width: 16)

                                Text(e.name)
                                    .font(.system(size: 13.5, weight: e.isMe ? .black : .semibold))
                                    .foregroundStyle(e.isMe ? accent : UpdoTheme.filmy(0.9))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                    .frame(width: 104, alignment: .leading)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(UpdoTheme.filmy(0.06)).frame(height: 8)
                                        Capsule()
                                            .fill(e.isMe
                                                  ? AnyShapeStyle(LinearGradient(colors: [accent, Color(arenaHex: AppArenaPalette.purple)], startPoint: .leading, endPoint: .trailing))
                                                  : AnyShapeStyle(UpdoTheme.filmy(0.22)))
                                            .frame(width: max(8, geo.size.width * CGFloat(Double(e.minutes) / Double(maxV))), height: 8)
                                    }
                                }
                                .frame(height: 8)

                                Text(InsightsFocusMath.durationText(e.minutes))
                                    .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                    .foregroundStyle(UpdoTheme.filmy(0.7))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(width: 56, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
    }

    private func cardHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
            .tracking(1.6)
            .foregroundStyle(accent.opacity(0.92))
    }

    // MARK: - All sessions

    private var visibleSessions: ArraySlice<FocusSessionRecord> {
        showAllSessions ? completed[...] : completed.prefix(Self.initialSessionRows)
    }

    private var sessionsCard: some View {
        InsightsGlassCard(tint: accent) {
            VStack(alignment: .leading, spacing: 14) {
                Text(tr("insd_all_sessions_caps"))
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(accent.opacity(0.92))

                if completed.isEmpty {
                    Text(tr("insd_empty"))
                        .font(.system(size: 13.5, weight: .regular))
                        .foregroundStyle(UpdoTheme.filmy(0.45))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(visibleSessions) { session in
                            row(session)
                        }
                    }

                    if !showAllSessions && completed.count > Self.initialSessionRows {
                        Button {
                            HapticManager.shared.navigation()
                            withAnimation(.easeOut(duration: 0.2)) { showAllSessions = true }
                        } label: {
                            Text(tr("insd_show_all", completed.count))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(accent.opacity(0.10))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func row(_ session: FocusSessionRecord) -> some View {
        let title = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let mins = session.completedSeconds / 60
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(accent.opacity(0.14)).frame(width: 34, height: 34)
                Image(systemName: "scope").font(.system(size: 13, weight: .bold)).foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title.isEmpty ? tr("insd_focus_untitled") : title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(UpdoTheme.textPrimary)
                    .lineLimit(1)
                Text(InsightsFocusMath.sessionDateText(session.endedAt))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(UpdoTheme.filmy(0.42))
            }
            Spacer(minLength: 6)
            Text(InsightsFocusMath.durationText(mins))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(UpdoTheme.filmy(0.8))
                .monospacedDigit()
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundStyle(UpdoTheme.textPrimary).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(UpdoTheme.filmy(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(UpdoTheme.filmy(0.08)).frame(width: 1, height: 30)
    }
}

// MARK: - Streak calendar (current month, real days only)
//
// One cell per day: filled = the day fed the streak (task AND focus),
// half ring = only one half done, hairline = nothing. Future days stay
// almost invisible. Same rule as StreakProgressEngine — no invented data.

struct InsightsStreakCalendarCard: View {
    let tasks: [DTTaskItem]
    let focusSessions: [FocusSessionRecord]
    var accent: Color = Color(arenaHex: AppArenaPalette.cyan)

    private let gold = Color(arenaHex: AppArenaPalette.gold)

    private var cal: Calendar { Calendar.current }
    private var today: Date { cal.startOfDay(for: Date()) }

    private var monthStart: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
    }

    private var daysInMonth: Int {
        cal.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }

    /// Empty cells before day 1 (Monday-based grid).
    private var leadingBlanks: Int {
        (cal.component(.weekday, from: monthStart) + 5) % 7
    }

    private enum DayState { case full, half, empty, future }

    private var dayStates: [DayState] {
        // Precompute day buckets once — the grid just looks them up.
        var taskDays = Set<Date>()
        for task in tasks {
            guard task.isDone, let done = task.completedAt else { continue }
            taskDays.insert(cal.startOfDay(for: done))
        }
        var focusDays = Set<Date>()
        for rec in focusSessions where rec.countsTowardStats {
            focusDays.insert(cal.startOfDay(for: rec.endedAt))
        }

        return (0..<daysInMonth).map { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: monthStart) else { return .empty }
            if day > today { return .future }
            let hasTask = taskDays.contains(day)
            let hasFocus = focusDays.contains(day)
            if hasTask && hasFocus { return .full }
            if hasTask || hasFocus { return .half }
            return .empty
        }
    }

    private var monthTitle: String {
        localizedMonthShort(cal.component(.month, from: today) - 1)
    }

    var body: some View {
        InsightsGlassCard(tint: gold) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(tr("insd_streak_cal_caps"))
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(gold.opacity(0.92))

                    Spacer()

                    Text(monthTitle)
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(UpdoTheme.filmy(0.4))
                }

                // Weekday letters (Monday-based).
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { idx in
                        Text(localizedWeekdayLetter(idx))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(UpdoTheme.filmy(0.32))
                            .frame(maxWidth: .infinity)
                    }
                }

                let states = dayStates
                let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

                LazyVGrid(columns: columns, spacing: 6) {
                    // The blank leading cells and the day cells live in ONE grid, so
                    // their ForEach ids must not collide. Blanks take ids
                    // 0..<leadingBlanks; days are offset to start AFTER the blanks
                    // (leadingBlanks..<leadingBlanks+daysInMonth) — otherwise both
                    // ranges start at 0 and SwiftUI warns "id used by multiple child
                    // views… undefined results" (garbled layout / crash).
                    ForEach(0..<leadingBlanks, id: \.self) { _ in
                        Color.clear.frame(height: 30)
                    }

                    ForEach(leadingBlanks..<(leadingBlanks + daysInMonth), id: \.self) { gridIndex in
                        let offset = gridIndex - leadingBlanks
                        dayCell(number: offset + 1, state: states[offset],
                                isToday: offset + 1 == cal.component(.day, from: today))
                    }
                }

                // Legend — one quiet line.
                HStack(spacing: 14) {
                    legendItem(fill: true, text: tr("insd_cal_full"))
                    legendItem(fill: false, text: tr("insd_cal_half"))
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(number: Int, state: DayState, isToday: Bool) -> some View {
        ZStack {
            switch state {
            case .full:
                Circle().fill(
                    LinearGradient(colors: [gold, accent],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            case .half:
                Circle().strokeBorder(gold.opacity(0.55), lineWidth: 1.5)
            case .empty:
                Circle().strokeBorder(UpdoTheme.filmy(0.09), lineWidth: 1)
            case .future:
                Circle().fill(UpdoTheme.filmy(0.025))
            }

            Text("\(number)")
                .font(.system(size: 11, weight: state == .full ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(
                    state == .full ? Color.black.opacity(0.85)
                    : state == .future ? UpdoTheme.filmy(0.18)
                    : UpdoTheme.filmy(0.6)
                )
        }
        .frame(height: 30)
        .overlay {
            if isToday {
                Circle().strokeBorder(UpdoTheme.filmy(0.55), lineWidth: 1.5)
            }
        }
    }

    private func legendItem(fill: Bool, text: String) -> some View {
        HStack(spacing: 5) {
            if fill {
                Circle()
                    .fill(LinearGradient(colors: [gold, accent],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 9, height: 9)
            } else {
                Circle()
                    .strokeBorder(gold.opacity(0.55), lineWidth: 1.5)
                    .frame(width: 9, height: 9)
            }

            Text(text)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(UpdoTheme.filmy(0.42))
        }
    }
}
