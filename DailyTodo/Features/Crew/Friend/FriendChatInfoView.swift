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
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    private let palette = ThemePalette()

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

            Text("Friend Info")
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

                    Text(friend.isOnline ? "Online" : "Offline")
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
            actionRow(
                title: "Open Shared Week",
                subtitle: "See weekly plan together",
                icon: "calendar"
            )

            actionRow(
                title: "Start Focus Together",
                subtitle: "Launch a shared focus session",
                icon: "timer"
            )
        }
        .padding(18)
        .background(cardBackground)
    }

    var settingsCard: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $friend.isMuted) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Mute Notifications")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primaryText)

                    Text("Stop alerts from this friend")
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
                    Text("Clear Chat Later")
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
