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
                    Text(tr("oc_todays_progress"))
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
                        Text(tr("hd_insights"))
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
            return tr("hm_1")
        }

        if boardTodayProgressValue >= 1 {
            return tr("hm_2")
        }

        if boardTodayProgressValue >= 0.6 {
            return tr("hm_3")
        }

        if boardTodayProgressValue > 0 {
            return tr("hm_4")
        }

        return tr("hm_5")
    }

    var momentumCardSubtitle: String {
        if shouldUseExamMomentumTone, let exam = nearestRelevantExam {
            let courseTitle = exam.courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? exam.title
                : exam.courseName
            return tr("hm_exam_approaching", courseTitle)
        }

        if shouldUseNoTaskMomentumTone {
            switch heroDayPhase {
            case .morning:
                return tr("hm_6")
            case .afternoon:
                return tr("hm_7")
            case .evening, .night:
                return tr("hm_8")
            }
        }

        if isDayEffectivelyComplete {
            return tr("hm_9")
        }

        if boardTodayProgressValue >= 0.6 {
            return tr("hm_10")
        }

        if boardTodayProgressValue > 0 {
            return tr("hm_11")
        }

        switch homeLayoutMode {
        case .focusActive:
            return tr("hm_12")
        case .crewFollowUp:
            return tr("hm_13")
        case .insightsFollowUp:
            return tr("hm_14")
        case .completionWrapUp:
            return tr("hm_15")
        case .defaultFlow:
            return tr("hm_16")
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
            return Color(arenaHex: AppArenaPalette.gold)
        }

        if shouldUseNoTaskMomentumTone {
            return Color(arenaHex: AppArenaPalette.purple)
        }

        if isDayEffectivelyComplete {
            return Color(arenaHex: AppArenaPalette.green)
        }

        if boardTodayProgressValue >= 0.6 {
            return Color(arenaHex: AppArenaPalette.green)
        }

        if boardTodayProgressValue > 0 {
            return Color(arenaHex: AppArenaPalette.blue)
        }

        switch homeLayoutMode {
        case .completionWrapUp:
            return Color(arenaHex: AppArenaPalette.green)
        case .insightsFollowUp:
            return Color(arenaHex: AppArenaPalette.blue)
        case .crewFollowUp:
            return Color(arenaHex: AppArenaPalette.coral)
        case .focusActive:
            return Color(arenaHex: AppArenaPalette.gold)
        case .defaultFlow:
            return Color(arenaHex: AppArenaPalette.cyan)
        }
    }

    var adaptiveMomentumBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        momentumAccentColor.opacity(0.070),
                        Color(arenaHex: AppArenaPalette.purple).opacity(0.045),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
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
                                shouldEmphasizeMomentumCard
                                ? momentumAccentColor.opacity(0.14)
                                : momentumAccentColor.opacity(0.08),
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 8,
                            endRadius: 210
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(arenaHex: AppArenaPalette.blue).opacity(0.060),
                                Color.clear
                            ],
                            center: .bottomTrailing,
                            startRadius: 10,
                            endRadius: 230
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(
                        shouldEmphasizeMomentumCard
                        ? momentumAccentColor.opacity(0.16)
                        : momentumAccentColor.opacity(0.12),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }
}
