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

    var body: some View {
        let today = weekdayIndexToday()
        let now = currentMinuteOfDay()

        let todayEvents = allEvents
            .filter { $0.weekday == today }
            .sorted { $0.startMinute < $1.startMinute }

        let live = todayEvents.first(where: { now >= $0.startMinute && now < ($0.startMinute + $0.durationMinute) })
        let next = todayEvents.first(where: { $0.startMinute > now })

        let remainingTodos = todos.filter { !$0.isDone }.count

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bugün")
                            .font(.title2.bold())
                        Text(dayTitles[today])
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

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
                            title: "Sıradaki",
                            main: next.title,
                            sub: "\(hm(next.startMinute))–\(hm(next.startMinute + next.durationMinute))",
                            right: "\(max(0, next.startMinute - now)) dk sonra",
                            colorHex: next.colorHex
                        )
                    } else {
                        bigCard(
                            title: "Program",
                            main: "Bugün ders yok",
                            sub: "Keyfine bak 😄",
                            right: "",
                            colorHex: "#64748B"
                        )
                    }
                }

                // Stats row
                let totalMinutes = todayEvents.reduce(0) { $0 + $1.durationMinute }
                HStack(spacing: 12) {
                    smallStat(title: "Ders", value: "\(todayEvents.count)")
                    smallStat(title: "Toplam", value: "\(totalMinutes/60)s \(totalMinutes%60)dk")
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
                        // sende varsa Todo list view buraya
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
    }

    // MARK: - UI Helpers

    private func bigCard(title: String, main: String, sub: String, right: String, colorHex: String) -> some View {
        let c = Color(hex: colorHex)
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
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
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
        let w = Calendar.current.component(.weekday, from: Date()) // 1=Paz ... 7=Cmt
        return (w + 5) % 7 // 0=Pzt ... 6=Paz
    }

    private func hm(_ minute: Int) -> String {
        let m = max(0, min(1439, minute))
        let h = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
    }
}

// MARK: - Hex Color (HomeView içinden kullanıyoruz)
private extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6 else { self = .accentColor; return }
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
