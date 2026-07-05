//
//  InsightsDataDashboard.swift
//  DailyTodo
//
//  Clean, data-first Insights cards built from the user's own in-app data:
//    • Focus this week — total + 7-day chart + today/sessions/all-time.
//      Tapping it opens the full focus history.
//    • Tasks this week — completed count + 7-day chart.
//
//  Identity and exam planner live in InsightsView around these.
//

import SwiftUI

struct InsightsDataDashboard: View {
    let focusSessions: [FocusSessionRecord]
    let tasks: [DTTaskItem]
    var accent: Color = Color(arenaHex: AppArenaPalette.cyan)

    private let green = Color(arenaHex: AppArenaPalette.green)

    @State private var showFocusDetail = false

    var body: some View {
        VStack(spacing: 14) {
            focusHeroCard
                .insightsCardReveal()

            if let hours = productiveHours {
                productiveHoursCard(hours)
                    .insightsCardReveal()
            }

            tasksCard
                .insightsCardReveal()
        }
        .sheet(isPresented: $showFocusDetail) {
            InsightsFocusHistorySheet(sessions: focusSessions, accent: accent)
        }
    }

    // MARK: - Derived focus data

    private var completedSessions: [FocusSessionRecord] {
        focusSessions.filter { $0.countsTowardStats }
    }

    private func focusMinutes(on day: Date) -> Int {
        let cal = Calendar.current
        return completedSessions
            .filter { cal.isDate($0.endedAt, inSameDayAs: day) }
            .reduce(0) { $0 + $1.completedSeconds } / 60
    }

    private var last7Days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { cal.date(byAdding: .day, value: -$0, to: today) ?? today }
    }

    private var todayMinutes: Int { focusMinutes(on: Date()) }
    private var weekMinutes: Int { last7Days.reduce(0) { $0 + focusMinutes(on: $1) } }
    private var totalMinutes: Int { completedSessions.reduce(0) { $0 + $1.completedSeconds } / 60 }
    private var totalSessions: Int { completedSessions.count }

    /// Minutes in the 7 days before the current 7-day window (for the delta).
    private var prevWeekMinutes: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let windowEnd = cal.date(byAdding: .day, value: -6, to: today),
              let windowStart = cal.date(byAdding: .day, value: -13, to: today)
        else { return 0 }

        return completedSessions
            .filter { $0.endedAt >= windowStart && $0.endedAt < windowEnd }
            .reduce(0) { $0 + $1.completedSeconds } / 60
    }

    /// "+42%" vs last week — nil when there is no previous week to compare.
    private var weekDelta: (text: String, isUp: Bool)? {
        guard prevWeekMinutes > 0, weekMinutes != prevWeekMinutes else { return nil }
        let pct = Int((Double(weekMinutes - prevWeekMinutes) / Double(prevWeekMinutes) * 100).rounded())
        guard pct != 0 else { return nil }
        return (String(format: "%+d%%", pct), pct > 0)
    }

    /// Hour-of-day focus distribution over the last 30 days. Nil until there
    /// are ≥ 5 sessions — an honest hide beats a noisy guess.
    private var productiveHours: (byHour: [Int], peakHour: Int)? {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -30, to: Date()) else { return nil }

        let recent = completedSessions.filter { $0.startedAt >= cutoff }
        guard recent.count >= 5 else { return nil }

        var byHour = Array(repeating: 0, count: 24)
        for session in recent {
            byHour[cal.component(.hour, from: session.startedAt)] += session.completedSeconds / 60
        }

        guard let peak = byHour.enumerated().max(by: { $0.element < $1.element }),
              peak.element > 0 else { return nil }
        return (byHour, peak.offset)
    }

    // MARK: - Derived task data

    private func tasksCompleted(on day: Date) -> Int {
        let cal = Calendar.current
        return tasks.filter { t in
            guard t.isDone, let done = t.completedAt else { return false }
            return cal.isDate(done, inSameDayAs: day)
        }.count
    }

    private var tasksThisWeek: Int { last7Days.reduce(0) { $0 + tasksCompleted(on: $1) } }

    // MARK: - Focus hero (tappable)

    private var focusHeroCard: some View {
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
                                Text(durationText(weekMinutes))
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(.white)
                                    .monospacedDigit()

                                if let delta = weekDelta {
                                    weekDeltaPill(delta)
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.35))
                    }

                    barChart(values: last7Days.map { focusMinutes(on: $0) }, tint: accent)

                    HStack(spacing: 0) {
                        heroStat(value: durationText(todayMinutes), label: tr("insd_today"))
                        statDivider
                        heroStat(value: "\(totalSessions)", label: tr("insd_sessions_label"))
                        statDivider
                        heroStat(value: durationText(totalMinutes), label: tr("insd_total"))
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// "+42%" — how this 7-day window compares to the previous one.
    private func weekDeltaPill(_ delta: (text: String, isUp: Bool)) -> some View {
        HStack(spacing: 3) {
            Image(systemName: delta.isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .black))
            Text(delta.text)
                .font(.system(size: 11, weight: .bold))
                .monospacedDigit()
        }
        .foregroundStyle(delta.isUp ? green : Color.white.opacity(0.5))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(delta.isUp ? green.opacity(0.13) : Color.white.opacity(0.06))
        )
    }

    // MARK: - Productive hours (last 30 days, real sessions only)

    private func productiveHoursCard(_ hours: (byHour: [Int], peakHour: Int)) -> some View {
        let maxValue = max(hours.byHour.max() ?? 0, 1)

        return InsightsGlassCard(tint: accent) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(tr("insd_hours_caps"))
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(accent.opacity(0.92))

                    Text(tr("insd_hours_peak", hours.peakHour))
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }

                VStack(spacing: 6) {
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(0..<24, id: \.self) { hour in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(
                                    hour == hours.peakHour
                                    ? AnyShapeStyle(accent)
                                    : AnyShapeStyle(accent.opacity(hours.byHour[hour] == 0 ? 0.10 : 0.45))
                                )
                                .frame(height: max(4, 42 * CGFloat(hours.byHour[hour]) / CGFloat(maxValue)))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 42, alignment: .bottom)

                    HStack {
                        Text("00")
                        Spacer()
                        Text("06")
                        Spacer()
                        Text("12")
                        Spacer()
                        Text("18")
                        Spacer()
                        Text("24")
                    }
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
    }

    // MARK: - Tasks card

    private var tasksCard: some View {
        InsightsGlassCard(tint: green) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(tr("insd_tasks_caps"))
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .tracking(1.6)
                            .foregroundStyle(green.opacity(0.92))
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(tasksThisWeek)")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            Text(tr("insd_completed_label"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(green)
                }

                barChart(values: last7Days.map { tasksCompleted(on: $0) }, tint: green)
            }
        }
    }

    // MARK: - Shared bar chart

    private func barChart(values: [Int], tint: Color) -> some View {
        let maxValue = max(values.max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(zip(last7Days, values).enumerated()), id: \.offset) { _, pair in
                let (day, value) = pair
                VStack(spacing: 7) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 60)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(LinearGradient(colors: [tint, tint.opacity(0.55)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(height: max(value == 0 ? 0 : 6, 60 * CGFloat(value) / CGFloat(maxValue)))
                    }
                    Text(weekdayLetter(day))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(isToday(day) ? 0.9 : 0.4))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 26)
    }

    // MARK: - Formatting

    private func durationText(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) \(tr("insd_min"))" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h)\(tr("insd_h"))" : "\(h)\(tr("insd_h")) \(m)\(tr("insd_min"))"
    }

    private func isToday(_ date: Date) -> Bool { Calendar.current.isDateInToday(date) }

    private func weekdayLetter(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: appLanguageIsEnglish() ? "en" : "tr")
        f.dateFormat = "EEEEE"
        return f.string(from: date).uppercased()
    }
}

// MARK: - Focus history sheet

struct InsightsFocusHistorySheet: View {
    let sessions: [FocusSessionRecord]
    var accent: Color = Color(arenaHex: AppArenaPalette.cyan)

    @Environment(\.dismiss) private var dismiss

    private var completed: [FocusSessionRecord] {
        sessions
            .filter { $0.countsTowardStats }
            .sorted { $0.endedAt > $1.endedAt }
    }

    private var totalMinutes: Int { completed.reduce(0) { $0 + $1.completedSeconds } / 60 }
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
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var summaryCard: some View {
        InsightsGlassCard(tint: accent) {
            HStack(spacing: 0) {
                stat(value: durationText(totalMinutes), label: tr("insd_total"))
                divider
                stat(value: "\(count)", label: tr("insd_sessions_label"))
                divider
                stat(value: durationText(avgMinutes), label: tr("insd_avg"))
            }
        }
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
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 10) {
                        ForEach(completed.prefix(40)) { session in
                            row(session)
                        }
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
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(dateText(session.endedAt))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
            }
            Spacer(minLength: 6)
            Text(durationText(mins))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
                .monospacedDigit()
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundStyle(.white).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.08)).frame(width: 1, height: 30)
    }

    private func durationText(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) \(tr("insd_min"))" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h)\(tr("insd_h"))" : "\(h)\(tr("insd_h")) \(m)\(tr("insd_min"))"
    }

    private func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: appLanguageIsEnglish() ? "en" : "tr")
        f.dateFormat = "d MMM · HH:mm"
        return f.string(from: date)
    }
}
