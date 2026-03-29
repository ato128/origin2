//
//  CrewChatView+Header.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension CrewChatView {

    var ambientBackground: some View {
        ZStack(alignment: .topLeading) {
            AppBackground()

            if appTheme == AppTheme.gradient.rawValue {
                RadialGradient(
                    colors: [hexColor(crew.colorHex).opacity(0.14), Color.clear],
                    center: .topLeading,
                    startRadius: 30,
                    endRadius: 260
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [Color.blue.opacity(0.06), Color.clear],
                    center: .topTrailing,
                    startRadius: 60,
                    endRadius: 320
                )
                .ignoresSafeArea()
            }
        }
    }

    var floatingTopControls: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(glassCircleBackground)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 6)

            Button {
                showCrewInfo = true
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(hexColor(crew.colorHex).opacity(0.16))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: crew.icon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(hexColor(crew.colorHex))
                        )

                    VStack(alignment: .leading, spacing: 0) {
                        Text(crew.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text("Crew chat")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.66))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .frame(height: 52)
                .background(glassCapsuleBackground)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 320)

            Spacer(minLength: 6)

            Button {
                showCrewInfo = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(glassCircleBackground)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    func typingBanner(text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "ellipsis.message.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.72))

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(glassRoundedBackground(cornerRadius: 20))
        .padding(.horizontal, 16)
    }

    var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(hexColor(crew.colorHex).opacity(0.14))
                    .frame(width: 82, height: 82)

                Image(systemName: "person.3.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(hexColor(crew.colorHex))
            }

            Text("crew_chat_empty_title")
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.primaryText)

            Text("crew_chat_empty_subtitle")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryText)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
