//
//  FocusDetailSectionV3.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 9.04.2026.
//

import SwiftUI

struct FocusDetailSectionV3: View {
    let mode: FocusMode

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow

            VStack(spacing: 10) {
                detailRow(
                    title: "Önerilen mod",
                    subtitle: detailSubtitle(for: .medium)
                )

                detailRow(
                    title: "Kısa başlangıç",
                    subtitle: detailSubtitle(for: .short)
                )

                detailRow(
                    title: "Uzun mod",
                    subtitle: detailSubtitle(for: .long)
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.018),
                            Color.white.opacity(0.008),
                            Color.black.opacity(0.11)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.04), lineWidth: 1)
                )
        )
    }
}

private extension FocusDetailSectionV3 {
    var headerRow: some View {
        HStack(alignment: .center) {
            Text("Detaylar")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(palette.primaryText)

            Spacer()

            Text(mode.detailBadge)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(palette.primaryText.opacity(0.82))
                .padding(.horizontal, 15)
                .frame(height: 36)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.035))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                )
        }
    }

    func detailRow(title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.white.opacity(0.24))
                .frame(width: 9, height: 9)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.primaryText.opacity(0.94))

                Text(subtitle)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.secondaryText.opacity(0.80))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
