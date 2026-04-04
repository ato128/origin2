//
//  HomeDashboardView+Momentum.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 30.03.2026.
//

import SwiftUI

extension HomeDashboardView {
    var momentumCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(momentumCardTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)

                    Text(momentumCardSubtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.secondaryText)

                    Text(momentumSubtitleText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(momentumAccentColor.opacity(0.92))
                }

                Spacer()

                Button {
                    onOpenInsights()
                } label: {
                    HStack(spacing: 6) {
                        Text(momentumCTAButtonTitle)
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(palette.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(palette.secondaryCardFill))
                    .overlay(
                        Capsule()
                            .stroke(
                                shouldEmphasizeMomentumCard
                                ? Color.accentColor.opacity(0.24)
                                : palette.cardStroke,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(Int(todayProgressValue * 100))%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(momentumAccentColor)

                    Spacer()

                    Text("\(completedTodayCount)/\(max(totalTodayTaskCount, 1))")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(palette.secondaryCardFill)

                        Capsule()
                            .fill(momentumAccentColor)
                            .frame(width: max(10, geo.size.width * todayProgressValue))
                    }
                }
                .frame(height: 10)
            }

            HStack(spacing: 8) {
                smallStatsChip(title: "Seri", value: "\(streakCount)", tint: .orange)
                smallStatsChip(title: "Biten", value: "\(completedTodayCount)", tint: .green)
                smallStatsChip(title: "Kalan", value: "\(todayTasks.count)", tint: .blue)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(adaptiveMomentumBackground)
        .shadow(
            color: shouldEmphasizeMomentumCard ? Color.accentColor.opacity(0.10) : .clear,
            radius: shouldEmphasizeMomentumCard ? 12 : 0,
            y: shouldEmphasizeMomentumCard ? 4 : 0
        )
    }
    
    var hasVisibleUpcomingExamMomentum: Bool {
        nearestRelevantExam != nil
    }

    var todayRemainingCount: Int {
        max(totalTodayTaskCount - completedTodayCount, 0)
    }

    var isDayEffectivelyComplete: Bool {
        totalTodayTaskCount > 0 && todayRemainingCount == 0
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

    var momentumSubtitleText: String {
        if todayTasks.isEmpty && completedTodayCount == 0 {
            return "Bugün sakin. İstersen küçük bir başlangıç yap."
        }

        if todayProgressValue >= 1 {
            return "Bugünü temiz kapattın. Harika."
        }

        if todayProgressValue >= 0.6 {
            return "İyi gidiyorsun. Bir adım daha var."
        }

        return "Küçük bir adım bile ivme yaratır."
    }
    var momentumCardTitle: String {
        if shouldUseExamMomentumTone {
            return "Hazırlık Durumu"
        }

        if shouldUseNoTaskMomentumTone {
            return "Bugün İçin Alan Var"
        }

        if isDayEffectivelyComplete {
            return "Bugün Tamam"
        }

        switch homeLayoutMode {
        case .focusActive:
            return "Odak Ritmi"
        case .crewFollowUp:
            return "Kişisel Durumun"
        case .insightsFollowUp:
            return "Bugünün Özeti"
        case .completionWrapUp:
            return "Gün Özeti"
        case .defaultFlow:
            return "Bugünkü İlerleme"
        }
    }

    var momentumCardSubtitle: String {
        if shouldUseExamMomentumTone, let exam = nearestRelevantExam {
            let courseTitle = exam.courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? exam.title
                : exam.courseName
            return "\(courseTitle) için ritmini burada takip edebilirsin."
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

        if todayProgressValue >= 0.6 {
            return "Ritmin oluştu. Birkaç adım daha günü güçlü kapatır."
        }

        if todayProgressValue > 0 {
            return "Başlangıç yaptın. Devamı gelirse gün çok daha netleşir."
        }

        switch homeLayoutMode {
        case .focusActive:
            return "Şu an ritmini koruman en önemli şey."
        case .crewFollowUp:
            return "Kişisel tarafı netleştirip sonra crew akışına geçebilirsin."
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

    var momentumCTAButtonTitle: String {
        if shouldUseExamMomentumTone {
            return "Hazırlık"
        }

        if shouldUseNoTaskMomentumTone {
            return "Plan"
        }

        if shouldUseWrapUpMomentumTone {
            return "Detaylar"
        }

        return "İçgörüler"
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

        if todayProgressValue >= 0.6 {
            return .green
        }

        if todayProgressValue > 0 {
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
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                shouldEmphasizeMomentumCard ? momentumAccentColor.opacity(0.10) : Color.clear,
                                Color.clear
                            ],
                            center: .topLeading,
                            startRadius: 12,
                            endRadius: 220
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        shouldEmphasizeMomentumCard
                        ? momentumAccentColor.opacity(0.24)
                        : palette.cardStroke,
                        lineWidth: 1
                    )
            )
    }
}
