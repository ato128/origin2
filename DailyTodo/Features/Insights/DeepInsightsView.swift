//
//  DeepInsightsView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.04.2026.
//

import SwiftUI

struct DeepInsightsView: View {
    @Environment(\.dismiss) private var dismiss

    let hero: DeepInsightsHeroData
    let bestWindow: BestStudyWindowData
    let weeklyReview: WeeklyDeepReviewData
    let identityEvolution: IdentityEvolutionData
    let exams: [ExamReadinessProRow]
    let alerts: [PatternAlertData]

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    heroCard
                    bestWindowCard
                    weeklyReviewCard
                    identityEvolutionCard
                    examReadinessCard
                    alertsSection
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("di_title"))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(tr("di_sub"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark").accessibilityLabel(tr("event_close"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var heroCard: some View {
        premiumCard(tint: .purple) {
            VStack(alignment: .leading, spacing: 12) {
                Text(hero.title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(hero.subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.74))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hero.primaryValue)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(hero.primaryLabel)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.60))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        chip(hero.chip1)
                        chip(hero.chip2)
                    }
                }
            }
        }
    }

    private var bestWindowCard: some View {
        premiumCard(tint: bestWindow.accent) {
            VStack(alignment: .leading, spacing: 10) {
                Text(tr("di_best_window"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.60))

                Text(bestWindow.timeRange)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(bestWindow.confidenceText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.68))

                Text(bestWindow.summary)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.76))
            }
        }
    }

    private var weeklyReviewCard: some View {
        premiumCard(tint: .blue) {
            VStack(alignment: .leading, spacing: 12) {
                Text(tr("di_weekly_review"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(tr("di_strongest", weeklyReview.strongestDay))
                    .foregroundStyle(.white.opacity(0.84))

                Text(tr("di_weakest", weeklyReview.weakestDay))
                    .foregroundStyle(.white.opacity(0.84))

                Text(weeklyReview.deltaText)
                    .foregroundStyle(.white.opacity(0.72))

                Text(weeklyReview.recommendation)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.76))
            }
        }
    }

    private var identityEvolutionCard: some View {
        premiumCard(tint: .orange) {
            VStack(alignment: .leading, spacing: 12) {
                Text(tr("di_identity_evo"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(identityEvolution.currentIdentity)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(tr("di_next", identityEvolution.nextIdentity))
                    .foregroundStyle(.white.opacity(0.76))

                ProgressView(value: identityEvolution.progress)
                    .tint(.white.opacity(0.88))

                Text(identityEvolution.progressText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
    }

    private var examReadinessCard: some View {
        premiumCard(tint: .pink) {
            VStack(alignment: .leading, spacing: 12) {
                Text(tr("di_exam_readiness"))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                ForEach(exams) { exam in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(exam.title)
                                .foregroundStyle(.white)
                            Spacer()
                            Text(exam.readinessText)
                                .foregroundStyle(.white.opacity(0.76))
                        }

                        ProgressView(value: exam.progress)
                            .tint(.white.opacity(0.86))

                        Text(exam.riskText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.60))
                    }
                }
            }
        }
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("di_pattern_alerts"))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            ForEach(alerts) { alert in
                premiumCard(tint: alert.tint) {
                    HStack(spacing: 12) {
                        Image(systemName: alert.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(alert.title)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text(alert.message)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.72))
                        }
                    }
                }
            }
        }
    }

    private func premiumCard<Content: View>(tint: Color, @ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.14),
                            Color.white.opacity(0.03),
                            Color.black.opacity(0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )

            content()
                .padding(18)
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(0.84))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.08), in: Capsule())
    }
}
