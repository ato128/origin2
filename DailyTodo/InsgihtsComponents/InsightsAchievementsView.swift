//
//  InsightsAchievementsView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct InsightsAchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    let badges: [InsightsBadgeData]

    @State private var selectedBadge: InsightsBadgeData?
    @State private var selectedPath: AchievementPath?
    @State private var ringFilled = false

    private let accent = Color(arenaHex: AppArenaPalette.gold)

    private var unlocked: [InsightsBadgeData] {
        badges.filter(\.isUnlocked)
    }

    private var paths: [AchievementPath] {
        AchievementPathBuilder.build(from: badges)
    }

    private var activePaths: [AchievementPath] {
        paths.filter { !$0.isCompleted }
    }

    private var completedPaths: [AchievementPath] {
        paths.filter(\.isCompleted)
    }

    var body: some View {
        ZStack {
            ArenaBackground(
                primaryGlow: Color(arenaHex: AppArenaPalette.gold),
                secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
                warmGlow: Color(arenaHex: AppArenaPalette.coral),
                intensity: 0.94
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    summaryCard

                    if !activePaths.isEmpty {
                        sectionTitle("Aktif yollar", tr("ia_ongoing"))

                        VStack(spacing: 12) {
                            ForEach(activePaths) { path in
                                AchievementPathCard(
                                    path: path,
                                    onOpenPath: {
                                        selectedPath = path
                                    },
                                    onSelectBadge: { badge in
                                        selectedBadge = badge
                                    }
                                )
                            }
                        }
                    }

                    if !completedPaths.isEmpty {
                        sectionTitle("Tamamlanan yollar", tr("ia_completed"))

                        VStack(spacing: 12) {
                            ForEach(completedPaths) { path in
                                AchievementPathCard(
                                    path: path,
                                    onOpenPath: {
                                        selectedPath = path
                                    },
                                    onSelectBadge: { badge in
                                        selectedBadge = badge
                                    }
                                )
                            }
                        }
                    }

                    if !unlocked.isEmpty {
                        sectionTitle(tr("ia_earned"), tr("ia_unlocked_badges"))

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            ForEach(unlocked) { badge in
                                EarnedBadgeCard(badge: badge) {
                                    selectedBadge = badge
                                }
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedBadge) { badge in
            AchievementDetailSheet(badge: badge)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedPath) { path in
            AchievementPathDetailSheet(path: path) { badge in
                selectedBadge = badge
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(accent)
                        .frame(width: 20, height: 1)

                    Text("ACHIEVEMENT PATHS")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .tracking(2.3)
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("Achievements")
                        .font(.system(size: 37, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text("map")
                        .font(.system(size: 34, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(arenaHex: AppArenaPalette.gold),
                                    Color(arenaHex: AppArenaPalette.coral)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text(tr("ia_subtitle"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(2)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.095),
                                        Color.white.opacity(0.045)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.11), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.24), radius: 12, y: 6)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(accent)
                        .frame(width: 18, height: 1)

                    Text("PROGRESS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.7)
                        .foregroundStyle(accent)
                }

                Text(tr("ia_unlocked_n", unlocked.count))
                    .font(.system(size: 27, weight: .black))
                    .foregroundStyle(.white)

                Text("\(activePaths.count) aktif yol • \(badges.count) toplam rozet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineLimit(2)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.075), lineWidth: 10)
                    .frame(width: 82, height: 82)

                Circle()
                    .trim(from: 0, to: ringFilled ? totalProgress : 0)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(arenaHex: AppArenaPalette.gold),
                                Color(arenaHex: AppArenaPalette.coral),
                                Color(arenaHex: AppArenaPalette.purple)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 82, height: 82)
                    .onAppear {
                        guard !ringFilled else { return }
                        withAnimation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.2)) {
                            ringFilled = true
                        }
                    }

                VStack(spacing: 1) {
                    Text("\(paths.count)")
                        .font(.system(size: 25, weight: .black))
                        .foregroundStyle(.white)
                        .monospacedDigit()

                    Text("PATH")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }
        }
        .padding(18)
        .background(
            AchievementSurface(tint: accent, strength: 0.78, radius: 28)
        )
    }

    private var totalProgress: Double {
        guard !badges.isEmpty else { return 0 }
        let completed = badges.reduce(0.0) { partial, badge in
            partial + min(max(badge.progress ?? (badge.isUnlocked ? 1 : 0), 0), 1)
        }
        return min(max(completed / Double(badges.count), 0), 1)
    }

    private func sectionTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 18, height: 1)

                Text(title.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.36))
            }

            Text(subtitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.46))
        }
        .padding(.top, 4)
    }
}

private struct AchievementPath: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let badges: [InsightsBadgeData]

    var unlockedCount: Int {
        badges.filter(\.isUnlocked).count
    }

    var isCompleted: Bool {
        !badges.isEmpty && unlockedCount == badges.count
    }

    var currentBadge: InsightsBadgeData? {
        badges.first { !$0.isUnlocked } ?? badges.last
    }

    var nextBadge: InsightsBadgeData? {
        badges.first { !$0.isUnlocked }
    }

    var progress: Double {
        guard !badges.isEmpty else { return 0 }

        let total = badges.reduce(0.0) { partial, badge in
            partial + min(max(badge.progress ?? (badge.isUnlocked ? 1 : 0), 0), 1)
        }

        return min(max(total / Double(badges.count), 0), 1)
    }
}

private enum AchievementPathBuilder {
    static func build(from badges: [InsightsBadgeData]) -> [AchievementPath] {
        let focus = badges.filter { badge in
            let text = searchText(badge)
            return text.contains("focus") || text.contains("odak") || text.contains("deep")
        }

        let streak = badges.filter { badge in
            let text = searchText(badge)
            return text.contains("seri") || text.contains("streak") || text.contains(tr("hv_day_word"))
        }

        let task = badges.filter { badge in
            let text = searchText(badge)
            return text.contains("task") || text.contains(tr("task_lc")) || text.contains("weekly warrior")
        }

        let exam = badges.filter { badge in
            let text = searchText(badge)
            return text.contains("exam") || text.contains(tr("exam_lc"))
        }

        let usedIDs = Set((focus + streak + task + exam).map(\.id))
        let other = badges.filter { !usedIDs.contains($0.id) }

        return [
            AchievementPath(
                id: "focus",
                title: "Focus Path",
                subtitle: tr("ia_improve_focus"),
                icon: "timer",
                tint: Color(arenaHex: AppArenaPalette.cyan),
                badges: sorted(focus)
            ),
            AchievementPath(
                id: "streak",
                title: "Streak Path",
                subtitle: tr("ia_grow_streak"),
                icon: "flame.fill",
                tint: Color(arenaHex: AppArenaPalette.gold),
                badges: sorted(streak)
            ),
            AchievementPath(
                id: "task",
                title: "Task Path",
                subtitle: tr("ia_boost_completion"),
                icon: "checkmark.seal.fill",
                tint: Color(arenaHex: AppArenaPalette.green),
                badges: sorted(task)
            ),
            AchievementPath(
                id: "exam",
                title: "Exam Path",
                subtitle: tr("iv_strengthen_prep"),
                icon: "graduationcap.fill",
                tint: Color(arenaHex: AppArenaPalette.purple),
                badges: sorted(exam)
            ),
            AchievementPath(
                id: "other",
                title: "Special Path",
                subtitle: tr("ia_other"),
                icon: "sparkles",
                tint: Color(arenaHex: AppArenaPalette.coral),
                badges: sorted(other)
            )
        ]
        .filter { !$0.badges.isEmpty }
    }

    private static func searchText(_ badge: InsightsBadgeData) -> String {
        "\(badge.title) \(badge.subtitle) \(badge.icon)".lowercased()
    }

    private static func sorted(_ badges: [InsightsBadgeData]) -> [InsightsBadgeData] {
        badges.sorted {
            let lhs = $0.progress ?? ($0.isUnlocked ? 1 : 0)
            let rhs = $1.progress ?? ($1.isUnlocked ? 1 : 0)

            if $0.isUnlocked != $1.isUnlocked {
                return $0.isUnlocked && !$1.isUnlocked
            }

            return lhs > rhs
        }
    }
}

private struct AchievementPathCard: View {
    let path: AchievementPath
    let onOpenPath: () -> Void
    let onSelectBadge: (InsightsBadgeData) -> Void

    var body: some View {
        Button(action: onOpenPath) {
            VStack(alignment: .leading, spacing: 16) {
                top

                if let current = path.currentBadge {
                    HStack(spacing: 14) {
                        icon

                        VStack(alignment: .leading, spacing: 6) {
                            Text(current.isUnlocked ? "SON KAZANILAN" : tr("ia_next_goal_caps"))
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(path.tint)
                                .tracking(1.2)

                            Text(current.title)
                                .font(.system(size: 22, weight: .black))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)

                            Text(current.subtitle)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.52))
                                .lineLimit(1)
                        }

                        Spacer()

                        Text("\(Int(path.progress * 100))%")
                            .font(.system(size: 17, weight: .black, design: .monospaced))
                            .foregroundStyle(path.tint)
                    }
                }

                miniPathPreview

                progressBar(progress: path.progress)

                HStack {
                    Text(tr("ia_open_roadmap_caps"))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(path.tint)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(path.tint.opacity(0.80))
                }
            }
            .padding(16)
            .background(AchievementSurface(tint: path.tint, strength: 0.60, radius: 28))
        }
        .buttonStyle(.plain)
    }

    private var top: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(path.tint)
                        .frame(width: 16, height: 1)

                    Text(path.id.uppercased())
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(path.tint)
                }

                Text(path.title)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)

                Text(path.subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.48))
            }

            Spacer()

            Text("\(path.unlockedCount)/\(path.badges.count)")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(path.tint)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(
                    Capsule()
                        .fill(path.tint.opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(path.tint.opacity(0.18), lineWidth: 1)
                        )
                )
        }
    }

    private var icon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(path.tint.opacity(0.13))
                .frame(width: 56, height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(path.tint.opacity(0.16), lineWidth: 1)
                )

            Image(systemName: path.icon)
                .font(.system(size: 21, weight: .black))
                .foregroundStyle(path.tint)
        }
    }

    private var miniPathPreview: some View {
        HStack(spacing: 0) {
            ForEach(Array(path.badges.prefix(5).enumerated()), id: \.element.id) { index, badge in
                pathNode(badge)

                if index < min(path.badges.count, 5) - 1 {
                    pathConnector(isActive: badge.isUnlocked)
                }
            }

            if path.badges.count > 5 {
                Text("+\(path.badges.count - 5)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.48))
                    .padding(.leading, 8)
            }

            Spacer()
        }
        .padding(.top, 2)
    }

    private func pathNode(_ badge: InsightsBadgeData) -> some View {
        Button {
            onSelectBadge(badge)
        } label: {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked ? path.tint.opacity(0.22) : Color.white.opacity(0.075))
                    .frame(width: 34, height: 34)
                    .overlay(
                        Circle()
                            .stroke(badge.isUnlocked ? path.tint.opacity(0.18) : Color.white.opacity(0.07), lineWidth: 1)
                    )

                Image(systemName: badge.isUnlocked ? "checkmark" : badge.icon)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(badge.isUnlocked ? path.tint : .white.opacity(0.42))
            }
        }
        .buttonStyle(.plain)
    }

    private func pathConnector(isActive: Bool) -> some View {
        Rectangle()
            .fill(isActive ? path.tint.opacity(0.75) : Color.white.opacity(0.14))
            .frame(width: 34, height: 3)
    }

    private func progressBar(progress: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.075))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                path.tint,
                                Color(arenaHex: AppArenaPalette.cyan).opacity(0.86)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, proxy.size.width * min(max(progress, 0), 1)))
                    .shadow(color: path.tint.opacity(0.16), radius: 7, y: 2)
            }
        }
        .frame(height: 8)
    }
}

private struct EarnedBadgeCard: View {
    let badge: InsightsBadgeData
    let action: () -> Void

    /// One-shot gleam sweep on appear (not looping)
    @State private var gleamX: CGFloat = -1.6

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(badge.accent.opacity(0.13))
                            .frame(width: 38, height: 38)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(badge.accent.opacity(0.16), lineWidth: 1)
                            )

                        Image(systemName: badge.icon)
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(badge.accent)
                    }

                    Spacer()

                    Text("KAZANILDI")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(Color(arenaHex: AppArenaPalette.green))
                }

                Spacer(minLength: 0)

                Text(badge.title)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(badge.subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(2)

                Capsule()
                    .fill(Color(arenaHex: AppArenaPalette.green))
                    .frame(height: 6)
            }
            .padding(14)
            .frame(height: 154)
            .background(AchievementSurface(tint: badge.accent, strength: 0.55, radius: 24))
            .overlay {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.14),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .rotationEffect(.degrees(18))
                    .offset(x: geo.size.width * gleamX)
                    .blendMode(.plusLighter)
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .allowsHitTesting(false)
            }
            .onAppear {
                guard gleamX < 0 else { return }
                withAnimation(.easeInOut(duration: 0.9).delay(0.35)) {
                    gleamX = 1.6
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct AchievementSurface: View {
    let tint: Color
    let strength: Double
    let radius: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.075 + strength * 0.035),
                        Color(arenaHex: AppArenaPalette.purple).opacity(0.038),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                tint.opacity(0.10 + strength * 0.08),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: 155
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(tint.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 14, y: 7)
    }
}

private struct AchievementDetailSheet: View {
    let badge: InsightsBadgeData
    @Environment(\.dismiss) private var dismiss

    private var progress: Double {
        min(max(badge.progress ?? (badge.isUnlocked ? 1 : 0), 0), 1)
    }

    var body: some View {
        ZStack {
            ArenaBackground(
                primaryGlow: badge.accent,
                secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
                warmGlow: Color(arenaHex: AppArenaPalette.gold),
                intensity: 0.90
            )

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(badge.accent)
                            .frame(width: 18, height: 1)

                        Text("ACHIEVEMENT")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.8)
                            .foregroundStyle(badge.accent)
                    }

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.080))
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(badge.accent.opacity(0.13))
                            .frame(width: 58, height: 58)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(badge.accent.opacity(0.16), lineWidth: 1)
                            )

                        Image(systemName: badge.icon)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(badge.accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(badge.title)
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text(badge.isUnlocked ? tr("ia_earned_label") : tr("ia_not_done"))
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(badge.isUnlocked ? Color(arenaHex: AppArenaPalette.green) : .white.opacity(0.58))
                    }
                }

                Text(badge.subtitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(tr("ia_progress_caps"))
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.42))

                        Spacer()

                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(badge.isUnlocked ? Color(arenaHex: AppArenaPalette.green) : badge.accent)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.075))

                            Capsule()
                                .fill(badge.isUnlocked ? Color(arenaHex: AppArenaPalette.green) : badge.accent)
                                .frame(width: max(8, proxy.size.width * progress))
                        }
                    }
                    .frame(height: 8)
                }

                Spacer()
            }
            .padding(22)
        }
        .preferredColorScheme(.dark)
    }
}

private struct AchievementPathDetailSheet: View {
    let path: AchievementPath
    let onSelectBadge: (InsightsBadgeData) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ArenaBackground(
                primaryGlow: path.tint,
                secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
                warmGlow: Color(arenaHex: AppArenaPalette.gold),
                intensity: 0.92
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    hero
                    roadmap

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(path.tint)
                        .frame(width: 20, height: 1)

                    Text("PATH DETAIL")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(path.tint)
                }

                Text(path.title)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(.white)

                Text(path.subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.080))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(path.tint.opacity(0.13))
                        .frame(width: 62, height: 62)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(path.tint.opacity(0.16), lineWidth: 1)
                        )

                    Image(systemName: path.icon)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(path.tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("rel_done_of", path.unlockedCount, path.badges.count))
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)

                    Text(tr("ia_progress_next"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                }

                Spacer()

                Text("\(Int(path.progress * 100))%")
                    .font(.system(size: 21, weight: .black, design: .monospaced))
                    .foregroundStyle(path.tint)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.075))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    path.tint,
                                    Color(arenaHex: AppArenaPalette.cyan).opacity(0.86)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, proxy.size.width * path.progress))
                }
            }
            .frame(height: 9)
        }
        .padding(18)
        .background(AchievementSurface(tint: path.tint, strength: 0.70, radius: 28))
    }

    private var roadmap: some View {
        VStack(spacing: 0) {
            ForEach(Array(path.badges.enumerated()), id: \.element.id) { index, badge in
                roadmapNode(
                    badge: badge,
                    index: index,
                    isLast: index == path.badges.count - 1
                )
            }
        }
        .padding(.top, 4)
    }

    private func roadmapNode(
        badge: InsightsBadgeData,
        index: Int,
        isLast: Bool
    ) -> some View {
        let progress = min(max(badge.progress ?? (badge.isUnlocked ? 1 : 0), 0), 1)
        let isCurrent = !badge.isUnlocked && progress > 0
        let isLocked = !badge.isUnlocked && progress <= 0
        let nodeTint = badge.isUnlocked ? Color(arenaHex: AppArenaPalette.green) : path.tint

        return Button {
            onSelectBadge(badge)
        } label: {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(nodeTint.opacity(isCurrent ? 0.20 : 0.13))
                            .frame(width: isCurrent ? 72 : 58, height: isCurrent ? 72 : 58)

                        Circle()
                            .stroke(nodeTint.opacity(isCurrent ? 0.48 : 0.20), lineWidth: 1.4)
                            .frame(width: isCurrent ? 72 : 58, height: isCurrent ? 72 : 58)

                        Image(systemName: nodeIcon(badge: badge, isLocked: isLocked))
                            .font(.system(size: isCurrent ? 24 : 20, weight: .black))
                            .foregroundStyle(isLocked ? .white.opacity(0.38) : nodeTint)
                    }
                    .shadow(
                        color: isCurrent ? path.tint.opacity(0.26) : .clear,
                        radius: 18,
                        x: 0,
                        y: 10
                    )

                    if !isLast {
                        VStack(spacing: 5) {
                            ForEach(0..<5, id: \.self) { _ in
                                Capsule()
                                    .fill(badge.isUnlocked ? path.tint.opacity(0.65) : Color.white.opacity(0.13))
                                    .frame(width: 4, height: 10)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(statusText(badge: badge, isCurrent: isCurrent, isLocked: isLocked))
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(statusColor(badge: badge, isCurrent: isCurrent, isLocked: isLocked))

                        Spacer()

                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .foregroundStyle(statusColor(badge: badge, isCurrent: isCurrent, isLocked: isLocked))
                    }

                    Text(badge.title)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(badge.subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(2)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.075))

                            Capsule()
                                .fill(badge.isUnlocked ? Color(arenaHex: AppArenaPalette.green) : path.tint)
                                .frame(width: max(8, proxy.size.width * progress))
                        }
                    }
                    .frame(height: 7)
                }
                .padding(16)
                .background(
                    AchievementSurface(
                        tint: badge.isUnlocked ? Color(arenaHex: AppArenaPalette.green) : path.tint,
                        strength: isCurrent ? 0.70 : 0.44,
                        radius: 24
                    )
                )
                .padding(.top, isCurrent ? 0 : 6)
            }
        }
        .buttonStyle(.plain)
    }

    private func nodeIcon(badge: InsightsBadgeData, isLocked: Bool) -> String {
        if badge.isUnlocked { return "checkmark" }
        if isLocked { return "lock.fill" }
        return badge.icon
    }

    private func statusText(
        badge: InsightsBadgeData,
        isCurrent: Bool,
        isLocked: Bool
    ) -> String {
        if badge.isUnlocked { return "TAMAMLANDI" }
        if isCurrent { return tr("ia_next_goal_caps") }
        if isLocked { return tr("ia_locked_caps") }
        return "HEDEF"
    }

    private func statusColor(
        badge: InsightsBadgeData,
        isCurrent: Bool,
        isLocked: Bool
    ) -> Color {
        if badge.isUnlocked { return Color(arenaHex: AppArenaPalette.green) }
        if isCurrent { return path.tint }
        if isLocked { return .white.opacity(0.38) }
        return path.tint
    }
}
