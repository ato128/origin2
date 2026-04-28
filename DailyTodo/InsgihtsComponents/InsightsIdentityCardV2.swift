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
        snapshot.accent
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
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var topBar: some View {
        HStack {
            Text("IDENTITY")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(3)
                .foregroundStyle(accent)

            Spacer()

            Text("Lv \(snapshot.level)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    private var progressArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))
                        .frame(height: 10)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent,
                                    .white.opacity(0.82)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geo.size.width * min(max(snapshot.progress, 0), 1),
                            height: 10
                        )
                }
            }
            .frame(height: 10)

            HStack {
                Text(snapshot.levelRangeText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)

                Spacer()

                Text(snapshot.percentText)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.60))
            }
        }
    }

    private var bottomArea: some View {
        HStack {
            Text(hasPendingLevelUp ? "Yeni seviyeye geç" : snapshot.statusText)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(hasPendingLevelUp ? .green : .white.opacity(0.58))

            Spacer()

            Image(systemName: hasPendingLevelUp ? "arrow.up.forward.circle.fill" : "chevron.down")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(hasPendingLevelUp ? .green : .white.opacity(0.45))
        }
    }

    private var expandedArea: some View {
        VStack(spacing: 10) {
            Divider().overlay(.white.opacity(0.07))

            stat("Focus", "\(snapshot.focusSessions)/\(snapshot.nextRequirement.requiredFocusSessions)")
            stat("Tasks", "\(snapshot.completedTasks)/\(snapshot.nextRequirement.requiredCompletedTasks)")
            stat("Streak", "\(snapshot.streakDays)/\(snapshot.nextRequirement.requiredStreakDays)")
        }
        .padding(.top, 4)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.50))

            Spacer()

            Text(value)
                .foregroundStyle(.white)
                .fontWeight(.bold)
        }
        .font(.system(size: 13, design: .rounded))
    }

    private var bg: some View {
        ZStack {
            LinearGradient(
                colors: [
                    accent.opacity(0.30),
                    Color.purple.opacity(0.12),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    accent.opacity(0.22),
                    .clear
                ],
                center: .topTrailing,
                startRadius: 8,
                endRadius: 170
            )
        }
    }
}
