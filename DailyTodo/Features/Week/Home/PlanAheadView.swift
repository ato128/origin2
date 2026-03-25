//
//  PlanAheadView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 12.03.2026.
//

import SwiftUI

struct PlanAheadView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @Binding var selectedDate: Date
    @Binding var mode: PlanAheadMode

    var onContinue: () -> Void

    var body: some View {
        Form {
            Section("plan_date_section") {
                DatePicker(
                    "plan_choose_date",
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)

                HStack {
                    Text("plan_selected")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(formattedDate(selectedDate))
                        .font(.subheadline.weight(.semibold))
                }
            }

            Section("plan_type_section") {
                Picker("plan_mode", selection: $mode) {
                    ForEach(PlanAheadMode.allCases, id: \.self) { item in
                        Text(localizedPlanAheadMode(item))
                            .tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button("plan_continue") {
                    onContinue()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("plan_ahead_title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("week_cancel") {
                    dismiss()
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func localizedPlanAheadMode(_ mode: PlanAheadMode) -> String {
        switch mode {
        case .personal:
            return String(localized: "plan_mode_personal")
        case .crew:
            return String(localized: "plan_mode_crew")
        }
    }
}
