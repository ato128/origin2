//
//  InsightsView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//

import SwiftUI
import SwiftData

struct InsightsView: View {
    @EnvironmentObject private var store: TodoStore

    @Query(sort: \EventItem.startMinute, order: .forward)
    private var events: [EventItem]

    private var todos: [DTTaskItem] { store.items }

    var body: some View {
        List {
            Section("Özet") {
                HStack {
                    Label("Toplam görev", systemImage: "checklist")
                    Spacer()
                    Text("\(todos.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Tamamlanan", systemImage: "checkmark.circle")
                    Spacer()
                    Text("\(completedCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Bekleyen", systemImage: "clock")
                    Spacer()
                    Text("\(pendingCount)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Toplam ders", systemImage: "calendar")
                    Spacer()
                    Text("\(events.count)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Insights")
    }

    private var completedCount: Int {
        todos.filter { $0.isDone }.count
    }

    private var pendingCount: Int {
        todos.filter { !$0.isDone }.count
    }
}
