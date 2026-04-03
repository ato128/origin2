//
//  SuggestedNextActionCard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 3.04.2026.
//

import SwiftUI

struct SuggestedNextActionCard: View {
    let action: SuggestedTaskAction
    let palette: ThemePalette
    let onPrimaryTap: () -> Void
    let onSecondaryTap: (() -> Void)?

    private var accent: Color {
        switch action.style {
        case .overdueRecovery:
            return .red
        case .quickWin:
            return .green
        case .startFocus:
            return .blue
        case .beforeClass:
            return .orange
        case .lightenLoad:
            return .purple
        case .planTomorrow:
            return .indigo
        case .keepMomentum:
            return .blue
        }
    }

    private var icon: String {
        switch action.style {
        case .overdueRecovery:
            return "exclamationmark.triangle.fill"
        case .quickWin:
            return "bolt.fill"
        case .startFocus:
            return "scope"
        case .beforeClass:
            return "clock.fill"
        case .lightenLoad:
            return "arrow.down.circle.fill"
        case .planTomorrow:
            return "calendar.badge.plus"
        case .keepMomentum:
            return "sparkles"
        }
    }

    private var eyebrow: String {
        switch action.style {
        case .overdueRecovery:
            return "Öncelikli adım"
        case .quickWin:
            return "Hızlı başlangıç"
        case .startFocus:
            return "Odak önerisi"
        case .beforeClass:
            return "Şimdi için uygun"
        case .lightenLoad:
            return "Yükü sadeleştir"
        case .planTomorrow:
            return "Akşam kapanışı"
        case .keepMomentum:
            return "Ritmi başlat"
        }
    }

    private var secondaryTitle: String {
        switch action.style {
        case .planTomorrow:
            return "Hafta"
        case .keepMomentum:
            return "Görevler"
        case .lightenLoad:
            return "Tüm Liste"
        case .overdueRecovery, .quickWin, .startFocus, .beforeClass:
            return "Görevler"
        }
    }

    private var secondaryIcon: String {
        switch action.style {
        case .planTomorrow:
            return "calendar"
        case .keepMomentum:
            return "list.bullet"
        case .lightenLoad:
            return "list.bullet.rectangle"
        case .overdueRecovery, .quickWin, .startFocus, .beforeClass:
            return "list.bullet"
        }
    }

    private var helperLine: String {
        switch action.style {
        case .overdueRecovery:
            return "Önce bu düğümü çözmek kalan işleri de hafifletir."
        case .quickWin:
            return "Küçük bir tamamlanma hissi tüm akışı açabilir."
        case .startFocus:
            return "Kısa bir odak oturumu başlamak için yeterli."
        case .beforeClass:
            return "Etkinlik başlamadan önce küçük bir ilerleme alabilirsin."
        case .lightenLoad:
            return "Önce sadeleştir, sonra odaklanmak kolaylaşır."
        case .planTomorrow:
            return "Yarına net girmek sabah sürtünmesini azaltır."
        case .keepMomentum:
            return "Tek bir küçük adım bile ritmi başlatır."
        }
    }

    private var backgroundGlow: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                RadialGradient(
                    colors: [
                        accent.opacity(0.12),
                        Color.clear
                    ],
                    center: .topTrailing,
                    startRadius: 10,
                    endRadius: 220
                )
            )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.14))
                        .frame(width: 40, height: 40)

                    Circle()
                        .stroke(accent.opacity(0.14), lineWidth: 1)
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(eyebrow)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(accent)

                    Text(action.title)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.primaryText)
                        .lineLimit(2)

                    Text(action.subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(3)
                        .padding(.top, 2)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)

                Text(helperLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(accent.opacity(0.10), lineWidth: 1)
            )

            HStack(spacing: 10) {
                Button {
                    onPrimaryTap()
                } label: {
                    Label(action.ctaTitle, systemImage: primaryIcon)
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            accent,
                                            accent.opacity(0.88)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .foregroundStyle(.white)
                        .shadow(color: accent.opacity(0.18), radius: 10, y: 4)
                }
                .buttonStyle(.plain)

                if let onSecondaryTap {
                    Button {
                        onSecondaryTap()
                    } label: {
                        Label(secondaryTitle, systemImage: secondaryIcon)
                            .font(.system(size: 14, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                Capsule()
                                    .fill(accent.opacity(0.12))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(accent.opacity(0.14), lineWidth: 1)
                            )
                            .foregroundStyle(accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(palette.cardFill)
                .overlay(backgroundGlow)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.04),
                                    Color.clear,
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(accent.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: accent.opacity(0.08), radius: 12, y: 4)
    }

    private var primaryIcon: String {
        switch action.style {
        case .planTomorrow:
            return "calendar.badge.plus"
        case .keepMomentum:
            return "plus"
        case .lightenLoad:
            return "slider.horizontal.3"
        case .overdueRecovery, .quickWin, .startFocus, .beforeClass:
            return "play.fill"
        }
    }
}
