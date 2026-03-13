//
//  WeekView+PersonalUI.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 11.03.2026.
//

import SwiftUI
import SwiftData

extension WeekView {
    
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
            ForEach(0..<7, id: \.self) { day in
                let isSelected = day == selectedDay
                let isToday = day == weekdayIndexToday()
                let tint = dayIndicatorColor(for: day)

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedDay = day
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(dayTitles[day])
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? .white : .primary)

                        Circle()
                            .fill(isToday ? Color.blue : Color.clear)
                            .frame(width: 6, height: 6)
                            .opacity(isToday ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                isSelected
                                ? LinearGradient(
                                    colors: [
                                        tint,
                                        tint.opacity(0.82)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.05),
                                        Color.white.opacity(0.025)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isSelected
                                ? Color.white.opacity(0.14)
                                : Color.white.opacity(0.05),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isSelected ? tint.opacity(0.26) : .clear,
                        radius: isSelected ? 12 : 0
                    )
                    .scaleEffect(isSelected ? 1.02 : 1.0)
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

                Spacer()
            }

            Text("Bu güne henüz ders eklenmemiş. Sağ üstteki + ile hızlıca yeni ders oluşturabilirsin.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                Haptics.impact(.medium)
                showingAdd = true
            } label: {
                Label("Ders ekle", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.accentColor.opacity(0.16)))
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
            return isTodaySelected && now >= start && now < end
        }
    }

    var nextEvents: [EventItem] {
        let now = currentMinuteOfDay()

        return eventsForDay.filter { ev in
            let start = ev.startMinute
            let diff = start - now
            return isTodaySelected && diff > 0 && diff <= 90
        }
    }

    var laterEvents: [EventItem] {
        let now = currentMinuteOfDay()

        return eventsForDay.filter { ev in
            let start = ev.startMinute
            return !isTodaySelected || start - now > 90
        }
    }

    var completedEvents: [EventItem] {
        let now = currentMinuteOfDay()

        return eventsForDay.filter { ev in
            let end = ev.startMinute + ev.durationMinute
            return isTodaySelected && now >= end
        }
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
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if totalMinutesForDay > 0 {
                    Text(durationText(totalMinutesForDay))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
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
                        .foregroundStyle(.primary)

                    Spacer()

                    Text(timeText(for: live))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
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
                    EventRow(
                        event: ev,
                        timeText: timeText(for: ev),
                        hasConflict: hasConflict(ev),
                        nowMinute: now,
                        isTodaySelected: isTodaySelected,
                        onTap: { editingEvent = ev },
                        onEdit: { editingEvent = ev },
                        onDelete: { delete(ev) }
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
            }
        }
    }
    
    func personalTimelineSectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

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
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
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
