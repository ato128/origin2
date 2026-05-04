//
//  FocusDetailSectionV3.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 9.04.2026.
//

import SwiftUI

struct FocusDetailSectionV3: View {
    let mode: FocusMode

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            VStack(spacing: 10) {
                detailRow(
                    title: "Önerilen mod",
                    subtitle: detailSubtitle(for: .medium),
                    icon: "target"
                )

                detailRow(
                    title: "Kısa başlangıç",
                    subtitle: detailSubtitle(for: .short),
                    icon: "bolt.fill"
                )

                detailRow(
                    title: "Uzun mod",
                    subtitle: detailSubtitle(for: .long),
                    icon: "timer"
                )
            }
        }
        .padding(20)
        .background(sectionBackground)
    }
}

private extension FocusDetailSectionV3 {

    var accent: Color {
        switch mode {
        case .personal:
            return Color(arenaHex: AppArenaPalette.cyan)
        case .crew:
            return Color(arenaHex: AppArenaPalette.coral)
        case .friend:
            return Color(arenaHex: AppArenaPalette.purple)
        }
    }

    var secondaryAccent: Color {
        switch mode {
        case .personal:
            return Color(arenaHex: AppArenaPalette.purple)
        case .crew:
            return Color(arenaHex: AppArenaPalette.gold)
        case .friend:
            return Color(arenaHex: AppArenaPalette.blue)
        }
    }

    var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        accent.opacity(0.070),
                        secondaryAccent.opacity(0.042),
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
                                accent.opacity(0.13),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 8,
                            endRadius: 210
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(accent.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }

    var headerRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(accent)
                        .frame(width: 18, height: 1)

                    Text("FOCUS DETAILS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(accent)
                }

                Text("Detaylar")
                    .font(.system(size: 25, weight: .black))
                    .foregroundStyle(.white)
            }

            Spacer()

            Text(mode.detailBadge)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(accent)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(
                    Capsule(style: .continuous)
                        .fill(accent.opacity(0.13))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(accent.opacity(0.18), lineWidth: 1)
                        )
                )
        }
    }

    func detailRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(accent.opacity(0.15), lineWidth: 1)
                    )

                Image(systemName: icon)
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(accent)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(.white.opacity(0.94))

                Text(subtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.050),
                            Color.white.opacity(0.035)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.065), lineWidth: 1)
                )
        )
    }

    func detailSubtitle(for preset: FocusDurationPreset) -> String {
        switch mode {
        case .personal:
            switch preset {
            case .short:
                return "15 dk hızlı çalışma"
            case .medium:
                return "25 dk derin odak"
            case .long:
                return "45 dk yoğun akış"
            case .custom:
                return "Özel süreli kişisel odak"
            }

        case .crew:
            switch preset {
            case .short:
                return "20 dk senkron başlangıç"
            case .medium:
                return "30 dk ekip akışı"
            case .long:
                return "50 dk takım odak modu"
            case .custom:
                return "Özel süreli ekip oturumu"
            }

        case .friend:
            switch preset {
            case .short:
                return "15 dk eşleşmiş odak"
            case .medium:
                return "25 dk birlikte odak"
            case .long:
                return "45 dk beraber derin akış"
            case .custom:
                return "Özel süreli ortak odak"
            }
        }
    }
}
