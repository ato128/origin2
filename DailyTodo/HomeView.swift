//
//  HomeView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//

import SwiftUI
import SwiftData

struct HomeView: View {

    @Environment(\.modelContext) private var context

    @Query(sort: \EventItem.startMinute, order: .forward)
    private var allEvents: [EventItem]

    @Query(sort: \DTTaskItem.createdAt, order: .reverse)
    private var todos: [DTTaskItem]

    private let dayTitles = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]

    @State private var selectedDay: Int = 0

    var body: some View {
        let today = weekdayIndexToday()
        let now = currentMinuteOfDay()
        let isTodaySelected = selectedDay == today

        let selectedDate = targetDateFor(day: selectedDay)

        let selectedDayEvents = allEvents
            .filter { ev in
                if let scheduledDate = ev.scheduledDate {
                    return Calendar.current.isDate(scheduledDate, inSameDayAs: selectedDate)
                } else {
                    return ev.weekday == selectedDay
                }
            }
            .sorted { $0.startMinute < $1.startMinute }

        let live = isTodaySelected
            ? selectedDayEvents.first(where: {
                now >= $0.startMinute && now < ($0.startMinute + $0.durationMinute)
            })
            : nil

        let next: EventItem? = {
            if isTodaySelected {
                return selectedDayEvents.first(where: { $0.startMinute > now })
            } else {
                return selectedDayEvents.first
            }
        }()

        let remainingTodos = todos.filter { !$0.isDone }.count
        let totalMinutes = selectedDayEvents.reduce(0) { $0 + $1.durationMinute }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bugün")
                            .font(.title2.bold())

                        Text(selectedHeaderText(for: selectedDay, today: today))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                // Mini Week Calendar
                miniWeekCalendar(today: today)

                // Next / Live card
                Group {
                    if let live {
                        bigCard(
                            title: "Şu an",
                            main: live.title,
                            sub: "\(hm(live.startMinute))–\(hm(live.startMinute + live.durationMinute))",
                            right: "\(max(0, (live.startMinute + live.durationMinute) - now)) dk kaldı",
                            colorHex: live.colorHex
                        )
                    } else if let next {
                        bigCard(
                            title: isTodaySelected ? "Sıradaki" : "Seçili Gün",
                            main: next.title,
                            sub: "\(hm(next.startMinute))–\(hm(next.startMinute + next.durationMinute))",
                            right: isTodaySelected
                            ? "\(max(0, next.startMinute - now)) dk sonra"
                            : "",
                            colorHex: next.colorHex
                        )
                    } else {
                        bigCard(
                            title: "Program",
                            main: "\(dayTitles[selectedDay]) günü boş",
                            sub: "Bu gün için kayıtlı ders yok",
                            right: "",
                            colorHex: "#64748B"
                        )
                    }
                }

                // Stats row
                HStack(spacing: 12) {
                    smallStat(title: "Ders", value: "\(selectedDayEvents.count)")
                    smallStat(title: "Toplam", value: formattedDuration(totalMinutes))
                    smallStat(title: "Todo", value: "\(remainingTodos)")
                }

                // Quick actions
                VStack(alignment: .leading, spacing: 10) {
                    Text("Kısayollar")
                        .font(.headline)

                    NavigationLink {
                        WeekView()
                    } label: {
                        actionRow(title: "Haftalık Program", icon: "calendar")
                    }

                    NavigationLink {
                        TodoListView(selectedTab: .constant(.tasks))
                    } label: {
                        actionRow(title: "Todo List", icon: "checklist")
                    }

                    NavigationLink {
                        SettingsView()
                    } label: {
                        actionRow(title: "Ayarlar", icon: "gearshape")
                    }
                }
                .padding(.top, 6)
            }
            .padding()
        }
        .navigationTitle("DailyTodo")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedDay = weekdayIndexToday()
        }
    }

    // MARK: - Mini Calendar

    @ViewBuilder
    private func miniWeekCalendar(today: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { day in
                let isSelected = day == selectedDay
                let isToday = day == today
                let date = targetDateFor(day: day)
                let hasItems = hasEvents(on: day)

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedDay = day
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(dayTitles[day])
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? .primary : .secondary)

                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)

                        ZStack {
                            if isToday && !hasItems {
                                Circle()
                                    .stroke(Color.accentColor.opacity(0.7), lineWidth: 1.5)
                                    .frame(width: 8, height: 8)
                            } else {
                                Circle()
                                    .fill(hasItems ? Color.accentColor : Color.white.opacity(0.18))
                                    .frame(width: hasItems ? 7 : 5, height: hasItems ? 7 : 5)
                            }
                        }
                        .frame(height: 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                isSelected
                                ? Color.accentColor.opacity(0.16)
                                : Color.secondary.opacity(0.08)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isSelected
                                ? Color.accentColor.opacity(0.28)
                                : Color.white.opacity(0.04),
                                lineWidth: 1
                            )
                    )
                    .scaleEffect(isSelected ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func hasEvents(on day: Int) -> Bool {
        let targetDate = targetDateFor(day: day)

        return allEvents.contains { ev in
            if let scheduledDate = ev.scheduledDate {
                return Calendar.current.isDate(scheduledDate, inSameDayAs: targetDate)
            } else {
                return ev.weekday == day
            }
        }
    }

    private func targetDateFor(day: Int) -> Date {
        let calendar = Calendar.current
        let today = Date()

        guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let targetDate = calendar.date(byAdding: .day, value: day, to: startOfWeek)
        else {
            return today
        }

        return targetDate
    }

    private func selectedHeaderText(for day: Int, today: Int) -> String {
        if day == today {
            return "\(dayTitles[day]) • Bugün"
        }
        return dayTitles[day]
    }

    // MARK: - UI Helpers

    private func bigCard(title: String, main: String, sub: String, right: String, colorHex: String) -> some View {
        let c = hexColor(colorHex)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if !right.isEmpty {
                    Text(right)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Text(main)
                .font(.title3.bold())
                .lineLimit(1)

            Text(sub)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(c.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(c.opacity(0.25), lineWidth: 1)
                )
        )
    }

    private func smallStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func actionRow(title: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 26)

            Text(title)
                .font(.subheadline.weight(.semibold))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    // MARK: - Time helpers

    private func currentMinuteOfDay() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private func weekdayIndexToday() -> Int {
        let w = Calendar.current.component(.weekday, from: Date())
        return (w + 5) % 7
    }

    private func hm(_ minute: Int) -> String {
        let m = max(0, min(1439, minute))
        let h = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
    }

    private func formattedDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60

        if minutes == 0 { return "0 dk" }
        if h == 0 { return "\(m) dk" }
        if m == 0 { return "\(h) sa" }
        return "\(h) sa \(m) dk"
    }
}

// MARK: - Hex Color (HomeView içinden kullanıyoruz)
 
