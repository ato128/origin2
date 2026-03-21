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
            VStack(spacing: 12) {
                
                Picker("Gün", selection: $selectedDay) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(dayTitles[i]).tag(i)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.vertical, 4)
                
                HStack {
                    ForEach(0..<7, id: \.self) { i in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(i == weekdayIndexToday() ? Color.accentColor : .clear)
                                .frame(width: 6, height: 6)
                                .scaleEffect(i == weekdayIndexToday() && pulseTodayDot ? 1.18 : 1.0)
                                .opacity(i == weekdayIndexToday() ? 1 : 0)
                            
                            Color.clear.frame(height: 1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulseTodayDot)
            }
            .padding(8)
            .background(sectionCardBackground)
        }
        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    var personalDayPickerSection: some View {
        HStack(spacing: 8) {
            ForEach(dayTitles.indices, id: \.self) { day in
                let tint = dayIndicatorColor(for: day)

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedDay = day
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(dayTitles[day])
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(
                                selectedDay == day
                                ? palette.primaryText
                                : palette.secondaryText
                            )

                        Circle()
                            .fill(day == weekdayIndexToday() ? Color.blue : Color.clear)
                            .frame(width: 6, height: 6)
                            .opacity(day == weekdayIndexToday() ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                selectedDay == day
                                ? tint.opacity(0.18)
                                : palette.secondaryCardFill
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                selectedDay == day
                                ? tint.opacity(0.28)
                                : palette.cardStroke,
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: selectedDay == day ? tint.opacity(0.18) : .clear,
                        radius: selectedDay == day ? 12 : 0
                    )
                    .scaleEffect(selectedDay == day ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }
    var summarySection: some View {
        daySummaryCard
        
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 14, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
    

    var emptySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)

                Text("\(dayTitles[selectedDay]) günü boş")
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Spacer()
            }

            Text("Bu güne henüz ders eklenmemiş. Sağ üstteki + ile hızlıca yeni ders oluşturabilirsin.")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)

            Button {
                Haptics.impact(.medium)
                showingAdd = true
            } label: {
                Label("Ders ekle", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.accentColor.opacity(0.16)))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sectionCardBackground)
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 16, trailing: 16))
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

        let items = (allEventsAccessible )
            .filter { ev in
                let end = ev.startMinute + ev.durationMinute

                // ✅ 1. Manuel completed
                if ev.isCompleted {
                    return true
                }

                // ✅ 2. Zaman geçmişse otomatik completed
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

        print("✅ completedEvents count:", items.count)
        return items
    }
    var eventsSection: some View {
        VStack(spacing: 6) {
            if !nowEvents.isEmpty {
                personalEventGroup(nowEvents, title: "Now", systemImage: "dot.radiowaves.left.and.right", startIndex: 0)
            }

            if !nextEvents.isEmpty {
                personalEventGroup(nextEvents, title: "Up Next", systemImage: "clock.badge", startIndex: nowEvents.count)
            }

            if !laterEvents.isEmpty {
                personalEventGroup(
                    laterEvents,
                    title: isTodaySelected ? "Later Today" : "Schedule",
                    systemImage: "calendar",
                    startIndex: nowEvents.count + nextEvents.count
                )
            }

            if !completedEvents.isEmpty {
                personalEventGroup(
                    completedEvents,
                    title: "Completed",
                    systemImage: "checkmark.circle",
                    startIndex: nowEvents.count + nextEvents.count + laterEvents.count
                )
            }
        }
        .padding(.top, 2)
    }

    var daySummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(dayTitles[selectedDay])
                            .font(.headline)
                            .foregroundStyle(palette.primaryText)

                        if isTodaySelected {
                            Text("Bugün")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor.opacity(0.18))
                                )
                                .foregroundStyle(Color.accentColor)
                        }

                        if liveEventForDay != nil {
                            Text("LIVE")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.green.opacity(0.18)))
                                .foregroundStyle(.green)
                                .scaleEffect(animateSummary ? 1.03 : 1.0)
                                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: animateSummary)
                        }
                    }

                    Text(summarySubtitle)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                if totalMinutesForDay > 0 {
                    Text(durationText(totalMinutesForDay))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.primaryText)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 12) {
                summaryChip(
                    title: "Ders",
                    value: "\(eventsForDay.count)",
                    icon: "book.closed.fill"
                )

                summaryChip(
                    title: "İlk",
                    value: firstEventOfDay.map { hm($0.startMinute) } ?? "--:--",
                    icon: "sunrise.fill"
                )

                summaryChip(
                    title: "Son",
                    value: lastEventOfDay.map { hm($0.startMinute + $0.durationMinute) } ?? "--:--",
                    icon: "moon.stars.fill"
                )
            }

            if let live = liveEventForDay {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animateSummary ? 1.12 : 0.92)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: animateSummary)

                    Text("\(live.title) aktif")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.primaryText)

                    Spacer()

                    Text(timeText(for: live))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .background(sectionCardBackground)
        .scaleEffect(animateSummary ? 1.01 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: animateSummary)
    }
    
    func personalEventGroup(_ items: [EventItem], title: String, systemImage: String, startIndex: Int = 0) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            personalTimelineSectionHeader(title, systemImage: systemImage)

            LazyVStack(spacing: 14) {
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
        try? context.save()
        Haptics.impact(.medium)
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
    
    func personalTimelineSectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.secondaryText)

            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.secondaryText)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    func summaryChip(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(palette.secondaryText)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.secondaryCardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.cardStroke, lineWidth: 1)
        )
    }

    var summarySubtitle: String {
        if eventsForDay.isEmpty {
            return "Bu gün için kayıtlı ders yok"
        }

        if liveEventForDay != nil {
            return "Ders şu an aktif"
        }

        return "\(eventsForDay.count) ders • \(durationText(totalMinutesForDay)) toplam"
    }
}
