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
    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue

    private let palette = ThemePalette()

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

                        Text("Backend bağlantısı hazır. Bir sonraki adımda burada arkadaşının gerçek haftalık planını göstereceğiz.")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)

                        VStack(spacing: 12) {
                            sampleRow(title: "Math Lecture", time: "09:00 – 10:30")
                            sampleRow(title: "UI Study Session", time: "13:00 – 14:00")
                            sampleRow(title: "Physics Lab Prep", time: "18:00 – 19:00")
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

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }
}
