//
//  InsightsIdentityCardV2.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsIdentityCardV2: View {
    let snapshot: IdentityLevelSnapshot
    let isExpanded: Bool
    let hasPendingLevelUp: Bool
    let onTap: () -> Void

    private var accent: Color {
        snapshot.currentRequirement.accent
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {

                topBar

                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.title)
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text("Level \(snapshot.level)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }

                progressArea

                bottomArea

                if isExpanded {
                    expandedArea
                }

            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    var topBar: some View {
        HStack {
            Text("IDENTITY")
                .font(.system(size: 11, weight: .black))
                .tracking(3)
                .foregroundStyle(accent)

            Spacer()

            Text("Lv \(snapshot.level)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    var progressArea: some View {
        VStack(alignment: .leading, spacing: 8) {

            GeometryReader { geo in
                ZStack(alignment: .leading) {

                    Capsule()
                        .fill(.white.opacity(0.08))
                        .frame(height: 10)

                    Capsule()
                        .fill(accent)
                        .frame(
                            width: geo.size.width * snapshot.progress,
                            height: 10
                        )
                }
            }
            .frame(height: 10)

            HStack {
                Text("Lv.\(snapshot.level) → Lv.\(snapshot.level + 1)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)

                Spacer()

                Text("\(Int(snapshot.progress * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    var bottomArea: some View {
        HStack {
            Text(hasPendingLevelUp ? "Yeni seviye hazır" : "İlerleme aktif")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(hasPendingLevelUp ? .green : .white.opacity(0.55))

            Spacer()

            Image(systemName: "chevron.down")
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    var expandedArea: some View {
        VStack(spacing: 10) {
            Divider().overlay(.white.opacity(0.07))

            stat("Focus", "\(snapshot.focusSessions)")
            stat("Tasks", "\(snapshot.completedTasks)")
            stat("Streak", "\(snapshot.streakDays)")
        }
        .padding(.top, 4)
    }

    func stat(_ title: String,_ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text(value)
                .foregroundStyle(.white)
                .fontWeight(.bold)
        }
        .font(.system(size: 13))
    }

    var bg: some View {
        LinearGradient(
            colors: [
                accent.opacity(0.28),
                Color.orange.opacity(0.12),
                Color.black
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
