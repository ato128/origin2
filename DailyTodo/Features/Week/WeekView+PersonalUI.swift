//
//  WeekView+PersonalUI.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 11.03.2026.
//

import SwiftUI
import SwiftData

extension WeekView {

    var palette: ThemePalette {
        ThemePalette()
    }

    var pickerSection: some View {
        Section {
            VStack(spacing: 10) {
                personalDayPickerSection
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    var personalDayPickerSection: some View {
        HStack(spacing: 6) {
            ForEach(dayTitles.indices, id: \.self) { day in
                dayPickerButton(for: day)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.cardFill,
                            palette.cardFill.opacity(0.96)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    func dayPickerButton(for day: Int) -> some View {
        let tint = dayAccent(for: day)
        let isSelected = selectedDay == day
        let isToday = day == weekdayIndexToday()
        let hasItems = hasItemsOnDay(day)
        let isLiveDay = liveEventFor(day: day) != nil
        let indicatorColor = isLiveDay ? Color.green : tint
        let dotColor = isLiveDay ? Color.green : (hasItems ? tint.opacity(0.95) : Color.white.opacity(0.10))
        let backgroundColor = isSelected ? indicatorColor.opacity(0.13) : Color.white.opacity(0.018)
        let strokeColor = isSelected ? indicatorColor.opacity(0.20) : Color.white.opacity(0.05)
        let shadowColor = isSelected ? indicatorColor.opacity(0.05) : .clear
        let dotSize: CGFloat = (isToday || isLiveDay) ? 5.5 : 4

        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                selectedDay = day
            }
        } label: {
            VStack(spacing: 4) {
                Text(localizedDayTitle(day))
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? palette.primaryText : palette.secondaryText)
                    .lineLimit(1)

                Text("\(Calendar.current.component(.day, from: targetDateFor(day: day)))")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .monospacedDigit()

                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(indicatorColor)
                            .frame(width: 14, height: 3.5)
                    } else {
                        Circle()
                            .fill(dotColor)
                            .frame(width: dotSize, height: dotSize)
                    }
                }
                .frame(height: 7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
            .shadow(
                color: shadowColor,
                radius: isSelected ? 5 : 0,
                y: isSelected ? 2 : 0
            )
        }
        .buttonStyle(.plain)
    }

    func eventsFor(day: Int) -> [EventItem] {
        let calendar = Calendar.current
        let targetDate = targetDateFor(day: day)

        return userScopedEvents
            .filter { ev in
                guard !ev.isCompleted else { return false }

                if let scheduledDate = ev.scheduledDate {
                    return calendar.isDate(scheduledDate, inSameDayAs: targetDate)
                } else {
                    return ev.weekday == day
                }
            }
            .sorted { $0.startMinute < $1.startMinute }
    }

    func liveEventFor(day: Int) -> EventItem? {
        guard day == weekdayIndexToday() else { return nil }

        let now = currentMinuteOfDay()
        return eventsFor(day: day).first(where: { ev in
            now >= ev.startMinute && now < (ev.startMinute + ev.durationMinute)
        })
    }

    func dayAccent(for day: Int) -> Color {
        if liveEventFor(day: day) != nil {
            return .green
        }

        let items = eventsFor(day: day)

        if items.isEmpty {
            return Color.white.opacity(0.16)
        }

        if let first = items.first {
            return hexColor(first.colorHex)
        }

        return .blue
    }

    func hasItemsOnDay(_ day: Int) -> Bool {
        !eventsFor(day: day).isEmpty
    }

    var daySummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(localizedDayTitle(selectedDay))
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)

                        if isTodaySelected {
                            capsuleMicroTag("Bugün", tint: .orange)
                        }

                        if liveEventForDay != nil {
                            capsuleMicroTag("Canlı", tint: .green)
                        }
                    }

                    Text(summarySubtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if totalMinutesForDay > 0 {
                    Text(durationText(totalMinutesForDay))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 8) {
                summaryChip(
                    title: "Ders",
                    value: "\(eventsForDay.count)",
                    icon: "book.closed.fill",
                    tint: liveEventForDay != nil ? .green : heroAccentColor
                )

                summaryChip(
                    title: "İlk",
                    value: firstEventOfDay.map { hm($0.startMinute) } ?? "--:--",
                    icon: "sunrise.fill",
                    tint: .orange
                )

                summaryChip(
                    title: "Son",
                    value: lastEventOfDay.map { hm($0.startMinute + $0.durationMinute) } ?? "--:--",
                    icon: "moon.stars.fill",
                    tint: .purple
                )
            }

            if let live = liveEventForDay {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)

                    Text(localizedLiveClassText(live.title))
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(1)

                    Spacer()

                    Text(timeText(for: live))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }
                .padding(.top, 1)
            } else if let info = currentTimeIndicatorText {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(palette.secondaryText)

                    Text(info)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.top, 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.cardFill,
                            palette.cardFill.opacity(0.97)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.03),
                                    heroAccentColor.opacity(0.028),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
        .shadow(color: heroAccentColor.opacity(0.04), radius: 7, y: 2)
        .padding(.horizontal, 2)
    }

    func summaryChip(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.10),
                            tint.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(tint.opacity(0.10), lineWidth: 1)
        )
    }

    func personalTimelineSectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(palette.secondaryText)

            Text(title)
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(palette.secondaryText)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 3)
    }

    var summarySection: some View {
        daySummaryCard
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 10, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    var emptySection: some View {
        Group {
            if studentStore.courses.isEmpty {
                studentCourseEmptyCard
            } else {
                defaultEmptyWeekCard
            }
        }
    }

    var defaultEmptyWeekCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(heroAccentColor.opacity(0.14))
                        .frame(width: 38, height: 38)

                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(heroAccentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedEmptyDayTitle(selectedDay))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text("Bugün için planlı bir ders ya da etkinlik görünmüyor.")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.accentColor)

                Text("Sağ üstten yeni ders veya etkinlik ekleyebilirsin")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.14))
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.cardFill,
                            palette.cardFill.opacity(0.97)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(palette.cardStroke, lineWidth: 1)
                )
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    var nowEvents: [EventItem] {
        let now = currentMinuteOfDay()

        return eventsForDay.filter { ev in
            let start = ev.startMinute
            let end = ev.startMinute + ev.durationMinute
            return !ev.isCompleted && isTodaySelected && now >= start && now < end
        }
    }

    var nextEvents: [EventItem] {
        let now = currentMinuteOfDay()

        return eventsForDay.filter { ev in
            let start = ev.startMinute
            let diff = start - now
            return !ev.isCompleted && isTodaySelected && diff > 0 && diff <= 90
        }
    }

    var laterEvents: [EventItem] {
        let now = currentMinuteOfDay()

        return eventsForDay.filter { ev in
            let start = ev.startMinute
            return !ev.isCompleted && (!isTodaySelected || start - now > 90)
        }
    }

    var completedEvents: [EventItem] {
        let now = currentMinuteOfDay()
        let calendar = Calendar.current
        let targetDate = targetDateForSelectedDay()

        return allEventsAccessible
            .filter { ev in
                let end = ev.startMinute + ev.durationMinute

                if ev.isCompleted {
                    return true
                }

                if isTodaySelected && now >= end {
                    return true
                }

                return false
            }
            .filter { ev in
                if let scheduledDate = ev.scheduledDate {
                    return calendar.isDate(scheduledDate, inSameDayAs: targetDate)
                } else {
                    return ev.weekday == selectedDay
                }
            }
            .sorted { $0.startMinute < $1.startMinute }
    }

    var eventsSection: some View {
        VStack(spacing: 8) {
            if !nowEvents.isEmpty {
                personalEventGroup(
                    nowEvents,
                    title: "Şimdi",
                    systemImage: "dot.radiowaves.left.and.right",
                    startIndex: 0
                )
            }

            if !nextEvents.isEmpty {
                personalEventGroup(
                    nextEvents,
                    title: "Sıradaki",
                    systemImage: "clock.badge",
                    startIndex: nowEvents.count
                )
            }

            if !laterEvents.isEmpty {
                personalEventGroup(
                    laterEvents,
                    title: isTodaySelected ? "Daha Sonra" : "Program",
                    systemImage: "calendar",
                    startIndex: nowEvents.count + nextEvents.count
                )
            }

            if !completedEvents.isEmpty {
                personalEventGroup(
                    completedEvents,
                    title: "Tamamlananlar",
                    systemImage: "checkmark.circle",
                    startIndex: nowEvents.count + nextEvents.count + laterEvents.count
                )
            }
        }
        .padding(.top, 2)
    }

    func personalEventGroup(_ items: [EventItem], title: String, systemImage: String, startIndex: Int = 0) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            personalTimelineSectionHeader(title, systemImage: systemImage)

            LazyVStack(spacing: 10) {
                let now = currentMinuteOfDay()

                ForEach(Array(items.enumerated()), id: \.element.id) { index, ev in
                    personalEventRow(
                        ev,
                        now: now,
                        startIndex: startIndex,
                        index: index
                    )
                }
            }
        }
    }

    @ViewBuilder
    func personalEventRow(_ ev: EventItem, now: Int, startIndex: Int, index: Int) -> some View {
        EventRow(
            event: ev,
            timeText: timeText(for: ev),
            hasConflict: hasConflict(ev),
            nowMinute: now,
            isTodaySelected: isTodaySelected,
            isWorkout: isWorkoutEvent(ev),
            workoutDay: workoutDayText(for: ev),
            exerciseCount: workoutExerciseCount(for: ev),
            onTap: { selectedEventForDetail = ev },
            onEdit: { editingEvent = ev },
            onDelete: { delete(ev) },
            onComplete: { markEventCompleted(ev) }
        )
        .id(ev.id)
        .padding(.horizontal, 16)
        .offset(y: showPersonalEventCards ? 0 : CGFloat(24 + ((startIndex + index) * 8)))
        .opacity(showPersonalEventCards ? 1 : 0)
        .scaleEffect(showPersonalEventCards ? 1 : 0.985)
        .animation(
            .spring(response: 0.48, dampingFraction: 0.86)
                .delay(Double(startIndex + index) * 0.04),
            value: showPersonalEventCards
        )
    }

    func markEventCompleted(_ event: EventItem) {
        event.isCompleted = true

        do {
            try context.save()
            Haptics.impact(.medium)

            WidgetAppSync.refreshFromSwiftData(context: context)

            Task {
                await NotificationManager.shared.rescheduleAll(events: allEventsAccessible)
            }

            Task {
                guard let currentUserID = session.currentUser?.id else { return }

                let descriptor = FetchDescriptor<EventItem>(
                    sortBy: [SortDescriptor(\EventItem.startMinute, order: .forward)]
                )

                let all = (try? context.fetch(descriptor)) ?? []
                let currentUserEvents = all.filter { $0.ownerUserID == currentUserID.uuidString }

                await friendStore.resyncSharedWeekIfNeeded(
                    for: currentUserID,
                    events: currentUserEvents
                )
            }

        } catch {
            print("❌ markEventCompleted error:", error)
        }
    }

    func sourceTask(for event: EventItem) -> DTTaskItem? {
        guard let sourceTaskUUID = event.sourceTaskUUID else { return nil }
        return tasks.first(where: { $0.taskUUID == sourceTaskUUID })
    }

    func workoutExerciseCount(for event: EventItem) -> Int {
        guard let sourceTaskUUID = event.sourceTaskUUID else { return 0 }
        return workoutExercises.filter { $0.taskUUID == sourceTaskUUID }.count
    }

    func isWorkoutEvent(_ event: EventItem) -> Bool {
        sourceTask(for: event)?.taskType == "workout"
    }

    func workoutDayText(for event: EventItem) -> String? {
        sourceTask(for: event)?.workoutDay
    }

    func compactSummaryChip(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(palette.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(palette.secondaryCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(palette.cardStroke, lineWidth: 1)
        )
    }

    var summarySubtitle: String {
        if eventsForDay.isEmpty {
            return "Bu gün için kayıtlı ders görünmüyor"
        }

        if liveEventForDay != nil {
            return "Şu anda aktif bir ders var"
        }

        return localizedSummarySubtitle(count: eventsForDay.count, totalMinutes: totalMinutesForDay)
    }

    var heroTitleText: String {
        if eventsForDay.isEmpty {
            return isTodaySelected ? "Bugün boş" : "\(localizedDayTitle(selectedDay)) hafif"
        }

        if let live = liveEventForDay {
            return live.title
        }

        if let first = firstEventOfDay {
            return first.title
        }

        return "Planın hazır"
    }

    var heroSubtitleText: String {
        if eventsForDay.isEmpty {
            return "Yeni ders, çalışma saati veya etkinlik ekleyerek planını doldurabilirsin."
        }

        if let live = liveEventForDay {
            return "\(timeText(for: live)) arasında aktif."
        }

        return "\(eventsForDay.count) kayıt • \(durationText(totalMinutesForDay)) toplam yük"
    }

    var heroAccentColor: Color {
        if liveEventForDay != nil {
            return .green
        }
        if eventsForDay.isEmpty {
            return .blue
        }
        return firstEventOfDay.map { dayIndicatorColor(for: $0.weekday) } ?? .accentColor
    }

    var heroSymbolName: String {
        if liveEventForDay != nil {
            return "dot.radiowaves.left.and.right"
        }
        if eventsForDay.isEmpty {
            return "calendar"
        }
        return "book.closed.fill"
    }

    func heroInfoChip(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
        )
    }

    func capsuleMicroTag(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
            )
    }

    func localizedEmptyDayTitle(_ day: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(localizedDayTitle(day)) boş"
        } else {
            return "\(localizedDayTitle(day)) is empty"
        }
    }

    func localizedLiveClassText(_ title: String) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(title) aktif"
        } else {
            return "\(title) is active"
        }
    }

    func localizedSummarySubtitle(count: Int, totalMinutes: Int) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(count) kayıt • \(durationText(totalMinutes)) toplam"
        } else {
            return "\(count) items • \(durationText(totalMinutes)) total"
        }
    }
    var studentCourseEmptyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 46, height: 46)

                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Derslerini ekle")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text("Derslerini seç, haftanı ve çalışma planını buna göre kuralım.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            Button {
                Haptics.impact(.medium)
                showCourseSetupSheet = true
            } label: {
                Text("Dersleri Seç")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [.blue, .indigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}
