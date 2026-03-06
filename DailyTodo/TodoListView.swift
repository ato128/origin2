//
//  TodoListView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//

import SwiftUI
import SwiftData
import UIKit
import Combine

struct TodoListView: View {
    @Binding var selectedTab: AppTab
    @EnvironmentObject private var store: TodoStore

    @Query(sort: \EventItem.startMinute, order: .forward)
    private var allEvents: [EventItem]

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case today = "Today"
        case overdue = "Overdue"
        var id: String { rawValue }
    }

    enum NextClassStatus {
        case live
        case next
    }

    @State private var searchText: String = ""
    @State private var filter: Filter = .all
    @State private var showDone: Bool = true

    @State private var showingAdd: Bool = false
    @State private var editingItem: DTTaskItem? = nil

    private let chipTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    private var items: [DTTaskItem] { store.items }

    private var filteredItems: [DTTaskItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var base = items

        if !showDone {
            base = base.filter { !$0.isDone }
        }

        if !q.isEmpty {
            base = base.filter { $0.title.lowercased().contains(q) }
        }

        switch filter {
        case .all:
            return base
        case .today:
            return base.filter { item in
                guard let d = item.dueDate else { return false }
                return Calendar.current.isDate(d, inSameDayAs: Date())
            }
        case .overdue:
            return base.filter { store.isOverdue($0) }
        }
    }

    private var nextClassInfo: (title: String, timeText: String, status: NextClassStatus)? {
        let today = weekdayIndexToday()
        let nowMinute = currentMinuteOfDay()

        let todayEvents = allEvents
            .filter { $0.weekday == today }
            .sorted { $0.startMinute < $1.startMinute }

        if let live = todayEvents.first(where: {
            nowMinute >= $0.startMinute &&
            nowMinute < ($0.startMinute + $0.durationMinute)
        }) {
            let endMinute = live.startMinute + live.durationMinute
            let remain = max(0, endMinute - nowMinute)
            return (live.title, "\(remain) dk", .live)
        }

        if let next = todayEvents.first(where: { $0.startMinute > nowMinute }) {
            let remain = max(0, next.startMinute - nowMinute)
            return (next.title, "\(remain) dk", .next)
        }

        return nil
    }

    var body: some View {
        Group {
            if filteredItems.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic))
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingAdd) {
            AddTaskView()
                .environmentObject(store)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                EditTaskView(item: item)
                    .environmentObject(store)
            }
            .presentationDetents([.medium, .large])
        }
        .overlay(alignment: .bottomTrailing) {
            floatingAddButton
        }
        .onReceive(chipTimer) { value in
            now = value
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checklist")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Henüz görev yok")
                .font(.title3.weight(.semibold))

            Text("Sağ alttaki + ile yeni görev ekleyebilirsin.")
                .foregroundStyle(.secondary)

            Button {
                showingAdd = true
                haptic(.medium)
            } label: {
                Label("İlk görevi ekle", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .padding(.top, 50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var list: some View {
        List {
            Section {
                ForEach(filteredItems) { item in
                    row(item)
                        .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    store.toggleDone(item)
                                }
                                haptic(.light)
                            } label: {
                                Label(
                                    item.isDone ? "Geri al" : "Tamamla",
                                    systemImage: item.isDone ? "arrow.uturn.left" : "checkmark"
                                )
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.delete(item)
                                haptic(.heavy)
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    private func row(_ item: DTTaskItem) -> some View {
        Button {
            editingItem = item
        } label: {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        store.toggleDone(item)
                    }
                    haptic(.light)
                } label: {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(item.isDone ? .green : .secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .strikethrough(item.isDone, color: .secondary)
                            .opacity(item.isDone ? 0.6 : 1.0)
                            .lineLimit(2)

                        Spacer(minLength: 8)

                        if let badge = badgeText(for: item) {
                            Text(badge.text)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(badge.background))
                                .foregroundStyle(badge.foreground)
                        }
                    }

                    if let d = item.dueDate {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text(d, style: .date)
                            Text("•")
                            Text(d, style: .time)
                        }
                        .font(.caption)
                        .foregroundStyle(store.isOverdue(item) && !item.isDone ? .red : .secondary)
                    }
                }

                if store.isOverdue(item) && !item.isDone {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .opacity(item.isDone ? 0.88 : 1.0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func badgeText(for item: DTTaskItem) -> (text: String, background: Color, foreground: Color)? {
        if item.isDone {
            return ("DONE", .green.opacity(0.16), .green)
        }

        if store.isOverdue(item) {
            return ("LATE", .red.opacity(0.16), .red)
        }

        if let d = item.dueDate, Calendar.current.isDate(d, inSameDayAs: Date()) {
            return ("TODAY", .orange.opacity(0.18), .orange)
        }

        return nil
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }

                Toggle("Done göster", isOn: $showDone)

                Button("Yenile") {
                    store.reload()
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            if let next = nextClassInfo {
                Button {
                    withAnimation(.easeInOut) {
                        selectedTab = .week
                    }
                    haptic(.light)
                } label: {
                    HStack(spacing: 6) {
                        Text(next.status == .live ? "LIVE" : "NEXT")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(next.status == .live ? .green : .orange)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(
                                        next.status == .live
                                        ? Color.green.opacity(0.18)
                                        : Color.orange.opacity(0.18)
                                    )
                            )
                            .shadow(
                                color: next.status == .live ? Color.green.opacity(0.28) : .clear,
                                radius: next.status == .live ? 6 : 0
                            )
                            .scaleEffect(next.status == .live ? 1.03 : 1.0)
                            .animation(
                                next.status == .live
                                ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                                : .default,
                                value: next.status == .live
                            )
                            .fixedSize(horizontal: true, vertical: true)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(next.title.uppercased())
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)

                            Text(next.timeText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.leading, 6)
                    .padding(.trailing, 8)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var floatingAddButton: some View {
        Button {
            showingAdd = true
            haptic(.medium)
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    private func currentMinuteOfDay() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private func weekdayIndexToday() -> Int {
        let w = Calendar.current.component(.weekday, from: now)
        return (w + 5) % 7
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }
}
