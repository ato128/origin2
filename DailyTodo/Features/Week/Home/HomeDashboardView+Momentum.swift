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
        switch homeLayoutMode {
        case .focusActive:
            return "Odak Ritmi"
        case .crewFollowUp:
            return "Bugünkü İlerleme"
        case .insightsFollowUp:
            return "Bugünün Özeti"
        case .completionWrapUp:
            return "Gün Özeti"
        case .defaultFlow:
            return "Bugünkü İlerleme"
        }
    }

    var momentumCardSubtitle: String {
        switch homeLayoutMode {
        case .focusActive:
            return "Şu an ritmini koruman en önemli şey."
        case .crewFollowUp:
            return "Kişisel tarafta neredesin, sonra crew’e geç."
        case .insightsFollowUp:
            return "Bugünün akışı burada, detay için içgörülere geçebilirsin."
        case .completionWrapUp:
            return "Bugün büyük ölçüde tamam. Kapanış görünümü."
        case .defaultFlow:
            return "Günün durumunu tek bakışta gör."
        }
    }

    var shouldEmphasizeMomentumCard: Bool {
        switch homeLayoutMode {
        case .insightsFollowUp, .completionWrapUp:
            return true
        default:
            return false
        }
    }

    var quickActionsCardTitle: String {
        switch homeLayoutMode {
        case .focusActive:
            return "Odak Sonrası"
        case .crewFollowUp:
            return "Sonraki Adımlar"
        case .insightsFollowUp:
            return "Kısa Yollar"
        case .completionWrapUp:
            return "Yarına Hazırlık"
        case .defaultFlow:
            return "Hızlı İşlemler"
        }
    }

    var quickActionsCardSubtitle: String {
        switch homeLayoutMode {
        case .focusActive:
            return "Odaktan çıkınca yapacağın kısa aksiyonlar"
        case .crewFollowUp:
            return "Buradan ekip veya plan tarafına geçebilirsin"
        case .insightsFollowUp:
            return "İçgörüden sonra ihtiyacın olacak kısa yollar"
        case .completionWrapUp:
            return "Günü kapatırken en mantıklı hamleler"
        case .defaultFlow:
            return "Öğrenci akışın için kısa yollar"
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
        switch homeLayoutMode {
        case .insightsFollowUp, .completionWrapUp:
            return "Detaylar"
        default:
            return "İçgörüler"
        }
    }

    var momentumAccentColor: Color {
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
