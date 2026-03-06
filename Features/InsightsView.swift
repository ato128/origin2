//
//  InsightsView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData
import Foundation

struct InsightsView: View {
    @EnvironmentObject var store: TodoStore

    @Query(sort: \EventItem.weekday, order: .forward)
    private var allEvents: [EventItem]

    @State private var animateFlame = false
    @State private var animateBars = false
    @State private var animateScoreRing = false
    @State private var displayedCompletionRate = 0
    @State private var didAnimate = false

    private var allTasks: [DTTaskItem] { store.items }

    private var weeklyCompletedData: [DayCount] {
        InsightsEngine.weeklyCompletedTasks(tasks: allTasks)
    }

    private var completedTodayCount: Int {
        InsightsEngine.completedTodayCount(tasks: allTasks)
    }

    private var totalTaskCount: Int {
        allTasks.count
    }

    private var activeTaskCount: Int {
        InsightsEngine.activeTaskCount(tasks: allTasks)
    }

    private var overdueTaskCount: Int {
        InsightsEngine.overdueTaskCount(tasks: allTasks)
    }

    private var completedTaskCount: Int {
        allTasks.filter(\.isDone).count
    }

    private var totalWeeklyMinutes: Int {
        InsightsEngine.totalWeeklyMinutes(events: allEvents)
    }

    private var busiestDay: (dayIndex: Int, minutes: Int) {
        InsightsEngine.busiestDay(events: allEvents)
    }

    private var completionRate: Int {
        InsightsEngine.completionRate(tasks: allTasks)
    }

    private var productivityScore: Int {
        InsightsEngine.productivityScore(tasks: allTasks)
    }

    private var currentStreak: Int {
        StreakEngine.currentStreak(tasks: allTasks)
    }

    private var maxWeeklyCompletedCount: Int {
        max(weeklyCompletedData.map(\.count).max() ?? 0, 1)
    }

    private var isEmptyState: Bool {
        allTasks.isEmpty
    }

    private var todayIndex: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())

        switch weekday {
        case 2: return 0 // Pzt
        case 3: return 1 // Sal
        case 4: return 2 // Çar
        case 5: return 3 // Per
        case 6: return 4 // Cum
        case 7: return 5 // Cmt
        case 1: return 6 // Paz
        default: return 0
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isEmptyState {
                    emptyStateCard
                        .opacity(didAnimate ? 1 : 0)
                        .offset(y: didAnimate ? 0 : 16)
                }

                heroCard
                    .opacity(didAnimate ? 1 : 0)
                    .offset(y: didAnimate ? 0 : 18)

                streakCard
                    .opacity(didAnimate ? 1 : 0)
                    .offset(y: didAnimate ? 0 : 22)

                LazyVGrid(columns: gridColumns, spacing: 14) {
                    statCard(
                        title: "Bugün tamamlanan",
                        value: "\(completedTodayCount)",
                        subtitle: "task"
                    )

                    statCard(
                        title: "Aktif task",
                        value: "\(activeTaskCount)",
                        subtitle: "bekleyen görev"
                    )

                    statCard(
                        title: "Toplam task",
                        value: "\(totalTaskCount)",
                        subtitle: "kayıtlı görev"
                    )

                    statCard(
                        title: "Overdue",
                        value: "\(overdueTaskCount)",
                        subtitle: "geciken görev"
                    )
                }
                .opacity(didAnimate ? 1 : 0)
                .offset(y: didAnimate ? 0 : 26)

                weeklyChartCard
                    .opacity(didAnimate ? 1 : 0)
                    .offset(y: didAnimate ? 0 : 30)

                studyCard
                    .opacity(didAnimate ? 1 : 0)
                    .offset(y: didAnimate ? 0 : 34)

                scoreCard
                    .opacity(didAnimate ? 1 : 0)
                    .offset(y: didAnimate ? 0 : 38)

                productivityCard
                    .opacity(didAnimate ? 1 : 0)
                    .offset(y: didAnimate ? 0 : 42)
            }
            .padding(16)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: didAnimate)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            runEntranceAnimations()
        }
    }

    private var gridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14)
        ]
    }

    private var emptyStateCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 52, height: 52)

                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Henüz görev yok")
                    .font(.headline)

                Text("İlk görevini eklediğinde burada ilerleme, seri ve haftalık istatistiklerini göreceksin.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Overview")
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("%\(displayedCompletionRate)")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())

                Text("tamamlanma")
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(displayedCompletionRate), total: 100)
                .tint(.accentColor)
                .animation(.easeInOut(duration: 1.0), value: displayedCompletionRate)

            HStack(spacing: 12) {
                smallBadge(
                    icon: "flame.fill",
                    text: "\(currentStreak) gün seri"
                )

                smallBadge(
                    icon: "checkmark.circle.fill",
                    text: "\(completedTaskCount) tamamlandı"
                )
            }

            Text("Görev tamamlama oranı ve genel ilerleme")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Streak")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)

                        Text("\(currentStreak) gün seri")
                            .font(.title2.bold())
                    }

                    Text(streakDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(animateFlame ? 0.22 : 0.12))
                        .frame(width: animateFlame ? 66 : 58, height: animateFlame ? 66 : 58)
                        .blur(radius: animateFlame ? 2 : 0)

                    Circle()
                        .fill(Color.orange.opacity(0.10))
                        .frame(width: 78, height: 78)
                        .scaleEffect(animateFlame ? 1.08 : 0.92)
                        .opacity(animateFlame ? 0.9 : 0.4)

                    Image(systemName: "flame.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                        .scaleEffect(animateFlame ? 1.12 : 0.94)
                        .shadow(color: .orange.opacity(animateFlame ? 0.65 : 0.2), radius: animateFlame ? 14 : 4)
                }
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: animateFlame)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var weeklyChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Weekly Progress")
                    .font(.headline)

                Spacer()

                Text("7 gün")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(weeklyCompletedData.enumerated()), id: \.element.id) { index, entry in
                    let isToday = entry.dayIndex == todayIndex
                    let isWeekend = entry.dayIndex >= 5

                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    isToday
                                    ? Color.accentColor.opacity(0.18)
                                    : (isWeekend
                                       ? Color.secondary.opacity(0.08)
                                       : Color.secondary.opacity(0.12))
                                )
                                .frame(height: 110)

                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    isToday
                                    ? Color.accentColor
                                    : (isWeekend
                                       ? Color.accentColor.opacity(0.55)
                                       : Color.accentColor.opacity(0.9))
                                )
                                .frame(height: animateBars ? barHeight(for: entry.count) : 12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            isToday ? Color.accentColor : .clear,
                                            lineWidth: 1.5
                                        )
                                )
                                .shadow(
                                    color: isToday ? Color.accentColor.opacity(0.35) : .clear,
                                    radius: 6
                                )
                                .animation(
                                    .spring(response: 0.65, dampingFraction: 0.82)
                                    .delay(Double(index) * 0.06),
                                    value: animateBars
                                )
                        }

                        Text(InsightsEngine.dayName(entry.dayIndex))
                            .font(.caption2.weight(isToday ? .bold : .semibold))
                            .foregroundStyle(isToday ? .primary : .secondary)

                        Text("\(entry.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var studyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Weekly Study")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(InsightsEngine.durationText(totalWeeklyMinutes))
                        .font(.title2.bold())

                    Text("Bu haftaki toplam ders süresi")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Productivity Score")
                .font(.headline)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(productivityScore)/100")
                        .font(.title2.bold())

                    Text(scoreDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 10)
                        .frame(width: 72, height: 72)

                    Circle()
                        .trim(from: 0, to: animateScoreRing ? Double(productivityScore) / 100 : 0)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 72, height: 72)
                        .animation(.easeInOut(duration: 1.1), value: animateScoreRing)

                    Text("\(productivityScore)")
                        .font(.headline.bold())
                        .contentTransition(.numericText())
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var productivityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Most Busy Day")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(InsightsEngine.dayName(busiestDay.dayIndex))
                        .font(.title2.bold())

                    Text(InsightsEngine.durationText(busiestDay.minutes))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private func statCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title.bold())
                .contentTransition(.numericText())

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(cardBackground)
    }

    private func smallBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.secondary.opacity(0.12)))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private func barHeight(for count: Int) -> CGFloat {
        let normalized = CGFloat(count) / CGFloat(maxWeeklyCompletedCount)
        return max(12, normalized * 110)
    }

    private var scoreDescription: String {
        switch productivityScore {
        case 85...100: return "Harika gidiyorsun"
        case 65..<85: return "Oldukça iyi"
        case 40..<65: return "Daha iyi olabilir"
        default: return "Biraz toparlayalım"
        }
    }

    private var streakDescription: String {
        switch currentStreak {
        case 0:
            return "Bugün bir görev tamamlayıp seriyi başlat"
        case 1:
            return "Güzel başlangıç, devam et"
        case 2...6:
            return "Seri oluşuyor, bozma"
        default:
            return "Harika gidiyorsun"
        }
    }

    private func runEntranceAnimations() {
        guard !didAnimate else { return }

        didAnimate = true
        animateFlame = false
        animateBars = false
        animateScoreRing = false
        displayedCompletionRate = 0

        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            animateFlame = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            animateBars = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            animateScoreRing = true
        }

        animateNumber(to: completionRate)
    }

    private func animateNumber(to target: Int) {
        guard target > 0 else {
            displayedCompletionRate = 0
            return
        }

        let duration = 0.9
        let steps = max(target, 1)
        let stepDuration = duration / Double(steps)

        for value in 0...target {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(value)) {
                displayedCompletionRate = value
            }
        }
    }
}
