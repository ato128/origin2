//
//  FriendChatInfoView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 15.03.2026.
//

import SwiftUI
import SwiftData

struct FriendChatInfoView: View {
    @Bindable var friend: Friend
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var session: SessionStore
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    @Query(sort: \EventItem.startMinute, order: .forward)
    private var allEvents: [EventItem]

    private let palette = ThemePalette()

    @State private var showSharedWeek = false
    @State private var isSavingShare = false
    @State private var shareMyWeek = false
    @State private var infoMessage: String?
    @State private var isLoadingShareState = true

    private var friendshipID: UUID? { friend.backendFriendshipID }
    private var friendUserID: UUID? { friend.backendUserID }

    private var canOpenSharedWeek: Bool {
        guard let friendshipID else { return false }
        return friendStore.incomingWeekSharesByFriendship[friendshipID]?.is_enabled == true
    }

    private var currentUserEvents: [EventItem] {
        guard let currentUserID = session.currentUser?.id.uuidString else { return [] }
        return allEvents.filter { $0.ownerUserID == currentUserID }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 18) {
                    topHeader
                    profileCard
                    actionsCard
                    settingsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard
                let friendshipID,
                let currentUserID = session.currentUser?.id,
                let friendUserID
            else { return }

            isLoadingShareState = true

            await friendStore.loadWeekShareStatus(
                friendshipID: friendshipID,
                currentUserID: currentUserID,
                friendUserID: friendUserID
            )

            let initialShareState =
                friendStore.outgoingWeekSharesByFriendship[friendshipID]?.is_enabled == true

            await MainActor.run {
                shareMyWeek = initialShareState
                isLoadingShareState = false
            }

            if initialShareState {
                await friendStore.setWeekShareEnabled(
                    friendshipID: friendshipID,
                    currentUserID: currentUserID,
                    friendUserID: friendUserID,
                    isEnabled: true,
                    events: currentUserEvents
                )

                await MainActor.run {
                    shareMyWeek =
                        friendStore.outgoingWeekSharesByFriendship[friendshipID]?.is_enabled == true
                }
            }
        }
        .onChange(of: allEvents.count) { _, _ in
            guard shareMyWeek else { return }
            guard !isSavingShare, !isLoadingShareState else { return }
            guard
                let friendshipID,
                let currentUserID = session.currentUser?.id,
                let friendUserID
            else { return }

            Task {
                await friendStore.setWeekShareEnabled(
                    friendshipID: friendshipID,
                    currentUserID: currentUserID,
                    friendUserID: friendUserID,
                    isEnabled: true,
                    events: currentUserEvents
                )

                await MainActor.run {
                    shareMyWeek =
                        friendStore.outgoingWeekSharesByFriendship[friendshipID]?.is_enabled == true
                }
            }
        }
        .sheet(isPresented: $showSharedWeek) {
            NavigationStack {
                SharedWeekView(friend: friend)
                    .environmentObject(friendStore)
                    .environmentObject(session)
            }
        }
        .alert("friend_info_alert_title", isPresented: Binding(
            get: { infoMessage != nil },
            set: { if !$0 { infoMessage = nil } }
        )) {
            Button("focus_ok", role: .cancel) { }
        } message: {
            Text(infoMessage ?? "")
        }
    }
}

private extension FriendChatInfoView {
    var topHeader: some View {
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

            Text("friend_info_title")
                .font(.headline)
                .foregroundStyle(palette.primaryText)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
    }

    var profileCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(hexColor(friend.colorHex).opacity(0.16))
                    .frame(width: 92, height: 92)

                Image(systemName: friend.avatarSymbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(hexColor(friend.colorHex))
            }

            VStack(spacing: 4) {
                Text(friend.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)

                HStack(spacing: 8) {
                    Circle()
                        .fill(friend.isOnline ? .green : .gray.opacity(0.6))
                        .frame(width: 8, height: 8)

                    Text(friend.isOnline ? "chat_online" : "friend_info_offline")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.secondaryText)
                }

                Text(friend.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(cardBackground)
    }

    var actionsCard: some View {
        VStack(spacing: 12) {
            Button {
                if canOpenSharedWeek {
                    showSharedWeek = true
                } else {
                    infoMessage = localizedFriendNotSharedWeek(friend.name)
                }
            } label: {
                actionRow(
                    title: String(localized: "friend_info_open_shared_week"),
                    subtitle: canOpenSharedWeek
                        ? String(localized: "friend_info_see_weekly_plan_together")
                        : String(localized: "friend_info_waiting_for_share"),
                    icon: "calendar"
                )
            }
            .buttonStyle(.plain)

            actionRow(
                title: String(localized: "friend_info_start_focus_together"),
                subtitle: String(localized: "friend_info_launch_shared_focus"),
                icon: "timer"
            )
        }
        .padding(18)
        .background(cardBackground)
    }

    var settingsCard: some View {
        VStack(spacing: 0) {
            Toggle(isOn: Binding(
                get: { shareMyWeek },
                set: { newValue in
                    guard
                        let friendshipID,
                        let currentUserID = session.currentUser?.id,
                        let friendUserID
                    else { return }

                    if isSavingShare || isLoadingShareState { return }

                    shareMyWeek = newValue
                    isSavingShare = true

                    Task {
                        await friendStore.setWeekShareEnabled(
                            friendshipID: friendshipID,
                            currentUserID: currentUserID,
                            friendUserID: friendUserID,
                            isEnabled: newValue,
                            events: currentUserEvents
                        )

                        await MainActor.run {
                            shareMyWeek =
                                friendStore.outgoingWeekSharesByFriendship[friendshipID]?.is_enabled == true
                            isSavingShare = false
                        }
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("friend_info_share_my_week")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primaryText)

                    Text("friend_info_let_friend_view_week")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
            }
            .tint(Color.accentColor)
            .padding(.vertical, 14)

            Divider()
                .overlay(palette.cardStroke)

            Toggle(isOn: $friend.isMuted) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("friend_info_mute_notifications")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primaryText)

                    Text("friend_info_stop_alerts_from_friend")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                }
            }
            .tint(Color.accentColor)
            .padding(.vertical, 14)

            Divider()
                .overlay(palette.cardStroke)

            Button(role: .destructive) {
            } label: {
                HStack {
                    Image(systemName: "bell.slash.fill")
                    Text("friend_info_clear_chat_later")
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .background(cardBackground)
    }

    func localizedFriendNotSharedWeek(_ name: String) -> String {
        if locale.language.languageCode?.identifier == "tr" {
            return "\(name) henüz haftasını seninle paylaşmadı."
        } else {
            return "\(name) has not shared their week with you yet."
        }
    }

    func actionRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryText)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryText)
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
