//
//  InsightsPremiumLabCard.swift
//  DailyTodo
//
//  Premium Lab — single tool: AI Sınav Planlayıcı
//

import SwiftUI

// MARK: - PremiumLabTool

enum PremiumLabTool {
    case examPlanner
    case aiCoach        // kept for backwards compatibility
    case smartInsights  // kept for backwards compatibility
}

// MARK: - Main Card

struct InsightsPremiumLabCard: View {
    let isPremium: Bool
    let onExamPlanner: () -> Void
    let onCoach: () -> Void         // unused but kept for API compatibility
    let onSmartInsights: () -> Void // unused but kept for API compatibility
    let onUpgrade: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            eyebrowRow
            examPlannerCard
        }
    }

    // MARK: - Eyebrow

    private var eyebrowRow: some View {
        HStack(spacing: 7) {
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(arenaHex: AppArenaPalette.gold), Color(arenaHex: AppArenaPalette.purple)],
                    startPoint: .leading, endPoint: .trailing))
                .frame(width: 16, height: 1)

            Text(tr("iplc_header_caps"))
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(LinearGradient(
                    colors: [Color(arenaHex: AppArenaPalette.gold), Color(arenaHex: AppArenaPalette.purple)],
                    startPoint: .leading, endPoint: .trailing))

            Spacer()

            if isPremium { proBadge }
        }
    }

    private var proBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 9, weight: .black))
            Text("PRO")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.6)
        }
        .foregroundStyle(Color(arenaHex: AppArenaPalette.gold))
        .padding(.horizontal, 7)
        .frame(height: 20)
        .background(
            Capsule()
                .fill(Color(arenaHex: AppArenaPalette.gold).opacity(0.15))
                .overlay(Capsule().stroke(Color(arenaHex: AppArenaPalette.gold).opacity(0.30), lineWidth: 1))
        )
    }

    // MARK: - Exam Planner (full-width, premium)

    private var examPlannerCard: some View {
        let gold = Color(arenaHex: AppArenaPalette.gold)
        let coral = Color(arenaHex: AppArenaPalette.coral)
        let purple = Color(arenaHex: AppArenaPalette.purple)

        return Button(action: onExamPlanner) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [gold, coral],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                        .shadow(color: gold.opacity(0.40), radius: 12, y: 5)
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(tr("iplc_exam_planner"))
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(UpdoTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text("AI")
                            .font(.system(size: 8.5, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(height: 15)
                            .background(
                                Capsule().fill(LinearGradient(colors: [purple, coral],
                                                              startPoint: .leading, endPoint: .trailing))
                            )
                    }

                    Text(tr("iplc_exam_sub"))
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(UpdoTheme.filmy(0.58))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle().fill(LinearGradient(colors: [gold, coral],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .shadow(color: gold.opacity(0.30), radius: 8, y: 3)
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [gold.opacity(0.12), coral.opacity(0.06), AppArenaPalette.surfaceColor.opacity(0.95)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(colors: [gold.opacity(0.32), coral.opacity(0.22)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1)
                    )
                    .shadow(color: UpdoTheme.cardShadow(0.18), radius: 12, y: 6)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Coming Soon Sheet (backwards compatibility)

struct InsightsComingSoonSheet: View {
    let tool: PremiumLabTool
    @Environment(\.dismiss) private var dismiss

    private var toolInfo: (title: String, icon: String, primary: Color, secondary: Color) {
        switch tool {
        case .aiCoach:
            return (tr("hdb_ai_coach"), "brain.head.profile",
                    Color(arenaHex: AppArenaPalette.purple), Color(arenaHex: AppArenaPalette.cyan))
        case .smartInsights:
            return ("Smart Insights", "chart.line.uptrend.xyaxis",
                    Color(arenaHex: AppArenaPalette.cyan), Color(arenaHex: AppArenaPalette.blue))
        case .examPlanner:
            return (tr("iplc_exam_planner"), "calendar.badge.clock",
                    Color(arenaHex: AppArenaPalette.gold), Color(arenaHex: AppArenaPalette.coral))
        }
    }

    var body: some View {
        ZStack {
            ArenaBackground(primaryGlow: toolInfo.primary, secondaryGlow: toolInfo.secondary,
                            warmGlow: Color(arenaHex: AppArenaPalette.gold))
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: toolInfo.icon)
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(toolInfo.primary)
                Text(toolInfo.title)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(UpdoTheme.textPrimary)
                Text(tr("iplc_already_active"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(UpdoTheme.filmy(0.6))
                Spacer()
                Button(appLanguageIsEnglish() ? "Close" : "Kapat") { dismiss() }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(UpdoTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 16).fill(toolInfo.primary.opacity(0.3)))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .updoColorScheme()
    }
}
