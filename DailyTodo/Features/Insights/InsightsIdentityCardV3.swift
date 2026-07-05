//
//  InsightsIdentityCardV3.swift
//  DailyTodo
//
//  F1 driver profile tarzı kimlik kartı.
//  - Sol: DRIVER eyebrow + isim (Atakan Ortaç)
//  - Sağ: TIER kutusu (gradient)
//  - Alt: 4 sütun büyük rakam (Focus / Streak / Tamam / Level)
//  - En alt: progress bar (LV X → LV X+1)
//

import SwiftUI

struct InsightsIdentityCardV3: View {
    let snapshot: IdentityLevelSnapshot
    let userName: String
    let hasPendingLevelUp: Bool
    let onTap: () -> Void

    @State private var barFilled = false

    private var primaryAccent: Color {
        hasPendingLevelUp ? Color(arenaHex: AppArenaPalette.gold) : snapshot.accent
    }

    private var secondaryAccent: Color {
        hasPendingLevelUp ? Color(arenaHex: AppArenaPalette.coral) : Color(arenaHex: AppArenaPalette.blue)
    }

    private var nameParts: (first: String, rest: String) {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return (tr("iid_fallback_name"), "") }

        let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
        if parts.count == 1 { return (parts[0], "") }
        return (parts[0], parts[1])
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                topRow
                footerRow
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    // MARK: Top: pure identity (name + title) + level ring
    //
    // The numbers live in the Focus / Tasks cards below — this card is only
    // "who you are": name, earned title, and the ring toward the next level.

    private var topRow: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(primaryAccent)
                        .frame(width: 20, height: 1)

                    Text("\(tr("iid_level_caps")) \(snapshot.level)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.8)
                        .foregroundStyle(primaryAccent)
                        .lineLimit(1)
                }

                Text(fullName)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                // The earned title is the star: big, serif italic, rarity color.
                Text(snapshot.title)
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [primaryAccent, secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Spacer(minLength: 8)

            levelRing
        }
    }

    private var fullName: String {
        nameParts.rest.isEmpty ? nameParts.first : "\(nameParts.first) \(nameParts.rest)"
    }

    /// Circular progress toward the next level, level number in the middle.
    private var levelRing: some View {
        let progress = min(max(snapshot.progress, 0), 1)

        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 5)

            Circle()
                .trim(from: 0, to: barFilled ? progress : 0.02)
                .stroke(
                    AngularGradient(
                        colors: [primaryAccent, secondaryAccent, primaryAccent],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: primaryAccent.opacity(0.35), radius: 6)

            VStack(spacing: 0) {
                Text("\(snapshot.level)")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text(snapshot.percentText)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .frame(width: 72, height: 72)
        .onAppear {
            guard !barFilled else { return }
            withAnimation(.spring(response: 0.9, dampingFraction: 0.72).delay(0.25)) {
                barFilled = true
            }
        }
    }

    // MARK: Footer: one quiet line

    private var footerRow: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(tr("iid_next_level_fmt", snapshot.level + 1))
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(primaryAccent)

            Spacer()

            if hasPendingLevelUp {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.forward.circle.fill")
                        .font(.system(size: 9, weight: .black))

                    Text(tr("iid_ready_chip"))
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(0.6)
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 7)
                .frame(height: 18)
                .background(
                    Capsule()
                        .fill(Color(arenaHex: AppArenaPalette.gold))
                )
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white.opacity(0.32))
            }
        }
    }

    // MARK: Background

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        primaryAccent.opacity(0.105),
                        secondaryAccent.opacity(0.058),
                        Color(arenaHex: AppArenaPalette.surface).opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                primaryAccent.opacity(hasPendingLevelUp ? 0.24 : 0.17),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 6,
                            endRadius: 200
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                secondaryAccent.opacity(0.10),
                                Color.clear
                            ],
                            center: .bottomLeading,
                            startRadius: 8,
                            endRadius: 200
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(primaryAccent.opacity(hasPendingLevelUp ? 0.26 : 0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }
}
