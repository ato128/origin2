//
//  WeekView+PersonalUI.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 11.03.2026.
//

import SwiftUI
import SwiftData

extension WeekView {

    @ViewBuilder
    func personalWeekList(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            modeTitleSwitcher

            List {
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: WeekScrollOffsetKey.self,
                            value: max(0, -geo.frame(in: .named("personalScroll")).minY)
                        )
                }
                .frame(height: 0)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

                pickerSection
                summarySection

                if eventsForDay.isEmpty {
                    emptySection
                } else {
                    eventsSection
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .coordinateSpace(name: "personalScroll")
            .onPreferenceChange(WeekScrollOffsetKey.self) { value in
                personalScrollOffset = value
            }
        }
        .background(Color(.systemGroupedBackground))
        .offset(y: showPersonalEntrance ? 0 : 28)
        .opacity(showPersonalEntrance ? 1 : 0)
        .scaleEffect(showPersonalEntrance ? 1.0 : 0.985)
        .animation(.spring(response: 0.44, dampingFraction: 0.86), value: showPersonalEntrance)
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
            .padding(10)
            .background(sectionCardBackground)
        }
        .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 6, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    var summarySection: some View {
        Section {
            daySummaryCard
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 12, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    var eventsSection: some View {
        Section {
            let now = currentMinuteOfDay()

            ForEach(Array(eventsForDay.enumerated()), id: \.element.id) { index, ev in
                AnyView(
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
                    .offset(y: showPersonalEventCards ? 0 : CGFloat(24 + index * 10))
                    .opacity(showPersonalEventCards ? 1 : 0)
                    .scaleEffect(showPersonalEventCards ? 1 : 0.985)
                    .animation(
                        .spring(response: 0.48, dampingFraction: 0.86)
                            .delay(Double(index) * 0.05),
                        value: showPersonalEventCards
                    )
                )
            }
        }
    }

    var daySummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 10) {
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
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundStyle(.green)

                    Text("\(live.title) şu an devam ediyor")
                        .font(.caption.weight(.semibold))

                    Spacer()

                    Text(timeText(for: live))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.12))
                )
            }

            if let indicator = currentTimeIndicatorText {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animateSummary ? 1.15 : 0.9)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: animateSummary)

                    Text(indicator)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.10))
                )
            }
        }
        .padding(18)
        .background(sectionCardBackground)
        .scaleEffect(animateSummary ? 1.01 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: animateSummary)
    }

    func summaryChip(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
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
