//
//  HomeView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var store: TodoStore

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case today = "Today"
        case overdue = "Overdue"
        var id: String { rawValue }
    }

    @State private var searchText: String = ""
    @State private var filter: Filter = .all
    @State private var showDone: Bool = true

    @State private var showingAdd: Bool = false
    @State private var editingItem: ? = nil

    private var items: [] { store.items }

    private var filteredItems: [] {
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

    var body: some View {
        Group {
            if filteredItems.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Tasks")
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
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Henüz görev yok")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Sağ üstteki + ile yeni görev ekleyebilirsin.")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 40)
    }

    private var list: some View {
        List {
            Section {
                ForEach(filteredItems) { item in
                    row(item)
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
                                haptic(.medium)
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func row(_ item: ) -> some View {
        Button {
            editingItem = item
        } label: {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        store.toggleDone(item)
                    }
                    haptic(.light)
                } label: {
                    Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(item.isDone ? .green : .secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .foregroundStyle(.primary)

                    if let d = item.dueDate {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text(d, style: .date)
                            Text(d, style: .time)
                        }
                        .font(.caption)
                        .foregroundStyle(store.isOverdue(item) ? .red : .secondary)
                    }
                }

                Spacer()

                if store.isOverdue(item) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            Button {
                showingAdd = true
                haptic(.medium)
            } label: {
                Image(systemName: "plus")
            }
        }
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }
}
