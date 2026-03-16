//
//  PlanAheadView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 12.03.2026.
//

import SwiftUI

struct PlanAheadView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selectedDate: Date
    @Binding var mode: PlanAheadMode
    
    var onContinue: () -> Void
    
    var body: some View {
        Form {
            Section("Date") {
                DatePicker(
                    "Choose Date",
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                
                HStack {
                    Text("Selected")
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text(formattedDate(selectedDate))
                        .font(.subheadline.weight(.semibold))
                }
            }
            
            Section("Type") {
                Picker("Mode", selection: $mode) {
                    ForEach(PlanAheadMode.allCases, id: \.self) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            Section {
                Button("Continue") {
                    onContinue()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Plan Ahead")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
