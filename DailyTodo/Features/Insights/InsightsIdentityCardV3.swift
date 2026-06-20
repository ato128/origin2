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
        guard !trimmed.isEmpty else { return ("Driver", "") }

        let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
        if parts.count == 1 { return (parts[0], "") }
        return (parts[0], parts[1])
    }

    /// Snapshot.title'dan tier harfi türet ("Momentum Starter" → "S", "Deep Worker" → "D")
    private var tierLetter: String {
        let trimmed = snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(1)).uppercased()
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                topRow
                statsGrid
                progressBar
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    // MARK: Top: name + tier

    private var topRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(primaryAccent)
                        .frame(width: 20, height: 1)

                    Text("DRIVER · LV \(snapshot.level) · \(snapshot.title.uppercased())")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(primaryAccent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.66)
                }

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(nameParts.first)
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)

                    if !nameParts.rest.isEmpty {
                        Text(nameParts.rest)
                            .font(.system(size: 26, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [primaryAccent, secondaryAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)
                    }
                }
                .layoutPriority(1)

                Text(hasPendingLevelUp ? tr("iid_ready_level") : snapshot.statusText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(hasPendingLevelUp ? primaryAccent.opacity(0.92) : .white.opacity(0.50))
                    .lineLimit(2)
                    .padding(.top, 1)
            }

            Spacer(minLength: 8)

            tierBox
        }
    }

    private var tierBox: some View {
        VStack(spacing: 2) {
            Text("TIER")
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.72))

            Text(tierLetter)
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [primaryAccent, secondaryAccent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: primaryAccent.opacity(0.30), radius: 10, y: 5)
        )
    }

    // MARK: Stats grid

    private var statsGrid: some View {
        HStack(spacing: 6) {
            statColumn(
                label: "FOCUS",
                value: snapshot.focusSessions,
                unit: "OTURUM",
                tint: Color(arenaHex: AppArenaPalette.cyan)
            )

            divider

            statColumn(
                label: "STREAK",
                value: snapshot.streakDays,
                unit: tr("iid_day_caps"),
                tint: Color(arenaHex: AppArenaPalette.gold)
            )

            divider

            statColumn(
                label: "TAMAM",
                value: snapshot.completedTasks,
                unit: tr("ct_task_caps"),
                tint: Color(arenaHex: AppArenaPalette.green)
            )

            divider

            statColumn(
                label: "LEVEL",
                value: snapshot.level,
                unit: tr("iid_stage_caps"),
                tint: Color(arenaHex: AppArenaPalette.purple)
            )
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.030))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func statColumn(label: String, value: Int, unit: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.42))
                .lineLimit(1)

            Text("\(value)")
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            Text(unit)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(tint.opacity(0.85))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(width: 1, height: 28)
    }

    // MARK: Progress bar

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                HStack(spacing: 4) {
                    Text("LV \(snapshot.level)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(primaryAccent)

                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(.white.opacity(0.35))

                    Text("LV \(snapshot.level + 1)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }

                Spacer()

                Text(snapshot.percentText)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.55))

                if hasPendingLevelUp {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.forward.circle.fill")
                            .font(.system(size: 9, weight: .black))

                        Text("HAZIR")
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

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    primaryAccent,
                                    secondaryAccent,
                                    Color(arenaHex: AppArenaPalette.cyan).opacity(0.90)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: barFilled
                                ? max(10, geo.size.width * min(max(snapshot.progress, 0), 1))
                                : 10,
                            height: 5
                        )
                        .shadow(color: primaryAccent.opacity(0.30), radius: 6, y: 2)
                }
            }
            .frame(height: 5)
            .onAppear {
                guard !barFilled else { return }
                // Animated fill with a soft bounce at the end
                withAnimation(.spring(response: 0.8, dampingFraction: 0.68).delay(0.25)) {
                    barFilled = true
                }
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
