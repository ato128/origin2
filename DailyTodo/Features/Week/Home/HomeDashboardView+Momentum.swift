//
//  HomeDashboardView+Momentum.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 30.03.2026.
//

import SwiftUI

extension HomeDashboardView {
    var momentumCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bugünkü İlerleme")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .shadow(color: .white.opacity(0.04), radius: 2, y: 1)

                    Text(momentumCardSubtitle)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(2)

                    Text(momentumSubtitleText)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(momentumAccentColor.opacity(0.94))
                }

                Spacer()

                Button {
                    onOpenInsights()
                } label: {
                    HStack(spacing: 6) {
                        Text("İçgörüler")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .foregroundStyle(palette.primaryText)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(palette.secondaryCardFill.opacity(0.96))
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                shouldEmphasizeMomentumCard
                                ? momentumAccentColor.opacity(0.14)
                                : palette.cardStroke.opacity(0.88),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .bottom) {
                Text(momentumPercentageText)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(momentumAccentColor)
                    .monospacedDigit()
                    .shadow(color: momentumAccentColor.opacity(0.12), radius: 6)

                Spacer()

                Text("\(completedTodayBoardCount)/\(max(todayBoardTasks.count, 1))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    palette.secondaryCardFill.opacity(0.96),
                                    palette.secondaryCardFill.opacity(0.88)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    momentumAccentColor.opacity(0.92),
                                    momentumAccentColor.opacity(0.76)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(12, geo.size.width * boardTodayProgressValue))
                        .shadow(color: momentumAccentColor.opacity(0.20), radius: 8, y: 2)
                }
            }
            .frame(height: 12)

            HStack(spacing: 8) {
                smallStatsChip(title: "Seri", value: "\(streakCount)", tint: .orange)
                smallStatsChip(title: "Biten", value: "\(completedTodayBoardCount)", tint: .green)
                smallStatsChip(title: "Kalan", value: "\(todayPendingBoardCount)", tint: .blue)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(adaptiveMomentumBackground)
        .shadow(
            color: shouldEmphasizeMomentumCard ? momentumAccentColor.opacity(0.07) : .clear,
            radius: shouldEmphasizeMomentumCard ? 10 : 0,
            y: shouldEmphasizeMomentumCard ? 4 : 0
        )
    }

    var hasVisibleUpcomingExamMomentum: Bool {
        nearestRelevantExam != nil
    }

    var boardTodayProgressValue: CGFloat {
        guard !todayBoardTasks.isEmpty else { return 0 }
        let value = Double(completedTodayBoardCount) / Double(todayBoardTasks.count)
        return CGFloat(min(max(value, 0), 1))
    }

    var boardTodayRemainingCount: Int {
        max(todayBoardTasks.count - completedTodayBoardCount, 0)
    }

    var isDayEffectivelyComplete: Bool {
        !todayBoardTasks.isEmpty && boardTodayRemainingCount == 0
    }

    var shouldUseExamMomentumTone: Bool {
        resolvedHeroKind == .upcomingExam && nearestRelevantExam != nil
    }

    var shouldUseNoTaskMomentumTone: Bool {
        todayBoardTasks.isEmpty && resolvedHeroKind == .noTaskPrompt
    }

    var shouldUseWrapUpMomentumTone: Bool {
        resolvedHeroKind == .wrapUp || homeLayoutMode == .completionWrapUp
    }

    var momentumPercentageText: String {
        "\(Int((boardTodayProgressValue * 100).rounded()))%"
    }

    var momentumSubtitleText: String {
        if todayBoardTasks.isEmpty {
            return "Bugün sakin. İstersen küçük bir başlangıç yap."
        }

        if boardTodayProgressValue >= 1 {
            return "Bugünü temiz kapattın. Harika."
        }

        if boardTodayProgressValue >= 0.6 {
            return "İyi gidiyorsun. Bir adım daha var."
        }

        if boardTodayProgressValue > 0 {
            return "Başladın. Birkaç görev daha günü güçlendirir."
        }

        return "Küçük bir adım bile ivme yaratır."
    }

    var momentumCardSubtitle: String {
        if shouldUseExamMomentumTone, let exam = nearestRelevantExam {
            let courseTitle = exam.courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? exam.title
                : exam.courseName
            return "\(courseTitle) yaklaşırken bugünkü ritmini takip et."
        }

        if shouldUseNoTaskMomentumTone {
            switch heroDayPhase {
            case .morning:
                return "Bugün hâlâ açık. Küçük bir plan güçlü bir başlangıç yaratır."
            case .afternoon:
                return "Henüz görev yok. Tek bir küçük iş bile günü hareket ettirebilir."
            case .evening, .night:
                return "Bugün boş geçtiyse bile yarın için küçük bir hazırlık yapabilirsin."
            }
        }

        if isDayEffectivelyComplete {
            return "Bugün için belirlediğin işler tamamlandı."
        }

        if boardTodayProgressValue >= 0.6 {
            return "Ritmin oluştu. Birkaç adım daha günü güçlü kapatır."
        }

        if boardTodayProgressValue > 0 {
            return "Başlangıç yaptın. Devam edersen gün çok daha netleşir."
        }

        switch homeLayoutMode {
        case .focusActive:
            return "Şu an ritmini koruman en önemli şey."
        case .crewFollowUp:
            return "Önce kişisel tarafı toparlayıp sonra crew akışına geçebilirsin."
        case .insightsFollowUp:
            return "Bugünkü akışının kısa özeti burada."
        case .completionWrapUp:
            return "Günün kapanış görünümünü tek bakışta gör."
        case .defaultFlow:
            return "Günün durumunu tek bakışta gör."
        }
    }

    var shouldEmphasizeMomentumCard: Bool {
        if shouldUseExamMomentumTone { return true }
        if shouldUseNoTaskMomentumTone { return true }
        if isDayEffectivelyComplete { return true }

        switch homeLayoutMode {
        case .insightsFollowUp, .completionWrapUp:
            return true
        default:
            return false
        }
    }

    var shouldEmphasizeQuickActionsCard: Bool {
        switch homeLayoutMode {
        case .completionWrapUp, .crewFollowUp:
            return true
        default:
            return false
        }
    }

    var momentumAccentColor: Color {
        if shouldUseExamMomentumTone {
            return .orange
        }

        if shouldUseNoTaskMomentumTone {
            return .purple
        }

        if isDayEffectivelyComplete {
            return .green
        }

        if boardTodayProgressValue >= 0.6 {
            return .green
        }

        if boardTodayProgressValue > 0 {
            return .blue
        }

        switch homeLayoutMode {
        case .completionWrapUp:
            return .green
        case .insightsFollowUp:
            return .blue
        case .crewFollowUp:
            return .pink
        case .focusActive:
            return .orange
        case .defaultFlow:
            return .accentColor
        }
    }

    var adaptiveMomentumBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        palette.cardFill,
                        palette.cardFill.opacity(0.97)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                shouldEmphasizeMomentumCard ? momentumAccentColor.opacity(0.10) : momentumAccentColor.opacity(0.04),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 8,
                            endRadius: 180
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                momentumAccentColor.opacity(0.06),
                                Color.clear
                            ],
                            center: .bottomTrailing,
                            startRadius: 10,
                            endRadius: 220
                        )
                    )
                    .blur(radius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(
                        shouldEmphasizeMomentumCard
                        ? momentumAccentColor.opacity(0.14)
                        : palette.cardStroke.opacity(0.86),
                        lineWidth: 1
                    )
            )
    }
}
