//
//  EditTaskView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData

struct EditTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let item: DTTaskItem

    @State private var title: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()

    var body: some View {
        Form {
            Section(String(localized: "edit_task_section_task")) {
                TextField(String(localized: "edit_task_title_placeholder"), text: $title)
                    .textInputAutocapitalization(.sentences)
            }

            Section(String(localized: "edit_task_section_date")) {
                Toggle(String(localized: "edit_task_toggle_date"), isOn: $hasDueDate.animation(.spring()))
                if hasDueDate {
                    DatePicker(
                        String(localized: "edit_task_date_picker"),
                        selection: $dueDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
            }

            Section {
                Button(role: .destructive) {
                    delete()
                } label: {
                    Text(String(localized: "edit_task_delete_button"))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle(String(localized: "edit_task_title"))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "common_cancel")) {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "common_save")) {
                    save()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            title = item.title
            if let d = item.dueDate {
                hasDueDate = true
                dueDate = d
            } else {
                hasDueDate = false
                dueDate = Date()
            }
        }
    }

    private func save() {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }

        item.title = t
        item.dueDate = hasDueDate ? dueDate : nil

        do {
            try context.save()
        } catch {
            print("Save failed:", error)
        }

        haptic(.light)
        dismiss()
    }

    private func delete() {
        context.delete(item)

        do {
            try context.save()
        } catch {
            print("Save failed:", error)
        }

        haptic(.heavy)
        dismiss()
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }
}
