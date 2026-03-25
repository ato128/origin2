//
//  AddTaskView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: TodoStore

    @State private var title: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "add_task_section_task")) {
                    TextField(String(localized: "add_task_title_placeholder"), text: $title)
                        .textInputAutocapitalization(.sentences)
                }

                Section(String(localized: "add_task_section_date")) {
                    Toggle(String(localized: "add_task_add_date"), isOn: $hasDueDate.animation())

                    if hasDueDate {
                        DatePicker(
                            String(localized: "add_task_date_picker"),
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
            }
            .navigationTitle(String(localized: "add_task_title"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common_cancel")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "add_task_add_button")) {
                        add()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func add() {
        store.add(
            title: title,
            dueDate: hasDueDate ? dueDate : nil
        )
        dismiss()
    }
}
