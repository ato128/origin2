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
        HStack(spacing: 7) {
            ForEach(dayTitles.indices, id: \.self) { day in
                dayPickerButton(for: day)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: AppArenaPalette.blue).opacity(0.055),
                            Color(arenaHex: AppArenaPalette.purple).opacity(0.038),
                            Color.white.opacity(0.030)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(arenaHex: AppArenaPalette.cyan).opacity(0.080),
                                    Color.clear
                                ],
                                center: .topTrailing,
                                startRadius: 6,
                                endRadius: 150
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.075), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
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
        let indicatorColor = isLiveDay ? Color(arenaHex: AppArenaPalette.green) : tint
        let dotColor = isLiveDay ? Color(arenaHex: AppArenaPalette.green) : (hasItems ? tint.opacity(0.95) : Color.white.opacity(0.16))
        let dotSize: CGFloat = (isToday || isLiveDay) ? 6 : 4

        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                selectedDay = day
            }
        } label: {
            VStack(spacing: 6) {
                Text(localizedDayTitle(day))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.48))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)

                Text("\(Calendar.current.component(.day, from: targetDateFor(day: day)))")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.86))
                    .monospacedDigit()

                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(indicatorColor)
                            .frame(width: 16, height: 4)
                            .shadow(color: indicatorColor.opacity(0.35), radius: 6, y: 2)
                    } else {
                        Circle()
                            .fill(dotColor)
                            .frame(width: dotSize, height: dotSize)
                    }
                }
                .frame(height: 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(
                        isSelected
                        ? indicatorColor.opacity(0.16)
                        : Color.white.opacity(0.035)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(
                        isSelected
                        ? indicatorColor.opacity(0.24)
                        : Color.white.opacity(0.065),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected ? indicatorColor.opacity(0.12) : .clear,
                radius: isSelected ? 10 : 0,
                y: isSelected ? 5 : 0
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(heroAccentColor)
                            .frame(width: 18, height: 1)

                        Text("DAY FLOW")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.7)
                            .foregroundStyle(heroAccentColor)
                    }

                    HStack(spacing: 8) {
                        Text(localizedDayTitle(selectedDay))
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(.white)

                        if isTodaySelected {
                            capsuleMicroTag("Bugün", tint: Color(arenaHex: AppArenaPalette.gold))
                        }

                        if liveEventForDay != nil {
                            capsuleMicroTag("Canlı", tint: Color(arenaHex: AppArenaPalette.green))
                        }
                    }

                    Text(summarySubtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                if totalMinutesForDay > 0 {
                    Text(durationText(totalMinutesForDay))
                        .font(.system(size: 17, weight: .black, design: .monospaced))
                        .foregroundStyle(heroAccentColor)
                        .monospacedDigit()
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(
                            Capsule()
                                .fill(heroAccentColor.opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(heroAccentColor.opacity(0.18), lineWidth: 1)
                                )
                        )
                }
            }

            HStack(spacing: 8) {
                summaryChip(
                    title: "Ders",
                    value: "\(eventsForDay.count)",
                    icon: "book.closed.fill",
                    tint: liveEventForDay != nil ? Color(arenaHex: AppArenaPalette.green) : heroAccentColor
                )

                summaryChip(
                    title: "İlk",
                    value: firstEventOfDay.map { hm($0.startMinute) } ?? "--:--",
                    icon: "sunrise.fill",
                    tint: Color(arenaHex: AppArenaPalette.gold)
                )

                summaryChip(
                    title: "Son",
                    value: lastEventOfDay.map { hm($0.startMinute + $0.durationMinute) } ?? "--:--",
                    icon: "moon.stars.fill",
                    tint: Color(arenaHex: AppArenaPalette.purple)
                )
            }

            if let live = liveEventForDay {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(arenaHex: AppArenaPalette.green))
                        .frame(width: 7, height: 7)
                        .shadow(color: Color(arenaHex: AppArenaPalette.green).opacity(0.35), radius: 7)

                    Text(localizedLiveClassText(live.title))
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.white.opacity(0.90))
                        .lineLimit(1)

                    Spacer()

                    Text(timeText(for: live))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                }
                .padding(.top, 1)
            } else if let info = currentTimeIndicatorText {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white.opacity(0.44))

                    Text(info)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.top, 1)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            heroAccentColor.opacity(0.075),
                            Color(arenaHex: AppArenaPalette.purple).opacity(0.040),
                            Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [
                                    heroAccentColor.opacity(0.13),
                                    Color.clear
                                ],
                                center: .topTrailing,
                                startRadius: 6,
                                endRadius: 180
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(heroAccentColor.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.20), radius: 14, y: 7)
        )
        .padding(.horizontal, 2)
    }

    func summaryChip(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .black))

                Text(title.uppercased())
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.7)
            }
            .foregroundStyle(tint)
            .lineLimit(1)

            Text(value)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(tint.opacity(0.085))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(tint.opacity(0.12), lineWidth: 1)
                )
        )
    }

    func personalTimelineSectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(Color.white.opacity(0.28))
                .frame(width: 16, height: 1)

            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(.white.opacity(0.42))

            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.42))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 4)
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
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(heroAccentColor.opacity(0.13))
                        .frame(width: 46, height: 46)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(heroAccentColor.opacity(0.16), lineWidth: 1)
                        )

                    Image(systemName: "calendar")
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(heroAccentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedEmptyDayTitle(selectedDay))
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)

                    Text("Bugün için planlı bir ders ya da etkinlik görünmüyor.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(2)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(heroAccentColor)

                Text("Sağ üstten yeni ders veya etkinlik ekleyebilirsin")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(heroAccentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                Capsule()
                    .fill(heroAccentColor.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(heroAccentColor.opacity(0.16), lineWidth: 1)
                    )
            )
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            heroAccentColor.opacity(0.070),
                            Color(arenaHex: AppArenaPalette.purple).opacity(0.035),
                            Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(heroAccentColor.opacity(0.13), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
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
            return Color(arenaHex: AppArenaPalette.green)
        }

        if eventsForDay.isEmpty {
            return Color(arenaHex: AppArenaPalette.cyan)
        }

        return firstEventOfDay.map { dayIndicatorColor(for: $0.weekday) } ?? Color(arenaHex: AppArenaPalette.blue)
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
                .font(.system(size: 10, weight: .black))

            Text(text.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.6)
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.16), lineWidth: 1)
                )
        )
    }
    func capsuleMicroTag(_ text: String, tint: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .tracking(0.6)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.16), lineWidth: 1)
                    )
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
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(arenaHex: AppArenaPalette.cyan).opacity(0.13))
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(arenaHex: AppArenaPalette.cyan).opacity(0.16), lineWidth: 1)
                        )

                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Color(arenaHex: AppArenaPalette.cyan))
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(Color(arenaHex: AppArenaPalette.cyan))
                            .frame(width: 16, height: 1)

                        Text("COURSE SETUP")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(Color(arenaHex: AppArenaPalette.cyan))
                    }

                    Text("Derslerini ekle")
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(.white)

                    Text("Derslerini seç, haftanı ve çalışma planını buna göre kuralım.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            Button {
                Haptics.impact(.medium)
                showCourseSetupSheet = true
            } label: {
                HStack(spacing: 10) {
                    Text("DERSLERİ SEÇ")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(0.8)

                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .black))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(arenaHex: AppArenaPalette.cyan),
                                    Color(arenaHex: AppArenaPalette.purple)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: AppArenaPalette.cyan).opacity(0.075),
                            Color(arenaHex: AppArenaPalette.purple).opacity(0.040),
                            Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color(arenaHex: AppArenaPalette.cyan).opacity(0.14), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
}
