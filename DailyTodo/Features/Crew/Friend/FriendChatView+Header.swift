//
//  FriendChatView+Header.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension FriendChatView {
    var ambientBackground: some View {
        ZStack(alignment: .topLeading) {
            AppBackground()

            if appTheme == AppTheme.gradient.rawValue {
                RadialGradient(
                    colors: [
                        hexColor(friend.colorHex).opacity(0.12),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 30,
                    endRadius: 240
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [
                        Color.blue.opacity(0.07),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 60,
                    endRadius: 280
                )
                .ignoresSafeArea()
            }
        }
    }

    var customHeader: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(palette.primaryText)
                    .frame(width: 52, height: 52)
                    .background(
                        Circle()
                            .fill(palette.cardFill)
                            .overlay(
                                Circle()
                                    .stroke(palette.cardStroke, lineWidth: 1)
                            )
                    )
                    .shadow(color: palette.shadowColor, radius: 10, y: 4)
            }
            .buttonStyle(.plain)

            Button {
                showFriendInfo = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(hexColor(friend.colorHex).opacity(0.16))
                            .frame(width: 42, height: 42)

                        Image(systemName: friend.avatarSymbol)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(hexColor(friend.colorHex))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(friend.name)
                            .font(.headline)
                            .foregroundStyle(palette.primaryText)

                        HStack(spacing: 6) {
                            Circle()
                                .fill(friend.isOnline ? .green : Color.gray.opacity(0.5))
                                .frame(width: 7, height: 7)

                            Text(friend.isOnline ? "Online" : "Offline")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(palette.secondaryText)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(palette.cardFill)
                .overlay(
                    Rectangle()
                        .fill(palette.cardStroke)
                        .frame(height: 0.8),
                    alignment: .bottom
                )
                .ignoresSafeArea(edges: .top)
        )
    }

    var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(hexColor(friend.colorHex).opacity(0.14))
                    .frame(width: 82, height: 82)

                Image(systemName: "message.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(hexColor(friend.colorHex))
            }

            Text("No messages yet")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.primaryText)

            Text("Start the conversation with \(friend.name).")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

}



