//
//  SharedWeekView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 21.03.2026.
//

import SwiftUI
import Combine

struct SharedWeekView: View {
    let friend: Friend

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var session: SessionStore
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    private let palette = ThemePalette()
    private let dayTitles = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]

    @State private var selectedDay: Int = 0
    @State private var now = Date()

    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var friendshipID: UUID? {
        friend.backendFriendshipID
    }

    private var friendUserID: UUID? {
        friend.backendUserID
    }

    private var sharedItems: [FriendWeekShareItemDTO] {
        guard let friendshipID else { return [] }

        let raw = friendStore.sharedWeekItemsByFriendship[friendshipID] ?? []

        return raw.sorted { a, b in
            if a.weekday != b.weekday {
                return a.weekday < b.weekday
            }
            return a.start_minute < b.start_minute
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 18) {
                    header
                    heroCard
                    statusCard
                    daySegment
                    pager
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .refreshable {
                await refreshSharedWeek()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            selectedDay = todayIndex()
        }
        .onReceive(timer) { value in
            now = value
        }
        .task {
            await refreshSharedWeek()

            guard
                let friendshipID,
                let currentUserID = session.currentUser?.id,
                let friendUserID
            else { return }

            friendStore.subscribeToSharedWeekItemsRealtime(
                friendshipID: friendshipID,
                ownerUserID: friendUserID,
                viewerUserID: currentUserID
            )
        }
        .onDisappear {
            friendStore.unsubscribeSharedWeekItemsRealtime()
        }
    }
}

private extension SharedWeekView {
    func refreshSharedWeek() async {
        guard
            let friendshipID,
            let currentUserID = session.currentUser?.id,
            let friendUserID
        else { return }

        await friendStore.loadSharedWeekItems(
            friendshipID: friendshipID,
            ownerUserID: friendUserID,
            viewerUserID: currentUserID
        )
    }

    var todayItems: [FriendWeekShareItemDTO] {
        sharedItemsForDay(todayIndex())
    }

    var liveItem: FriendWeekShareItemDTO? {
        todayItems.first { item in
            let start = item.start_minute
            let end = item.start_minute + item.duration_minute
            let nowMinute = currentMinuteOfDay()
            return nowMinute >= start && nowMinute < end
        }
    }

    var nextItem: FriendWeekShareItemDTO? {
        let nowMinute = currentMinuteOfDay()

        return todayItems
            .filter { $0.start_minute > nowMinute }
            .sorted { $0.start_minute < $1.start_minute }
            .first
    }

    func minutesUntilStart(_ item: FriendWeekShareItemDTO) -> Int {
        max(0, item.start_minute - currentMinuteOfDay())
    }

    func minutesLeft(_ item: FriendWeekShareItemDTO) -> Int {
        max(0, (item.start_minute + item.duration_minute) - currentMinuteOfDay())
    }

    var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 19, weight: .bold))
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

            Text("Shared Week")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
    }

    var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(friend.name)'s Shared Week")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Text("Swipe between days and see which class or event is live right now.")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(cardBackground)
    }

    var statusCard: some View {
        Group {
            if let liveItem {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.green.opacity(0.18))
                            .frame(width: 64, height: 64)

                        Image(systemName: "bolt.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.green)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("LIVE NOW")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.green.opacity(0.16))
                                )

                            Text("\(minutesLeft(liveItem)) dk kaldı")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.secondaryText)
                        }

                        Text(liveItem.title)
                            .font(.headline)
                            .foregroundStyle(palette.primaryText)

                        Text("\(dayTitles[todayIndex()]) • \(timeText(for: liveItem))")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                    }

                    Spacer()
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(palette.secondaryCardFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.green.opacity(0.28), lineWidth: 1)
                        )
                )
                .shadow(color: Color.green.opacity(0.18), radius: 16, y: 6)

            } else if let nextItem {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.orange.opacity(0.18))
                            .frame(width: 64, height: 64)

                        Image(systemName: "clock.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.orange)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("NEXT UP")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.orange.opacity(0.16))
                                )

                            Text("\(minutesUntilStart(nextItem)) dk sonra")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.secondaryText)
                        }

                        Text(nextItem.title)
                            .font(.headline)
                            .foregroundStyle(palette.primaryText)

                        Text("\(dayTitles[todayIndex()]) • \(timeText(for: nextItem))")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                    }

                    Spacer()
                }
                .padding(18)
                .background(cardBackground)
            }
        }
    }

    var daySegment: some View {
        HStack(spacing: 10) {
            ForEach(0..<7, id: \.self) { day in
                let isSelected = selectedDay == day
                let isToday = todayIndex() == day

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        selectedDay = day
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(dayTitles[day])
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? palette.primaryText : palette.secondaryText)

                        if isToday {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 6, height: 6)
                        } else {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                isSelected
                                ? Color.accentColor.opacity(0.16)
                                : palette.secondaryCardFill
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                isSelected ? Color.accentColor.opacity(0.28) : palette.cardStroke,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(cardBackground)
    }

    var pager: some View {
        TabView(selection: $selectedDay) {
            ForEach(0..<7, id: \.self) { day in
                dayPage(day: day)
                    .tag(day)
                    .padding(.top, 2)
                    .padding(.bottom, 12)
                    .padding(.horizontal, 2)
            }
        }
        .frame(minHeight: 420)
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    func dayPage(day: Int) -> some View {
        let items = uniqueItems(sharedItemsForDay(day))

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(dayTitles[day])
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.primaryText)

                Spacer()

                Text("\(items.count) event")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryText)
            }

            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.accentColor)

                    Text("No shared events")
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)

                    Text("There is no event shared for \(dayTitles[day]).")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(cardBackground)
            } else {
                ForEach(items) { item in
                    eventRow(item, day: day)
                }
            }
        }
    }

    func eventRow(_ item: FriendWeekShareItemDTO, day: Int) -> some View {
        let isLive = isLiveEvent(item, day: day)

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isLive
                        ? Color.green.opacity(0.18)
                        : Color.accentColor.opacity(0.14)
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: isLive ? "bolt.fill" : "calendar")
                    .font(.headline)
                    .foregroundStyle(isLive ? .green : Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(palette.primaryText)

                    if isLive {
                        Text("LIVE")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.16))
                            )
                    }
                }

                Text("\(dayTitles[day]) • \(timeText(for: item))")
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)

                if let details = item.details,
                   !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(2)
                }

                if isLive {
                    Text(liveStatusText(for: item))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.secondaryCardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            isLive ? Color.green.opacity(0.30) : palette.cardStroke,
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: isLive ? Color.green.opacity(0.18) : .clear,
            radius: isLive ? 16 : 0,
            y: 6
        )
    }

    func sharedItemsForDay(_ day: Int) -> [FriendWeekShareItemDTO] {
        sharedItems.filter { $0.weekday == day }
    }

    func uniqueItems(_ items: [FriendWeekShareItemDTO]) -> [FriendWeekShareItemDTO] {
        var seen = Set<String>()
        var result: [FriendWeekShareItemDTO] = []

        for item in items {
            let key = "\(item.title)-\(item.weekday)-\(item.start_minute)-\(item.duration_minute)"

            if !seen.contains(key) {
                seen.insert(key)
                result.append(item)
            }
        }

        return result
    }

    func isLiveEvent(_ item: FriendWeekShareItemDTO, day: Int) -> Bool {
        guard todayIndex() == day else { return false }

        let nowMinute = currentMinuteOfDay()
        let end = item.start_minute + item.duration_minute

        return nowMinute >= item.start_minute && nowMinute < end
    }

    func liveStatusText(for item: FriendWeekShareItemDTO) -> String {
        let end = item.start_minute + item.duration_minute
        let left = max(0, end - currentMinuteOfDay())
        return "Active now • \(left) dk kaldı"
    }

    func timeText(for item: FriendWeekShareItemDTO) -> String {
        "\(hm(item.start_minute)) – \(hm(item.start_minute + item.duration_minute))"
    }

    func hm(_ minute: Int) -> String {
        let safe = max(0, minute)
        let h = safe / 60
        let m = safe % 60
        return String(format: "%02d:%02d", h, m)
    }

    func currentMinuteOfDay() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        let h = c.hour ?? 0
        let m = c.minute ?? 0
        return h * 60 + m
    }

    func todayIndex() -> Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday + 5) % 7
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
