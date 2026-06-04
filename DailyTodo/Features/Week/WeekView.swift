//
//  WeekView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData
import UIKit
import Combine

// MARK: - WeekView (Apple Calendar Style, Personal Only)

struct WeekView: View {

    // MARK: Environment

    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale

    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var friendStore: FriendStore
    @EnvironmentObject private var studentStore: StudentStore

    @Query(sort: \EventItem.startMinute, order: .forward)
    private var allEvents: [EventItem]

    // MARK: State

    /// Şu an gösterilen tarih (sayfa). Swipe ile değişir.
    @State private var currentDate: Date = Date()

    /// Takvim sheet
    @State private var showCalendarSheet = false

    /// Add event sheet
    @State private var showingAdd = false
    @State private var editingEvent: EventItem? = nil

    /// Animasyon için
    @State private var pageDirection: Int = 0 // -1: geri, +1: ileri
    @State private var entranceShown = false

    /// Live timer (her dakika)
    private let liveTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var liveTick: Int = 0

    // MARK: Body

    var body: some View {
        ZStack {
            ArenaBackground(
                primaryGlow: heroAccent,
                secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
                warmGlow: Color(arenaHex: AppArenaPalette.cyan),
                intensity: 0.94
            )
            .animation(.easeInOut(duration: 0.45), value: heroAccent)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                dayPagedContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showCalendarSheet) {
            CalendarSheet(
                selectedDate: $currentDate,
                allEvents: userScopedEvents,
                onPick: { picked in
                    pageDirection = picked > currentDate ? 1 : -1
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        currentDate = picked
                    }
                    showCalendarSheet = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                AddEventView(
                    defaultWeekday: weekdayIndex(from: currentDate),
                    defaultDate: currentDate
                )
                .environmentObject(session)
                .environmentObject(friendStore)
                .environmentObject(studentStore)
            }
        }
        .sheet(item: $editingEvent) { event in
            NavigationStack {
                AddEventView(
                    defaultWeekday: event.weekday,
                    defaultDate: event.scheduledDate
                )
                .environmentObject(session)
                .environmentObject(friendStore)
                .environmentObject(studentStore)
            }
        }
        .onAppear {
            studentStore.reload()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                entranceShown = true
            }
        }
        .onReceive(liveTimer) { _ in
            liveTick &+= 1
        }
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack(spacing: 10) {
            // Takvim icon → modal
            Button {
                Haptics.impact(.light)
                showCalendarSheet = true
            } label: {
                circularIconButton(systemName: "calendar")
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            // Tarih + state label
            VStack(spacing: 2) {
                Text(eyebrowText)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [heroAccent, Color(arenaHex: AppArenaPalette.blue)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineLimit(1)

                Text(longDateText)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            // Navigasyon
            HStack(spacing: 6) {
                Button {
                    navigate(by: -1)
                } label: {
                    smallNavButton(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Button {
                    navigate(by: 1)
                } label: {
                    smallNavButton(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func circularIconButton(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .black))
            .foregroundStyle(Color(arenaHex: AppArenaPalette.cyan))
            .frame(width: 40, height: 40)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.095),
                                Color.white.opacity(0.045)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.11), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.24), radius: 10, y: 6)
            )
    }

    private func smallNavButton(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(Color.white.opacity(0.65))
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.045))
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
            )
    }

    // MARK: Paged Day Content

    private var dayPagedContent: some View {
        // Drag gesture ile sayfa geçişi
        ZStack {
            dayContent
                .id(dateKey(currentDate))
                .transition(
                    .asymmetric(
                        insertion: .move(edge: pageDirection >= 0 ? .trailing : .leading)
                            .combined(with: .opacity),
                        removal: .move(edge: pageDirection >= 0 ? .leading : .trailing)
                            .combined(with: .opacity)
                    )
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 22)
                .onEnded { value in
                    let threshold: CGFloat = 70
                    if value.translation.width < -threshold {
                        navigate(by: 1)
                    } else if value.translation.width > threshold {
                        navigate(by: -1)
                    }
                }
        )
    }

    @ViewBuilder
    private var dayContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                heroSection
                    .padding(.horizontal, 18)
                    .padding(.top, 12)

                statsRow
                    .padding(.horizontal, 18)

                if let active = activeEventNow {
                    activeBanner(active)
                        .padding(.horizontal, 18)
                }

                eventsList
                    .padding(.horizontal, 18)

                swipeIndicator
                    .padding(.top, 10)
                    .padding(.bottom, 110)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Hero

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Eyebrow
            HStack(spacing: 8) {
                Rectangle()
                    .fill(heroAccent)
                    .frame(width: 22, height: 1)

                Text(eyebrowText)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2.35)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [heroAccent, Color(arenaHex: AppArenaPalette.blue)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                if let count = heroEventCount {
                    Text("· \(count) DERS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(heroAccent.opacity(0.78))
                }
            }

            // Title
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(heroTitle)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                    .layoutPriority(1)

                Text(heroItalic)
                    .font(.system(size: 30, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                heroAccent,
                                Color(arenaHex: AppArenaPalette.purple)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }

            // Subtitle
            Text(heroSubtitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.50))
                .lineLimit(2)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Stats Row

    private var statsRow: some View {
        HStack(spacing: 8) {
            statChip(
                title: "TOPLAM",
                value: "\(eventsForCurrentDate.count)",
                suffix: "ders",
                tint: heroAccent
            )

            statChip(
                title: "TAMAM",
                value: "\(completedCount)",
                suffix: "/\(eventsForCurrentDate.count)",
                tint: Color(arenaHex: AppArenaPalette.green)
            )

            statChip(
                title: "SÜRE",
                value: hourValue,
                suffix: hourSuffix,
                tint: Color(arenaHex: AppArenaPalette.purple)
            )
        }
    }

    private func statChip(title: String, value: String, suffix: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Rectangle()
                    .fill(tint)
                    .frame(width: 14, height: 1)

                Text(title)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(tint)
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text(suffix)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.075))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(tint.opacity(0.16), lineWidth: 1)
                )
        )
    }

    // MARK: Active Banner

    private func activeBanner(_ event: EventItem) -> some View {
        let warm = Color(arenaHex: AppArenaPalette.coral)
        let now = currentMinuteOfDay()
        let left = max(0, (event.startMinute + event.durationMinute) - now)

        return HStack(spacing: 12) {
            Circle()
                .fill(warm)
                .frame(width: 8, height: 8)
                .shadow(color: warm.opacity(0.55), radius: 6)
                .overlay(
                    Circle()
                        .stroke(warm.opacity(0.35), lineWidth: 6)
                        .scaleEffect(1.8)
                        .opacity(0.4)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("ŞU AN · CANLI")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(warm)

                Text(event.title)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 2) {
                Text(timeRange(event))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))

                Text("\(left) dk kaldı")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(warm)
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            warm.opacity(0.18),
                            warm.opacity(0.07)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(warm.opacity(0.32), lineWidth: 1)
                )
                .shadow(color: warm.opacity(0.12), radius: 14, y: 7)
        )
    }

    // MARK: Events List

    @ViewBuilder
    private var eventsList: some View {
        if eventsForCurrentDate.isEmpty {
            emptyDayCard
        } else {
            VStack(spacing: 8) {
                ForEach(Array(eventsForCurrentDate.enumerated()), id: \.element.id) { idx, event in
                    eventRow(event, index: idx)
                }
            }
        }
    }

    private var emptyDayCard: some View {
        Button {
            Haptics.impact(.light)
            showingAdd = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(heroAccent.opacity(0.78))

                VStack(spacing: 4) {
                    Text(emptyTitle)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)

                    Text("Yeni ders veya etkinlik ekle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }

                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .black))

                    Text("EKLE")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(0.8)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(
                    Capsule()
                        .fill(heroAccent)
                        .shadow(color: heroAccent.opacity(0.30), radius: 10, y: 5)
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.025))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                Color.white.opacity(0.10),
                                style: StrokeStyle(lineWidth: 1, dash: [6, 5])
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func eventRow(_ event: EventItem, index: Int) -> some View {
        let now = currentMinuteOfDay()
        let start = event.startMinute
        let end = event.startMinute + event.durationMinute
        let isToday = Calendar.current.isDateInToday(currentDate)
        let isPast = (event.isCompleted) || (isToday && now >= end)
        let isActive = isToday && now >= start && now < end
        let isRecurring = (event.scheduledDate == nil)

        let tint = colorFromHex(event.colorHex)

        Button {
            editingEvent = event
        } label: {
            HStack(alignment: .center, spacing: 12) {
                // Time
                VStack(alignment: .center, spacing: 2) {
                    Text(hm(event.startMinute))
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(isActive ? Color(arenaHex: AppArenaPalette.coral) : .white.opacity(isPast ? 0.55 : 0.92))

                    Text("\(event.durationMinute)dk")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(isPast ? 0.32 : 0.45))
                }
                .frame(minWidth: 50)

                // Color stripe
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(isActive ? Color(arenaHex: AppArenaPalette.coral) : tint)
                    .frame(width: 3, height: isActive ? 40 : 32)

                // Content
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white.opacity(isPast ? 0.65 : 1))
                        .strikethrough(isPast)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let loc = event.location, !loc.isEmpty {
                            Text(loc)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.42))
                                .lineLimit(1)
                        }

                        if isActive {
                            Text("·")
                                .foregroundStyle(.white.opacity(0.32))

                            Text("\(max(0, end - now)) dk kaldı")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(Color(arenaHex: AppArenaPalette.coral))
                        }
                    }
                }

                Spacer(minLength: 4)

                // Right side: status or recur badge
                if isPast {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color(arenaHex: AppArenaPalette.green).opacity(0.85))
                } else if isActive {
                    Circle()
                        .fill(Color(arenaHex: AppArenaPalette.coral))
                        .frame(width: 8, height: 8)
                        .shadow(color: Color(arenaHex: AppArenaPalette.coral).opacity(0.55), radius: 6)
                } else if isRecurring {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 8, weight: .black))

                        Text("TEKRAR")
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .tracking(0.4)
                    }
                    .foregroundStyle(tint)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(
                        Capsule()
                            .fill(tint.opacity(0.14))
                            .overlay(
                                Capsule()
                                    .stroke(tint.opacity(0.22), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(12)
            .background(eventRowBackground(isPast: isPast, isActive: isActive, tint: tint))
            .opacity(isPast ? 0.62 : 1.0)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !event.isCompleted {
                Button {
                    markCompleted(event)
                } label: {
                    Label("Tamamlandı olarak işaretle", systemImage: "checkmark.circle")
                }
            }

            Button {
                editingEvent = event
            } label: {
                Label("Düzenle", systemImage: "pencil")
            }

            Button(role: .destructive) {
                delete(event)
            } label: {
                Label("Sil", systemImage: "trash")
            }
        }
        .opacity(entranceShown ? 1 : 0)
        .offset(y: entranceShown ? 0 : 18)
        .animation(
            .spring(response: 0.45, dampingFraction: 0.86).delay(Double(index) * 0.035),
            value: entranceShown
        )
    }

    private func eventRowBackground(isPast: Bool, isActive: Bool, tint: Color) -> some View {
        let bg: Color = {
            if isActive { return Color(arenaHex: AppArenaPalette.coral).opacity(0.10) }
            if isPast { return Color(arenaHex: AppArenaPalette.green).opacity(0.05) }
            return tint.opacity(0.06)
        }()

        let border: Color = {
            if isActive { return Color(arenaHex: AppArenaPalette.coral).opacity(0.30) }
            if isPast { return Color(arenaHex: AppArenaPalette.green).opacity(0.12) }
            return tint.opacity(0.18)
        }()

        return RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(bg)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
    }

    // MARK: Swipe Indicator

    private var swipeIndicator: some View {
        HStack(spacing: 12) {
            Image(systemName: "chevron.left")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white.opacity(0.32))

            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { i in
                    if i == 2 {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [heroAccent, Color(arenaHex: AppArenaPalette.blue)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 16, height: 4)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 4, height: 4)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white.opacity(0.32))
        }
        .frame(maxWidth: .infinity)
        .opacity(0.65)
    }

    // MARK: Actions

    private func navigate(by offset: Int) {
        Haptics.impact(.light)
        pageDirection = offset
        if let newDate = Calendar.current.date(byAdding: .day, value: offset, to: currentDate) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                currentDate = newDate
            }
        }
    }

    private func markCompleted(_ event: EventItem) {
        event.isCompleted = true

        do {
            try context.save()
            Haptics.impact(.medium)
            WidgetAppSync.refreshFromSwiftData(context: context)

            Task {
                await NotificationManager.shared.rescheduleAll(events: userScopedEvents)
            }

            Task {
                guard let userID = session.currentUser?.id else { return }
                await friendStore.resyncSharedWeekIfNeeded(for: userID, events: userScopedEvents)
            }
        } catch {
            print("markCompleted error:", error)
        }
    }

    private func delete(_ event: EventItem) {
        context.delete(event)

        do {
            try context.save()
            WidgetAppSync.refreshFromSwiftData(context: context)

            Task {
                await NotificationManager.shared.rescheduleAll(
                    events: userScopedEvents.filter { $0.id != event.id }
                )
            }

            Task {
                guard let userID = session.currentUser?.id else { return }
                await friendStore.resyncSharedWeekIfNeeded(for: userID, events: userScopedEvents)
            }
        } catch {
            print("WeekView.delete error:", error)
        }
    }
}

// MARK: - Computed Properties

private extension WeekView {

    var userScopedEvents: [EventItem] {
        guard let userID = session.currentUser?.id else { return [] }
        return allEvents.filter { $0.ownerUserID == userID.uuidString }
    }

    /// `currentDate` için olan etkinlikler (haftalık tekrar + tek seferlik)
    var eventsForCurrentDate: [EventItem] {
        let calendar = Calendar.current
        let weekday = weekdayIndex(from: currentDate)

        return userScopedEvents
            .filter { ev in
                if let scheduledDate = ev.scheduledDate {
                    return calendar.isDate(scheduledDate, inSameDayAs: currentDate)
                } else {
                    return ev.weekday == weekday
                }
            }
            .sorted { $0.startMinute < $1.startMinute }
    }

    var activeEventNow: EventItem? {
        guard Calendar.current.isDateInToday(currentDate) else { return nil }
        let now = currentMinuteOfDay()
        _ = liveTick // re-evaluate on tick
        return eventsForCurrentDate.first { ev in
            !ev.isCompleted && now >= ev.startMinute && now < (ev.startMinute + ev.durationMinute)
        }
    }

    var completedCount: Int {
        let now = currentMinuteOfDay()
        let isToday = Calendar.current.isDateInToday(currentDate)

        return eventsForCurrentDate.filter { ev in
            if ev.isCompleted { return true }
            if isToday && now >= (ev.startMinute + ev.durationMinute) { return true }
            return false
        }.count
    }

    var totalMinutes: Int {
        eventsForCurrentDate.reduce(0) { $0 + $1.durationMinute }
    }

    var hourValue: String {
        let h = totalMinutes / 60
        return "\(h)"
    }

    var hourSuffix: String {
        let m = totalMinutes % 60
        if totalMinutes == 0 { return "—" }
        if m == 0 { return "sa" }
        return "sa \(m)"
    }

    var heroAccent: Color {
        if activeEventNow != nil { return Color(arenaHex: AppArenaPalette.coral) }
        if isYesterday { return Color.white.opacity(0.4) }
        if isPastDay { return Color.white.opacity(0.4) }
        if isTomorrow { return Color(arenaHex: AppArenaPalette.purple) }
        if isToday { return Color(arenaHex: AppArenaPalette.cyan) }
        return Color(arenaHex: AppArenaPalette.blue)
    }

    var heroTitle: String {
        if eventsForCurrentDate.isEmpty {
            if isToday { return "Bugün" }
            if isTomorrow { return "Yarın" }
            return shortDayName
        }

        if let active = activeEventNow {
            return active.title
        }

        if isToday {
            if let next = nextEvent {
                return next.title
            }
            return "Bugün"
        }

        if eventsForCurrentDate.count == 1, let only = eventsForCurrentDate.first {
            return only.title
        }

        return "\(eventsForCurrentDate.count) ders"
    }

    var heroItalic: String {
        if eventsForCurrentDate.isEmpty {
            if isToday { return "sakin" }
            if isTomorrow { return "boş" }
            if isPastDay { return "geçti" }
            return "boş"
        }

        if activeEventNow != nil { return "aktif" }

        if isToday {
            if nextEvent != nil { return "sıradaki" }
            return "günü"
        }

        if isTomorrow { return "yarın" }

        return "günü"
    }

    var heroSubtitle: String {
        if eventsForCurrentDate.isEmpty {
            if isPastDay { return "Bu güne kayıt yok." }
            return "Bu güne yeni bir ders veya etkinlik ekle."
        }

        if let active = activeEventNow {
            let now = currentMinuteOfDay()
            let left = max(0, (active.startMinute + active.durationMinute) - now)
            return "\(active.title) aktif · \(left) dk kaldı"
        }

        if isToday, let next = nextEvent {
            let now = currentMinuteOfDay()
            let diff = next.startMinute - now
            if diff > 0 {
                return "Sıradaki: \(next.title) · \(diff) dk sonra"
            }
        }

        return "\(eventsForCurrentDate.count) ders · \(durationText(totalMinutes))"
    }

    var heroEventCount: Int? {
        guard !eventsForCurrentDate.isEmpty else { return nil }
        return eventsForCurrentDate.count
    }

    var nextEvent: EventItem? {
        guard isToday else { return nil }
        let now = currentMinuteOfDay()
        return eventsForCurrentDate.first { ev in
            !ev.isCompleted && ev.startMinute > now
        }
    }

    var eyebrowText: String {
        if activeEventNow != nil { return "ŞU AN · CANLI" }
        if isToday { return "BUGÜN" }
        if isTomorrow { return "YARIN" }
        if isYesterday { return "DÜN" }
        if isPastDay { return "GEÇMİŞ" }
        return "PROGRAM"
    }

    var longDateText: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEEE d MMM"
        return formatter.string(from: currentDate).capitalized
    }

    var shortDayName: String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "EEEE"
        return formatter.string(from: currentDate).capitalized
    }

    var emptyTitle: String {
        if isToday { return "Bugün sakin" }
        if isTomorrow { return "Yarın boş" }
        if isPastDay { return "Bu güne kayıt yok" }
        return "Boş gün"
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(currentDate)
    }

    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(currentDate)
    }

    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(currentDate)
    }

    var isPastDay: Bool {
        Calendar.current.startOfDay(for: currentDate) < Calendar.current.startOfDay(for: Date())
    }
}

// MARK: - Helpers

private extension WeekView {

    func weekdayIndex(from date: Date) -> Int {
        let w = Calendar.current.component(.weekday, from: date)
        return (w + 5) % 7
    }

    func currentMinuteOfDay() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    func hm(_ minute: Int) -> String {
        let m = max(0, min(1439, minute))
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    func timeRange(_ event: EventItem) -> String {
        "\(hm(event.startMinute))—\(hm(event.startMinute + event.durationMinute))"
    }

    func durationText(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m) dk" }
        if m == 0 { return "\(h) sa" }
        return "\(h)sa \(m)dk"
    }

    func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func colorFromHex(_ hex: String) -> Color {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        clean = clean.replacingOccurrences(of: "#", with: "")
        guard clean.count == 6 else { return Color(arenaHex: AppArenaPalette.blue) }

        var rgb: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&rgb)

        return Color(
            red: Double((rgb & 0xFF0000) >> 16) / 255,
            green: Double((rgb & 0x00FF00) >> 8) / 255,
            blue: Double(rgb & 0x0000FF) / 255
        )
    }
}

// MARK: - CalendarSheet

private struct CalendarSheet: View {

    @Binding var selectedDate: Date
    let allEvents: [EventItem]
    let onPick: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var displayMonth: Date = Date()

    var body: some View {
        ZStack {
            ArenaBackground(
                primaryGlow: Color(arenaHex: AppArenaPalette.cyan),
                secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
                warmGlow: Color(arenaHex: AppArenaPalette.blue),
                intensity: 0.84
            )

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 18) {
                        weekdayHeader
                            .padding(.horizontal, 18)
                            .padding(.top, 14)

                        monthGrid
                            .padding(.horizontal, 14)

                        legend
                            .padding(.horizontal, 18)
                            .padding(.top, 4)
                    }
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear {
            displayMonth = selectedDate
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            // Close
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            // Month nav
            HStack(spacing: 4) {
                Button {
                    Haptics.impact(.light)
                    if let d = Calendar.current.date(byAdding: .month, value: -1, to: displayMonth) {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                            displayMonth = d
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                VStack(spacing: 1) {
                    Text("TAKVİM")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(arenaHex: AppArenaPalette.cyan), Color(arenaHex: AppArenaPalette.blue)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    HStack(spacing: 5) {
                        Text(monthName)
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(.white)

                        Text(yearText)
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(arenaHex: AppArenaPalette.cyan), Color(arenaHex: AppArenaPalette.blue)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                }
                .frame(minWidth: 130)

                Button {
                    Haptics.impact(.light)
                    if let d = Calendar.current.date(byAdding: .month, value: 1, to: displayMonth) {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                            displayMonth = d
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.white.opacity(0.65))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 8)

            // Today
            Button {
                Haptics.impact(.light)
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    displayMonth = Date()
                }
                onPick(Date())
            } label: {
                Text("Bugün")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(Color(arenaHex: AppArenaPalette.cyan))
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(
                        Capsule()
                            .fill(Color(arenaHex: AppArenaPalette.cyan).opacity(0.14))
                            .overlay(
                                Capsule()
                                    .stroke(Color(arenaHex: AppArenaPalette.cyan).opacity(0.26), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(weekdaySymbols, id: \.self) { sym in
                Text(sym)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.42))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        let days = daysInMonthGrid()

        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                if let day = day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: 48)
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isToday = Calendar.current.isDateInToday(date)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let day = Calendar.current.component(.day, from: date)
        let isPastDay = Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date())
        let colors = eventColorsForDate(date)
        let hasSpecialEvent = hasOneTimeEventOn(date)

        return Button {
            Haptics.impact(.light)
            onPick(date)
        } label: {
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(
                        isToday
                            ? Color.white
                            : (isPastDay ? Color.white.opacity(0.55) : Color.white)
                    )
                    .monospacedDigit()

                HStack(spacing: 2) {
                    ForEach(colors.prefix(3), id: \.self) { hex in
                        Circle()
                            .fill(colorFromHex(hex))
                            .frame(width: 3.5, height: 3.5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                ZStack {
                    if isToday {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(arenaHex: AppArenaPalette.cyan),
                                        Color(arenaHex: AppArenaPalette.blue)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(arenaHex: AppArenaPalette.blue).opacity(0.28), radius: 8, y: 4)
                    } else if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                    } else if !colors.isEmpty {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.025))
                    }

                    if hasSpecialEvent && !isToday {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                Color(arenaHex: AppArenaPalette.coral).opacity(0.45),
                                lineWidth: 1
                            )
                    }
                }
            )
            .opacity(isPastDay && !isToday ? 0.65 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: Color(arenaHex: AppArenaPalette.cyan), text: "Bugün")
            legendItem(color: Color(arenaHex: AppArenaPalette.coral), text: "Özel")

            Spacer()

            Text("tap → gün")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.32))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.030))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)

            Text(text)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    // MARK: Helpers

    private var monthName: String {
        let f = DateFormatter()
        f.locale = locale
        f.dateFormat = "LLLL"
        return f.string(from: displayMonth).capitalized
    }

    private var yearText: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f.string(from: displayMonth)
    }

    private var weekdaySymbols: [String] {
        // Pazartesi başlangıç
        ["P", "S", "Ç", "P", "C", "C", "P"]
    }

    /// Grid'i Pazartesi başlangıçlı şekilde döndürür.
    private func daysInMonthGrid() -> [Date?] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: displayMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth))
        else { return [] }

        // First day of month — weekday index (0 = Monday)
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let firstIndex = (weekday + 5) % 7

        var result: [Date?] = Array(repeating: nil, count: firstIndex)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                result.append(date)
            }
        }

        // Pad to multiple of 7
        while result.count % 7 != 0 {
            result.append(nil)
        }

        return result
    }

    private func eventColorsForDate(_ date: Date) -> [String] {
        let calendar = Calendar.current
        let weekday = (calendar.component(.weekday, from: date) + 5) % 7

        let events = allEvents.filter { ev in
            if let scheduledDate = ev.scheduledDate {
                return calendar.isDate(scheduledDate, inSameDayAs: date)
            } else {
                return ev.weekday == weekday
            }
        }

        // Unique hex colors
        var seen = Set<String>()
        var result: [String] = []
        for ev in events {
            if !seen.contains(ev.colorHex) {
                seen.insert(ev.colorHex)
                result.append(ev.colorHex)
            }
        }

        return result
    }

    private func hasOneTimeEventOn(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return allEvents.contains { ev in
            if let scheduledDate = ev.scheduledDate {
                return calendar.isDate(scheduledDate, inSameDayAs: date)
            }
            return false
        }
    }

    private func colorFromHex(_ hex: String) -> Color {
        var clean = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        clean = clean.replacingOccurrences(of: "#", with: "")
        guard clean.count == 6 else { return Color(arenaHex: AppArenaPalette.blue) }

        var rgb: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&rgb)

        return Color(
            red: Double((rgb & 0xFF0000) >> 16) / 255,
            green: Double((rgb & 0x00FF00) >> 8) / 255,
            blue: Double(rgb & 0x0000FF) / 255
        )
    }
}
