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

            if !isPremium {
                upgradeCTA.padding(.top, 4)
            }
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

    // MARK: - Exam Planner (full-width)

    private var examPlannerCard: some View {
        let gold = Color(arenaHex: AppArenaPalette.gold)
        let coral = Color(arenaHex: AppArenaPalette.coral)

        return Button(action: onExamPlanner) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [gold, coral],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 52, height: 52)
                        .shadow(color: gold.opacity(0.35), radius: 10, y: 5)
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("iplc_exam_planner"))
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(tr("iplc_exam_sub"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                VStack(spacing: 4) {
                    proActiveBadge(tint: gold)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(
                        colors: [gold.opacity(0.10), coral.opacity(0.05), Color(arenaHex: AppArenaPalette.surface).opacity(0.92)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(gold.opacity(0.22), lineWidth: 1))
                    .shadow(color: .black.opacity(0.18), radius: 10, y: 5)
            )
        }
        .buttonStyle(.plain)
    }

    private func proActiveBadge(tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: 7, weight: .black))
            Text("PRO")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(0.4)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .frame(height: 19)
        .background(
            Capsule()
                .fill(tint.opacity(0.16))
                .overlay(Capsule().stroke(tint.opacity(0.30), lineWidth: 1))
        )
    }

    // MARK: - Upgrade CTA

    private var upgradeCTA: some View {
        Button(action: onUpgrade) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .black))
                        Text("UPDO PRO")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1.2)
                    }
                    .foregroundStyle(.black.opacity(0.62))

                    Text(tr("iplc_all_free"))
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text("sonra ₺49/ay")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black.opacity(0.62))
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Color.black.opacity(0.08)))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(arenaHex: AppArenaPalette.gold),
                                 Color(arenaHex: AppArenaPalette.coral),
                                 Color(arenaHex: AppArenaPalette.purple)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(RadialGradient(
                            colors: [.white.opacity(0.22), .clear],
                            center: .topTrailing, startRadius: 4, endRadius: 160)))
                    .shadow(color: Color(arenaHex: AppArenaPalette.gold).opacity(0.25), radius: 14, y: 7)
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
                    .foregroundStyle(.white)
                Text(tr("iplc_already_active"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button("Kapat") { dismiss() }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 16).fill(toolInfo.primary.opacity(0.3)))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}
