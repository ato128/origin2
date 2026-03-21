//
//  SharedWeekView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 21.03.2026.
//

import SwiftUI

struct SharedWeekView: View {
    let friend: Friend

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var session: SessionStore
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    private let palette = ThemePalette()

    private var friendshipID: UUID? { friend.backendFriendshipID }
    private var friendUserID: UUID? { friend.backendUserID }

    private var sharedItems: [FriendWeekShareItemDTO] {
        guard let friendshipID else { return [] }
        return friendStore.sharedWeekItemsByFriendship[friendshipID] ?? []
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 18) {
                    header

                    VStack(alignment: .leading, spacing: 16) {
                        Text("\(friend.name)'s Shared Week")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)

                        if sharedItems.isEmpty {
                            Text("Bu arkadaş henüz paylaşılmış hafta planı göndermedi.")
                                .font(.subheadline)
                                .foregroundStyle(palette.secondaryText)
                        } else {
                            ForEach(sharedItems) { item in
                                sampleRow(
                                    title: item.title,
                                    time: "\(dayText(item.weekday)) • \(hm(item.start_minute)) – \(hm(item.start_minute + item.duration_minute))"
                                )
                            }
                        }
                    }
                    .padding(20)
                    .background(cardBackground)
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
                let friendUserID,
                let currentUserID = session.currentUser?.id
            else { return }

            await friendStore.loadSharedWeekItems(
                friendshipID: friendshipID,
                ownerUserID: friendUserID,
                viewerUserID: currentUserID
            )
        }
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
                                Circle().stroke(palette.cardStroke, lineWidth: 1)
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

    func sampleRow(title: String, time: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.opacity(0.14))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.accentColor)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.primaryText)

                Text(time)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(palette.secondaryCardFill)
        )
    }

    func hm(_ minute: Int) -> String {
        let h = minute / 60
        let m = minute % 60
        return String(format: "%02d:%02d", h, m)
    }

    func dayText(_ weekday: Int) -> String {
        let days = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
        return days.indices.contains(weekday) ? days[weekday] : "?"
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
