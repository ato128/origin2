//
//  FriendDetailView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI
import SwiftData

private enum FriendDetailArenaPalette {
    static let backgroundTop = Color(arenaHex: "#05060D")
    static let backgroundMid = Color(arenaHex: "#070713")
    static let backgroundBottom = Color(arenaHex: "#07040C")

    static let blue = Color(arenaHex: "#1593FF")
    static let cyan = Color(arenaHex: "#2DD4FF")
    static let purple = Color(arenaHex: "#7C3AED")
    static let coral = Color(arenaHex: "#FF5A44")
    static let gold = Color(arenaHex: "#FBBF24")
    static let green = Color(arenaHex: "#A3E635")
    static let surface = Color(arenaHex: "#101118")

    static var appGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: "#1E6BFF"),
                Color(arenaHex: "#7C3AED")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct FriendDetailView: View {
    let friend: Friend

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var session: SessionStore

    @Query(sort: \SharedWeekItem.createdAt, order: .forward)
    private var allSharedItems: [SharedWeekItem]

    @Query(sort: \FriendFocusSession.startedAt, order: .reverse)
    private var allFocusSessions: [FriendFocusSession]

    @State private var showHero = false
    @State private var showSchedule = false
    @State private var showInsights = false
    @State private var showActions = false

    @State private var showRemoveFriendAlert = false
    @State private var isRemovingFriend = false

    private var friendshipID: UUID? {
        friend.backendFriendshipID
    }

    private var isBackendFriend: Bool {
        friend.backendFriendshipID != nil
    }

    private var backendMessages: [FriendChatMessageItem] {
        guard let friendshipID else { return [] }
        return friendStore.friendMessagesByFriendship[friendshipID] ?? []
    }

    private var messages: [FriendChatMessageItem] {
        isBackendFriend ? backendMessages : []
    }

    private var todaySchedule: [SharedWeekItem] {
        guard !isBackendFriend else { return [] }

        let today = weekdayIndexToday()

        return allSharedItems
            .filter { $0.friendID == friend.id && $0.weekday == today }
            .sorted { $0.startMinute < $1.startMinute }
    }

    private var weekCount: Int {
        allSharedItems.filter { $0.friendID == friend.id }.count
    }

    private var activeFocusSession: FriendFocusSession? {
        guard !isBackendFriend else { return nil }

        return allFocusSessions.first {
            $0.friendID == friend.id &&
            $0.isActive
        }
    }

    private var friendFocusSessions: [FriendFocusSession] {
        allFocusSessions.filter { $0.friendID == friend.id }
    }

    private var totalFocusMinutes: Int {
        friendFocusSessions.reduce(0) { $0 + $1.durationMinute }
    }

    private var weeklyFocusSessions: [FriendFocusSession] {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        return friendFocusSessions.filter {
            $0.startedAt >= weekAgo
        }
    }

    private var weeklyFocusCount: Int {
        weeklyFocusSessions.count
    }

    private var weeklyFocusMinutes: Int {
        weeklyFocusSessions.reduce(0) { $0 + $1.durationMinute }
    }

    private var longestFocusMinutes: Int {
        friendFocusSessions.map(\.durationMinute).max() ?? 0
    }

    private var lastFocusDate: Date? {
        friendFocusSessions.map(\.startedAt).max()
    }

    private var sharedScheduleCount: Int {
        todaySchedule.count
    }

    private var friendAccent: Color {
        Color(arenaHex: friend.colorHex)
    }

    private var isOnlineText: String {
        friend.isOnline
        ? String(localized: "chat_online")
        : String(localized: "friend_info_offline")
    }

    private var friendInsightLine: String {
        if let activeFocusSession {
            return localizedInFocusNow(activeFocusSession.durationMinute)
        }

        if weeklyFocusCount >= 4 {
            return !appLanguageIsEnglish()
            ? tr("fd_steady_rhythm")
            : "Looks consistent this week."
        }

        if let lastFocusDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.locale = Locale.current
            let relative = formatter.localizedString(for: lastFocusDate, relativeTo: Date())

            return !appLanguageIsEnglish()
            ? "Son odak: \(relative)"
            : "Last focus: \(relative)"
        }

        return !appLanguageIsEnglish()
        ? tr("fd_no_focus_data")
        : "No focus data yet."
    }

    var body: some View {
        ZStack(alignment: .top) {
            ambientBackground

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: 6)

                    customHeader

                    heroCard
                        .offset(y: showHero ? 0 : 18)
                        .opacity(showHero ? 1 : 0)
                        .scaleEffect(showHero ? 1 : 0.985)

                    todayScheduleCard
                        .offset(y: showSchedule ? 0 : 18)
                        .opacity(showSchedule ? 1 : 0)
                        .scaleEffect(showSchedule ? 1 : 0.985)

                    friendInsightsCard
                        .offset(y: showInsights ? 0 : 18)
                        .opacity(showInsights ? 1 : 0)
                        .scaleEffect(showInsights ? 1 : 0.985)

                    actionsCard
                        .offset(y: showActions ? 0 : 18)
                        .opacity(showActions ? 1 : 0)
                        .scaleEffect(showActions ? 1 : 0.985)

                    Color.clear.frame(height: 96)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 18)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            playEntrance()
        }
        .task {
            guard let friendshipID else { return }

            await friendStore.loadInitialMessages(
                for: friendshipID,
                currentUserID: session.currentUser?.id
            )

            await friendStore.markMessagesSeen(
                friendshipID: friendshipID,
                currentUserID: session.currentUser?.id
            )

            friendStore.subscribeToFriendMessagesRealtime(
                friendshipID: friendshipID,
                currentUserID: session.currentUser?.id
            )
        }
        .alert("crew_remove_friend_confirm_title", isPresented: $showRemoveFriendAlert) {
            Button(tr("crew_keep_friend"), role: .cancel) { }

            Button(tr("crew_remove"), role: .destructive) {
                Task {
                    await removeFriend()
                }
            }
        } message: {
            Text(tr("friend_detail_remove_message"))
        }
    }
}

// MARK: - Main UI

private extension FriendDetailView {
    var ambientBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    FriendDetailArenaPalette.backgroundTop,
                    FriendDetailArenaPalette.backgroundMid,
                    FriendDetailArenaPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(friendAccent.opacity(0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 105)
                .offset(x: -170, y: 480)

            Circle()
                .fill(FriendDetailArenaPalette.blue.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 96)
                .offset(x: 165, y: -245)

            Circle()
                .fill(FriendDetailArenaPalette.purple.opacity(0.14))
                .frame(width: 300, height: 300)
                .blur(radius: 110)
                .offset(x: 180, y: 260)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.16),
                    Color.clear,
                    Color.black.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    var customHeader: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left").accessibilityLabel(tr("a11y_back"))
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(Color.white.opacity(0.075))
                            .overlay(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 3) {
                Text(tr("fd_friend_space_caps"))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(FriendDetailArenaPalette.cyan)

                Text(friend.name)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer()

            Menu {
                NavigationLink {
                    FriendChatView(friend: friend)
                        .environmentObject(friendStore)
                        .environmentObject(session)
                } label: {
                    Label(tr("crew_chat"), systemImage: "message.fill")
                }

                Button(role: .destructive) {
                    showRemoveFriendAlert = true
                } label: {
                    Label(tr("crew_remove_friend"), systemImage: "person.crop.circle.badge.xmark")
                }
            } label: {
                ZStack {
                    if isRemovingFriend {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "ellipsis").accessibilityLabel(tr("a11y_more"))
                            .font(.system(size: 19, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(Color.white.opacity(0.075))
                        .overlay(
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
            }
            .disabled(isRemovingFriend)
        }
    }

    var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    friendAccent.opacity(0.90),
                                    FriendDetailArenaPalette.purple.opacity(0.82)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 74, height: 74)
                        .overlay(
                            Image(systemName: friend.avatarSymbol)
                                .font(.system(size: 30, weight: .black))
                                .foregroundStyle(.white)
                        )

                    Circle()
                        .fill(friend.isOnline ? FriendDetailArenaPalette.green : Color.gray.opacity(0.65))
                        .frame(width: 15, height: 15)
                        .overlay(
                            Circle()
                                .stroke(FriendDetailArenaPalette.surface, lineWidth: 3)
                        )
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(activeFocusSession != nil ? FriendDetailArenaPalette.green : friendAccent)
                            .frame(width: 8, height: 8)

                        Text(activeFocusSession != nil ? "LIVE FOCUS" : "SOCIAL FRIEND")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundStyle(activeFocusSession != nil ? FriendDetailArenaPalette.green : FriendDetailArenaPalette.cyan)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(friend.name)
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)

                        Text("friend")
                            .font(.system(size: 25, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(FriendDetailArenaPalette.cyan)
                    }

                    Text(friend.subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        statusPill(
                            text: isOnlineText,
                            tint: friend.isOnline ? FriendDetailArenaPalette.green : .gray
                        )

                        if isBackendFriend {
                            statusPill(
                                text: "Connected",
                                tint: FriendDetailArenaPalette.blue
                            )
                        }
                    }
                }

                Spacer()
            }

            if let activeFocusSession {
                HStack(spacing: 10) {
                    Image(systemName: "timer")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(FriendDetailArenaPalette.green)

                    Text(localizedInFocusNow(activeFocusSession.durationMinute))
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(FriendDetailArenaPalette.green)

                    Spacer()
                }
                .padding(12)
                .background(detailSurface(cornerRadius: 18, tint: FriendDetailArenaPalette.green))
            }

            HStack(spacing: 10) {
                statPill(
                    value: "\(weekCount)",
                    title: localizedThisWeek(weekCount),
                    tint: friendAccent
                )

                statPill(
                    value: "\(todaySchedule.count)",
                    title: localizedToday(todaySchedule.count),
                    tint: FriendDetailArenaPalette.green
                )

                statPill(
                    value: "\(messages.count)",
                    title: localizedMessages(messages.count),
                    tint: FriendDetailArenaPalette.blue
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            friendAccent.opacity(0.13),
                            FriendDetailArenaPalette.purple.opacity(0.11),
                            FriendDetailArenaPalette.surface.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(friendAccent.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 20, y: 12)
        )
    }

    var todayScheduleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle(
                    eyebrow: tr("fd_today_plan_caps"),
                    title: tr("fd_todays"),
                    italic: "program"
                )

                Spacer()

                Text(localizedScheduleCount(todaySchedule.count))
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(FriendDetailArenaPalette.green)
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background(
                        Capsule()
                            .fill(FriendDetailArenaPalette.green.opacity(0.12))
                    )
            }

            if todaySchedule.isEmpty {
                emptyMiniState(
                    icon: "calendar",
                    text: String(localized: "friend_detail_no_schedule_today"),
                    tint: FriendDetailArenaPalette.cyan
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(todaySchedule) { item in
                        scheduleRow(item)
                    }
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var friendInsightsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                eyebrow: tr("fd_study_profile_caps"),
                title: tr("tt_study"),
                italic: "profili"
            )

            HStack(spacing: 10) {
                insightStatCard(
                    value: "\(totalFocusMinutes)",
                    title: !appLanguageIsEnglish() ? "Toplam dk" : "Total min",
                    tint: friendAccent
                )

                insightStatCard(
                    value: "\(weeklyFocusCount)",
                    title: !appLanguageIsEnglish() ? "Bu hafta" : "This week",
                    tint: FriendDetailArenaPalette.blue
                )

                insightStatCard(
                    value: "\(longestFocusMinutes)",
                    title: !appLanguageIsEnglish() ? "En uzun" : "Longest",
                    tint: FriendDetailArenaPalette.green
                )
            }

            HStack(spacing: 10) {
                miniInsightPill(
                    icon: "calendar",
                    text: !appLanguageIsEnglish()
                    ? tr("fd_today_plans", sharedScheduleCount)
                    : "\(sharedScheduleCount) today items",
                    tint: FriendDetailArenaPalette.coral
                )

                miniInsightPill(
                    icon: "timer",
                    text: !appLanguageIsEnglish()
                    ? "\(weeklyFocusMinutes) dk hafta"
                    : "\(weeklyFocusMinutes) min week",
                    tint: FriendDetailArenaPalette.purple
                )
            }

            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(FriendDetailArenaPalette.gold)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(FriendDetailArenaPalette.gold.opacity(0.13))
                    )

                Text(friendInsightLine)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(2)

                Spacer()
            }
            .padding(14)
            .background(detailSurface(cornerRadius: 22, tint: FriendDetailArenaPalette.gold))
        }
        .padding(18)
        .background(cardBackground)
    }

    var actionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                eyebrow: tr("fd_social_actions_caps"),
                title: tr("bctd_quick_w"),
                italic: tr("bctd_actions_w")
            )

            HStack(spacing: 10) {
                NavigationLink {
                    FriendChatView(friend: friend)
                        .environmentObject(friendStore)
                        .environmentObject(session)
                } label: {
                    actionTile(
                        title: !appLanguageIsEnglish() ? "Sohbet" : "Chat",
                        systemImage: "message.fill",
                        tint: FriendDetailArenaPalette.blue,
                        filled: true
                    )
                }
                .buttonStyle(.plain)

                actionTile(
                    title: !appLanguageIsEnglish() ? "Profil" : "Profile",
                    systemImage: "person.crop.circle.fill",
                    tint: friendAccent,
                    filled: false
                )

                actionTile(
                    title: activeFocusSession != nil
                    ? (!appLanguageIsEnglish() ? "Odakta" : "In Focus")
                    : (friend.isOnline ? "Online" : "Offline"),
                    systemImage: activeFocusSession != nil ? "timer" : (friend.isOnline ? "circle.fill" : "moon.fill"),
                    tint: activeFocusSession != nil ? FriendDetailArenaPalette.green : friendAccent,
                    filled: false
                )
            }

            Button(role: .destructive) {
                showRemoveFriendAlert = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.system(size: 15, weight: .black))

                    Text(String(localized: "crew_remove_friend"))
                        .font(.system(size: 13, weight: .black))

                    Spacer()
                }
                .foregroundStyle(FriendDetailArenaPalette.coral)
                .padding(14)
                .background(detailSurface(cornerRadius: 20, tint: FriendDetailArenaPalette.coral))
            }
            .buttonStyle(.plain)
            .disabled(isRemovingFriend)
        }
        .padding(18)
        .background(cardBackground)
    }
}

// MARK: - Components

private extension FriendDetailView {
    func scheduleRow(_ item: SharedWeekItem) -> some View {
        HStack(spacing: 13) {
            Image(systemName: "calendar")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(friendAccent)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(friendAccent.opacity(0.13))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(hm(item.startMinute)) – \(hm(item.startMinute + item.durationMinute))")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.42))
            }

            Spacer()
        }
        .padding(14)
        .background(detailSurface(cornerRadius: 22, tint: friendAccent))
    }

    func actionTile(title: String, systemImage: String, tint: Color, filled: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .black))

            Text(title)
                .font(.system(size: 11, weight: .black))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(filled ? .black : tint)
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(filled ? tint : tint.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(tint.opacity(filled ? 0 : 0.20), lineWidth: 1)
                )
        )
    }

    func statPill(value: String, title: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 21, weight: .black))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)

            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.38))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 70)
        .background(detailSurface(cornerRadius: 18, tint: tint))
    }

    func insightStatCard(value: String, title: String, tint: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)

            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(detailSurface(cornerRadius: 18, tint: tint))
    }

    func miniInsightPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))

            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
        }
        .font(.system(size: 11, weight: .black, design: .monospaced))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        )
    }

    func statusPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.18), lineWidth: 1)
                    )
            )
            .lineLimit(1)
    }

    func emptyMiniState(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(tint.opacity(0.13))
                )

            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.50))
                .lineLimit(2)

            Spacer()
        }
        .padding(14)
        .background(detailSurface(cornerRadius: 22, tint: tint))
    }

    func sectionTitle(eyebrow: String, title: String, italic: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("— \(eyebrow) —")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.34))
                .lineLimit(1)
                .minimumScaleFactor(0.60)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)

                Text(italic)
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.white)
            }
        }
    }

    func detailSurface(cornerRadius: CGFloat, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.055),
                        FriendDetailArenaPalette.purple.opacity(0.040),
                        Color.white.opacity(0.038)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 14, y: 8)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        FriendDetailArenaPalette.blue.opacity(0.035),
                        FriendDetailArenaPalette.purple.opacity(0.045),
                        Color.white.opacity(0.040)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }
}

// MARK: - Helpers

private extension FriendDetailView {
    func playEntrance() {
        showHero = false
        showSchedule = false
        showInsights = false
        showActions = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                showHero = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                showSchedule = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                showInsights = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.86)) {
                showActions = true
            }
        }
    }

    @MainActor
    func removeFriend() async {
        guard let friendshipID = friendshipID,
              let currentUserID = session.currentUser?.id else { return }

        isRemovingFriend = true

        do {
            try await friendStore.removeFriendship(
                friendshipID: friendshipID,
                currentUserID: currentUserID,
                modelContext: modelContext
            )
            dismiss()
        } catch {
            Log.debug("REMOVE FRIEND ALERT ACTION ERROR:", error.localizedDescription)
        }

        isRemovingFriend = false
    }

    func localizedThisWeek(_ count: Int) -> String {
        !appLanguageIsEnglish() ? "Bu Hafta" : "This Week"
    }

    func localizedToday(_ count: Int) -> String {
        !appLanguageIsEnglish() ? tr("common_today") : "Today"
    }

    func localizedMessages(_ count: Int) -> String {
        !appLanguageIsEnglish() ? "Mesajlar" : "Messages"
    }

    func localizedInFocusNow(_ minutes: Int) -> String {
        !appLanguageIsEnglish()
        ? "\(tr("fd_focusing_now")) • \(tr("rel_min_short_n", minutes))"
        : "In focus now • \(minutes) min"
    }

    func localizedScheduleCount(_ count: Int) -> String {
        !appLanguageIsEnglish()
        ? tr("fd_item_count", count)
        : "\(count) items"
    }

    func weekdayIndexToday() -> Int {
        let w = Calendar.current.component(.weekday, from: Date())
        return (w + 5) % 7
    }

    func hm(_ minute: Int) -> String {
        let m = max(0, min(1439, minute))
        let h = m / 60
        let mm = m % 60
        return String(format: "%02d:%02d", h, mm)
    }
}

// MARK: - Color Hex
