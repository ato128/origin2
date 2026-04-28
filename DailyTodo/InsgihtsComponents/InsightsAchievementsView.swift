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

    private let accent = Color(red: 0.56, green: 0.36, blue: 1.00)

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
            Color.black.ignoresSafeArea()
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    summaryCard

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

                    if !completedPaths.isEmpty {
                        sectionTitle("Tamamlanan yollar", "Bitirdiğin gelişim serileri")

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
                        sectionTitle("Kazanılanlar", "Açtığın rozetler")

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
                .padding(.top, 14)
                .padding(.bottom, 24)
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
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Achievements")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("Kategori bazlı gelişim yolları")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var summaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("PROGRESS")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)
                    .tracking(1.4)

                Text("\(unlocked.count) kazanıldı")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(activePaths.count) aktif yol • \(badges.count) toplam rozet")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(accent.opacity(0.16))
                    .frame(width: 78, height: 78)

                Circle()
                    .stroke(.white.opacity(0.10), lineWidth: 1)
                    .frame(width: 78, height: 78)

                VStack(spacing: 1) {
                    Text("\(paths.count)")
                        .font(.system(size: 27, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("path")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
        }
        .padding(18)
        .background(
            AchievementSurface(tint: accent, strength: 0.76, radius: 28)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        )
    }

    private func sectionTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 23, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 12, weight: .bold, design: .rounded))
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
            return text.contains("seri") || text.contains("streak") || text.contains("gün")
        }

        let task = badges.filter { badge in
            let text = searchText(badge)
            return text.contains("task") || text.contains("görev") || text.contains("weekly warrior")
        }

        let exam = badges.filter { badge in
            let text = searchText(badge)
            return text.contains("exam") || text.contains("sınav")
        }

        let usedIDs = Set((focus + streak + task + exam).map(\.id))

        let other = badges.filter { !usedIDs.contains($0.id) }

        return [
            AchievementPath(
                id: "focus",
                title: "Focus Path",
                subtitle: "Odak oturumlarını geliştir",
                icon: "timer",
                tint: .blue,
                badges: sorted(focus)
            ),
            AchievementPath(
                id: "streak",
                title: "Streak Path",
                subtitle: "Düzenli çalışma serini büyüt",
                icon: "flame.fill",
                tint: .orange,
                badges: sorted(streak)
            ),
            AchievementPath(
                id: "task",
                title: "Task Path",
                subtitle: "Görev tamamlama ritmini artır",
                icon: "checkmark.seal.fill",
                tint: .green,
                badges: sorted(task)
            ),
            AchievementPath(
                id: "exam",
                title: "Exam Path",
                subtitle: "Sınav hazırlığını güçlendir",
                icon: "graduationcap.fill",
                tint: .purple,
                badges: sorted(exam)
            ),
            AchievementPath(
                id: "other",
                title: "Special Path",
                subtitle: "Diğer özel kazanımlar",
                icon: "sparkles",
                tint: .pink,
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
                            Text(current.isUnlocked ? "SON KAZANILAN" : "SIRADAKİ HEDEF")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(path.tint)
                                .tracking(1.2)

                            Text(current.title)
                                .font(.system(size: 23, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Text(current.subtitle)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.56))
                                .lineLimit(1)
                        }

                        Spacer()

                        Text("\(Int(path.progress * 100))%")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(path.tint)
                    }
                }

                miniPathPreview

                progressBar(progress: path.progress)

                HStack {
                    Text("Yol haritasını aç")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.white.opacity(0.42))
                }
            }
            .padding(16)
            .background(AchievementSurface(tint: path.tint, strength: 0.58, radius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var top: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(path.title)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(path.subtitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
            }

            Spacer()

            Text("\(path.unlockedCount)/\(path.badges.count)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(path.tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(path.tint.opacity(0.12), in: Capsule())
        }
    }

    private var icon: some View {
        ZStack {
            Circle()
                .fill(path.tint.opacity(0.18))
                .frame(width: 56, height: 56)

            Image(systemName: path.icon)
                .font(.system(size: 21, weight: .black))
                .foregroundStyle(.white)
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
                    .font(.system(size: 12, weight: .black, design: .rounded))
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
                    .fill(badge.isUnlocked ? path.tint.opacity(0.26) : .white.opacity(0.08))
                    .frame(width: 34, height: 34)

                Image(systemName: badge.isUnlocked ? "checkmark" : badge.icon)
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(badge.isUnlocked ? .white : .white.opacity(0.42))
            }
        }
        .buttonStyle(.plain)
    }

    private func pathConnector(isActive: Bool) -> some View {
        Rectangle()
            .fill(isActive ? path.tint.opacity(0.75) : .white.opacity(0.14))
            .frame(width: 34, height: 3)
    }

    private func progressBar(progress: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.08))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [path.tint, .white.opacity(0.86)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, proxy.size.width * min(max(progress, 0), 1)))
            }
        }
        .frame(height: 8)
    }
}

  

private struct EarnedBadgeCard: View {
    let badge: InsightsBadgeData
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(badge.accent.opacity(0.20))
                            .frame(width: 38, height: 38)

                        Image(systemName: badge.icon)
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Text("Kazanıldı")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                }

                Spacer(minLength: 0)

                Text(badge.title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(badge.subtitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(2)

                Capsule()
                    .fill(.green)
                    .frame(height: 6)
            }
            .padding(14)
            .frame(height: 154)
            .background(AchievementSurface(tint: badge.accent, strength: 0.55, radius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.065), lineWidth: 1)
            )
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
                        tint.opacity(0.16 + strength * 0.16),
                        tint.opacity(0.07),
                        Color(red: 0.10, green: 0.10, blue: 0.16).opacity(0.70),
                        Color(red: 0.035, green: 0.035, blue: 0.070)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RadialGradient(
                    colors: [
                        tint.opacity(0.14 + strength * 0.10),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 4,
                    endRadius: 150
                )
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
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
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Achievement")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(badge.accent)
                        .tracking(1.4)

                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(badge.accent.opacity(0.18))
                            .frame(width: 58, height: 58)

                        Image(systemName: badge.icon)
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(badge.title)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)

                        Text(badge.isUnlocked ? "Kazanıldı" : "Henüz tamamlanmadı")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(badge.isUnlocked ? .green : .white.opacity(0.58))
                    }
                }

                Text(badge.subtitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineSpacing(3)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("İlerleme")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.62))

                        Spacer()

                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(badge.isUnlocked ? .green : badge.accent)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.08))

                            Capsule()
                                .fill(badge.isUnlocked ? .green : badge.accent)
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
            Color.black.ignoresSafeArea()

            AchievementSurface(tint: path.tint, strength: 0.42, radius: 0)
                .ignoresSafeArea()
                .opacity(0.65)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
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
            VStack(alignment: .leading, spacing: 4) {
                Text(path.title)
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)

                Text(path.subtitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.08), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle()
                        .fill(path.tint.opacity(0.18))
                        .frame(width: 62, height: 62)

                    Image(systemName: path.icon)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(path.unlockedCount)/\(path.badges.count) tamamlandı")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Sıradaki hedefe ilerle ve yeni rozetleri aç.")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.56))
                }

                Spacer()

                Text("\(Int(path.progress * 100))%")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(path.tint)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [path.tint, .white.opacity(0.86)],
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
        .background(AchievementSurface(tint: path.tint, strength: 0.68, radius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
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

        return Button {
            onSelectBadge(badge)
        } label: {
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(nodeFill(badge: badge, isCurrent: isCurrent))
                            .frame(width: isCurrent ? 72 : 58, height: isCurrent ? 72 : 58)

                        Circle()
                            .stroke(nodeStroke(badge: badge, isCurrent: isCurrent), lineWidth: 1.4)
                            .frame(width: isCurrent ? 72 : 58, height: isCurrent ? 72 : 58)

                        Image(systemName: nodeIcon(badge: badge, isLocked: isLocked))
                            .font(.system(size: isCurrent ? 24 : 20, weight: .black))
                            .foregroundStyle(nodeIconColor(badge: badge, isLocked: isLocked))
                    }
                    .shadow(
                        color: isCurrent ? path.tint.opacity(0.35) : .clear,
                        radius: 18,
                        x: 0,
                        y: 10
                    )

                    if !isLast {
                        VStack(spacing: 5) {
                            ForEach(0..<5, id: \.self) { _ in
                                Capsule()
                                    .fill(badge.isUnlocked ? path.tint.opacity(0.65) : .white.opacity(0.13))
                                    .frame(width: 4, height: 10)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(statusText(badge: badge, isCurrent: isCurrent, isLocked: isLocked))
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(statusColor(badge: badge, isCurrent: isCurrent, isLocked: isLocked))

                        Spacer()

                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundStyle(statusColor(badge: badge, isCurrent: isCurrent, isLocked: isLocked))
                    }

                    Text(badge.title)
                        .font(.system(size: 23, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(badge.subtitle)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(2)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.08))

                            Capsule()
                                .fill(badge.isUnlocked ? .green : path.tint)
                                .frame(width: max(8, proxy.size.width * progress))
                        }
                    }
                    .frame(height: 7)
                }
                .padding(16)
                .background(
                    AchievementSurface(
                        tint: badge.isUnlocked ? .green : path.tint,
                        strength: isCurrent ? 0.70 : 0.40,
                        radius: 24
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(isCurrent ? 0.12 : 0.06), lineWidth: 1)
                )
                .padding(.top, isCurrent ? 0 : 6)
            }
        }
        .buttonStyle(.plain)
    }

    private func nodeFill(badge: InsightsBadgeData, isCurrent: Bool) -> Color {
        if badge.isUnlocked { return .green.opacity(0.22) }
        if isCurrent { return path.tint.opacity(0.25) }
        return .white.opacity(0.08)
    }

    private func nodeStroke(badge: InsightsBadgeData, isCurrent: Bool) -> Color {
        if badge.isUnlocked { return .green.opacity(0.45) }
        if isCurrent { return path.tint.opacity(0.70) }
        return .white.opacity(0.10)
    }

    private func nodeIcon(badge: InsightsBadgeData, isLocked: Bool) -> String {
        if badge.isUnlocked { return "checkmark" }
        if isLocked { return "lock.fill" }
        return badge.icon
    }

    private func nodeIconColor(badge: InsightsBadgeData, isLocked: Bool) -> Color {
        if badge.isUnlocked { return .white }
        if isLocked { return .white.opacity(0.38) }
        return .white
    }

    private func statusText(
        badge: InsightsBadgeData,
        isCurrent: Bool,
        isLocked: Bool
    ) -> String {
        if badge.isUnlocked { return "TAMAMLANDI" }
        if isCurrent { return "SIRADAKİ HEDEF" }
        if isLocked { return "KİLİTLİ" }
        return "HEDEF"
    }

    private func statusColor(
        badge: InsightsBadgeData,
        isCurrent: Bool,
        isLocked: Bool
    ) -> Color {
        if badge.isUnlocked { return .green }
        if isCurrent { return path.tint }
        if isLocked { return .white.opacity(0.38) }
        return path.tint
    }
}
