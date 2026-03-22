//
//  MostBusyCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//
import SwiftUI

struct MostBusyDayCard: View {
    let data: MostBusyDayData

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @State private var isVisible = false

    private var hasBusyDay: Bool {
        !data.dayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !data.durationText.contains("0")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text(hasBusyDay ? "En yoğun günün" : "Henüz yoğun bir gün oluşmadı")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 42, height: 42)

                    Image(systemName: "calendar")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }

            Text(data.dayText)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.orange)

                Text(data.durationText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
            }

            Text(data.subtitle)
                .font(.system(size: 14))
                .foregroundStyle(palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if !hasBusyDay {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.accentColor)

                    Text("Etkinlik ve görev tamamladıkça bu alan netleşecek")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(Color.accentColor.opacity(0.14))
                )
                .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.985)
        .offset(y: isVisible ? 0 : 10)
        .animation(.spring(response: 0.46, dampingFraction: 0.86), value: isVisible)
        .animateWhenVisible($isVisible)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(palette.cardStroke, lineWidth: 1)
            )
    }
}
