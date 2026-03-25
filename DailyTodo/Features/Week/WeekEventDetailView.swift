//
//  WeekEventDetailView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 17.03.2026.
//

import SwiftUI
import SwiftData

struct WeekEventDetailView: View {
    @Bindable var event: EventItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var friendStore: FriendStore

    @Query private var allTasks: [DTTaskItem]
    @Query private var allWorkoutExercises: [WorkoutExerciseItem]
    @Query(sort: \EventItem.startMinute, order: .forward) private var allEvents: [EventItem]

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @State private var showEditSheet = false

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    titleCard
                    timeCard

                    if isWorkoutEvent {
                        workoutSummaryCard
                    }

                    detailsCard
                    actionCard

                    Spacer(minLength: 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEditSheet) {
            EditEventView(event: event)
        }
    }
}

private extension WeekEventDetailView {
    var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(palette.cardFill)
                            .overlay(
                                Circle()
                                    .stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            Text(String(localized: "week_event_detail_title"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
    }

    var sourceTask: DTTaskItem? {
        guard let sourceTaskUUID = event.sourceTaskUUID else { return nil }
        return allTasks.first(where: { $0.taskUUID == sourceTaskUUID })
    }

    var workoutExercisesForEvent: [WorkoutExerciseItem] {
        guard let sourceTaskUUID = event.sourceTaskUUID else { return [] }

        return allWorkoutExercises
            .filter { $0.taskUUID == sourceTaskUUID }
            .sorted { lhs, rhs in
                if lhs.orderIndex != rhs.orderIndex {
                    return lhs.orderIndex < rhs.orderIndex
                }
                return lhs.createdAt < rhs.createdAt
            }
    }

    var isWorkoutEvent: Bool {
        sourceTask?.taskType == "workout"
    }

    var workoutSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(String(localized: "week_event_workout_summary"))
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Spacer()

                if let day = sourceTask?.workoutDay {
                    Text(day)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.12))
                        )
                }
            }

            if workoutExercisesForEvent.isEmpty {
                Text(String(localized: "week_event_no_exercises_found"))
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(workoutExercisesForEvent) { exercise in
                        workoutExerciseMiniCard(exercise)
                    }
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    func miniInfoPill(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(palette.secondaryText)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(palette.cardFill)
            )
    }

    func workoutExerciseMiniCard(_ exercise: WorkoutExerciseItem) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(Color.green.opacity(0.14))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    miniInfoPill(localizedSetText(exercise.sets))
                    miniInfoPill(localizedRepText(exercise.reps))

                    if exercise.durationSeconds > 0 {
                        miniInfoPill(localizedSecondText(exercise.durationSeconds))
                    }

                    if exercise.restSeconds > 0 {
                        miniInfoPill(localizedRestText(exercise.restSeconds))
                    }
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.secondaryCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    var titleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(hexColor(event.colorHex))
                    .frame(width: 12, height: 12)

                Text(event.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(palette.primaryText)
            }

            Text(dayText(for: event.weekday))
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
        }
        .padding(18)
        .background(cardBackground)
    }

    var timeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "week_event_time"))
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            HStack(spacing: 12) {
                infoBlock(
                    title: String(localized: "week_event_starts"),
                    value: hm(event.startMinute),
                    icon: "clock.fill"
                )

                infoBlock(
                    title: String(localized: "week_event_ends"),
                    value: hm(event.startMinute + event.durationMinute),
                    icon: "clock.badge.checkmark.fill"
                )

                infoBlock(
                    title: String(localized: "week_event_duration"),
                    value: localizedMinuteValue(event.durationMinute),
                    icon: "timer"
                )
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var detailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "week_event_details"))
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            if let location = event.location,
               !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                detailRow(
                    title: String(localized: "week_event_location"),
                    value: location,
                    icon: "mappin.and.ellipse"
                )
            }

            if let notes = event.notes,
               !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                detailRow(
                    title: String(localized: "week_event_notes"),
                    value: notes,
                    icon: "note.text"
                )
            }

            if event.location?.isEmpty != false && event.notes?.isEmpty != false {
                Text(String(localized: "week_event_no_extra_details"))
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var actionCard: some View {
        VStack(spacing: 12) {
            Button {
                showEditSheet = true
            } label: {
                Text(String(localized: "week_event_edit"))
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

            Button(role: .destructive) {
                Task {
                    let deletedEventID = event.id

                    modelContext.delete(event)

                    do {
                        try modelContext.save()

                        guard let currentUserID = session.currentUser?.id else {
                            dismiss()
                            return
                        }

                        let currentUserEvents = allEvents.filter {
                            $0.id != deletedEventID && $0.ownerUserID == currentUserID.uuidString
                        }

                        await friendStore.resyncSharedWeekIfNeeded(
                            for: currentUserID,
                            events: currentUserEvents
                        )

                        dismiss()
                    } catch {
                        print("WeekEventDetailView delete error:", error)
                    }
                }
            } label: {
                Text(String(localized: "week_event_delete"))
                    .font(.headline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.red.opacity(0.10))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(cardBackground)
    }

    func infoBlock(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(palette.secondaryText)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.primaryText)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.secondaryCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    func detailRow(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(palette.primaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.secondaryCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
    }

    func hm(_ minute: Int) -> String {
        let m = max(0, min(1439, minute))
        let h = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
    }

    func dayText(for weekday: Int) -> String {
        let isTR = locale.language.languageCode?.identifier == "tr"

        if isTR {
            let days = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]
            guard weekday >= 0 && weekday < days.count else { return "Bilinmeyen gün" }
            return days[weekday]
        } else {
            let days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            guard weekday >= 0 && weekday < days.count else { return "Unknown day" }
            return days[weekday]
        }
    }

    func localizedMinuteValue(_ value: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(value) dk"
        } else {
            return "\(value) min"
        }
    }

    func localizedSetText(_ value: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(value) set"
        } else {
            return "\(value) set"
        }
    }

    func localizedRepText(_ value: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(value) tekrar"
        } else {
            return "\(value) rep"
        }
    }

    func localizedSecondText(_ value: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(value) sn"
        } else {
            return "\(value) sec"
        }
    }

    func localizedRestText(_ value: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(value) dinlenme"
        } else {
            return "\(value) rest"
        }
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
