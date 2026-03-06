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
    @State private var highlightStreak = false
    @State private var bumpChart = false
    @State private var pulseCompletion = false
    @State private var shineCompletion = false

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
    private var productivityLevel: String {
        switch completionRate {
        case 0..<30:
            return "Low focus"
        case 30..<60:
            return "Getting momentum"
        case 60..<85:
            return "Productive"
        default:
            return "Deep Work"
        }
    }
    private var productivityColor: Color {
        switch completionRate {
        case 0..<30:
            return .gray
        case 30..<60:
            return .orange
        case 60..<85:
            return .blue
        default:
            return .green
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .taskCompleted)) { _ in
            highlightStreak = true
            bumpChart = true
            pulseCompletion = true
            shineCompletion = true
            animateNumber(to: completionRate)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                bumpChart = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                pulseCompletion = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                shineCompletion = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                highlightStreak = false
            }
            
            
            
        }
        .onChange(of: completionRate) { newValue in
            displayedCompletionRate = newValue
        }
        
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
            HStack(spacing: 8) {
                Text("Overview")

                Label(productivityLevel, systemImage: "bolt.fill")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(productivityColor.opacity(0.18))
                    )
                    .foregroundStyle(productivityColor)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: completionRate)
            }
            .font(.headline)
            .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                ZStack {
                    Text("%\(displayedCompletionRate)")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .scaleEffect(pulseCompletion ? 1.18 : 1.0)
                        .shadow(
                            color: pulseCompletion ? Color.accentColor.opacity(0.45) : .clear,
                            radius: pulseCompletion ? 16 : 0
                        )
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: pulseCompletion)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.75),
                                    Color.white.opacity(0.0),
                                    .clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 26, height: 52)
                        .rotationEffect(.degrees(18))
                        .offset(x: shineCompletion ? 70 : -70)
                        .animation(.easeInOut(duration: 0.55), value: shineCompletion)
                        .mask(
                            Text("%\(displayedCompletionRate)")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                        )
                        .allowsHitTesting(false)
                }
                .frame(width: 160, height: 46, alignment: .leading)
                Text("tamamlanma")
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(displayedCompletionRate), total: 100)
                .tint(.clear)
                .overlay {
                    GeometryReader { geo in
                        let width = max(0, min(geo.size.width, geo.size.width * CGFloat(displayedCompletionRate) / 100))

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor.opacity(0.9),
                                        Color.accentColor,
                                        Color.white.opacity(shineCompletion ? 0.9 : 0.2),
                                        Color.accentColor
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: width, height: 4)
                            .animation(.easeInOut(duration: 0.6), value: displayedCompletionRate)
                            .animation(.easeInOut(duration: 0.4), value: shineCompletion)
                    }
                }
                .frame(height: 4)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )

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
                        .fill(Color.orange.opacity(animateFlame ? 0.24 : 0.10))
                        .frame(
                            width: highlightStreak
                            ? (animateFlame ? 78 : 68)
                            : (animateFlame ? 68 : 58),
                            height: highlightStreak
                            ? (animateFlame ? 78 : 68)
                            : (animateFlame ? 68 : 58)
                        )
                        .blur(radius: animateFlame ? 4 : 1)

                    Circle()
                        .fill(Color.orange.opacity(highlightStreak ? 0.18 : 0.10))
                        .frame(width: highlightStreak ? 92 : 78, height: highlightStreak ? 92 : 78)
                        .scaleEffect(animateFlame ? 1.12 : 0.90)
                        .opacity(animateFlame ? 0.95 : 0.35)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.yellow.opacity(highlightStreak ? 0.35 : 0.18),
                                    Color.orange.opacity(highlightStreak ? 0.20 : 0.08),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 4,
                                endRadius: highlightStreak ? 42 : 30
                            )
                        )
                        .frame(width: highlightStreak ? 100 : 82, height: highlightStreak ? 100 : 82)
                        .scaleEffect(animateFlame ? 1.08 : 0.92)

                    Image(systemName: "flame.fill")
                        .font(highlightStreak ? .title : .title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(
                            highlightStreak
                            ? (animateFlame ? 1.22 : 1.00)
                            : (animateFlame ? 1.14 : 0.94)
                        )
                        .shadow(
                            color: .orange.opacity(highlightStreak ? 0.85 : 0.45),
                            radius: highlightStreak ? 18 : 10
                        )
                }
                .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: animateFlame)
                .animation(.spring(response: 0.35, dampingFraction: 0.68), value: highlightStreak)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .scaleEffect(highlightStreak ? 1.04 : 1.0)
        .shadow(
            color: highlightStreak ? Color.orange.opacity(0.35) : .clear,
            radius: highlightStreak ? 18 : 0
        )
        .animation(.spring(response: 0.36, dampingFraction: 0.72), value: highlightStreak)
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
                                .scaleEffect(y: bumpChart ? 1.06 : 1.0, anchor: .bottom)
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
