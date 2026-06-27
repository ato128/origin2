//
//  TasksScheduleSheet.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 17.03.2026.
//

import SwiftUI

struct TaskScheduleSheet: View {
    @Bindable var task: DTTaskItem
    @Environment(\.dismiss) private var dismiss

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    var body: some View {
        ZStack {
            AppBackground()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(tr("tss_title"))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Spacer()

                    Button(tr("common_ok")) {
                        dismiss()
                    }
                    .font(.headline)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(tr("tss_task"))
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)

                    Text(task.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.primaryText)
                }
                .padding(18)
                .background(cardBackground)

                VStack(alignment: .leading, spacing: 12) {
                    Text(tr("tss_datetime"))
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)

                    DatePicker(
                        "Schedule",
                        selection: Binding(
                            get: { task.scheduledWeekDate ?? Date() },
                            set: { task.scheduledWeekDate = $0 }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .foregroundStyle(palette.primaryText)

                    Stepper(
                        value: Binding(
                            get: { task.scheduledWeekDurationMinutes ?? 60 },
                            set: { task.scheduledWeekDurationMinutes = $0 }
                        ),
                        in: 15...240,
                        step: 15
                    ) {
                        Text(tr("tss_duration", task.scheduledWeekDurationMinutes ?? 60))
                            .foregroundStyle(palette.primaryText)
                    }
                }
                .padding(18)
                .background(cardBackground)

                Button {
                    dismiss()
                } label: {
                    Text(tr("tss_save"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.blue)
                        )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(16)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }
}
