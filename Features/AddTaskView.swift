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
                Section("Görev") {
                    TextField("Başlık", text: $title)
                        .textInputAutocapitalization(.sentences)
                }

                Section("Tarih") {
                    Toggle("Tarih ekle", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker("Tarih", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("Görev Ekle")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ekle") { add() }
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
