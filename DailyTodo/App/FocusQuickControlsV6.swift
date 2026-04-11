//
//  FocusQuickControlsV6.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 11.04.2026.
//

import SwiftUI

struct FocusQuickControlsV6: View {
    @Binding var selectedPreset: FocusDurationPreset
    @Binding var customMinutes: Int
    let selectedGoal: FocusGoal
    let selectedStyle: FocusStyle
    let accent: Color
    let onTapCustom: () -> Void
    let onTapGoal: () -> Void
    let onTapStyle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hızlı Ayarlar")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.94))

            HStack(spacing: 10) {
                presetChip(.short, label: "15 dk")
                presetChip(.medium, label: "25 dk")
                presetChip(.long, label: "45 dk")
                customChip
            }

            VStack(spacing: 8) {
                selectionRow(
                    title: "Goal",
                    value: selectedGoal.title,
                    subtitle: selectedGoal.subtitle,
                    icon: selectedGoal.icon,
                    accent: accent,
                    action: onTapGoal
                )

                selectionRow(
                    title: "Sound",
                    value: selectedStyle.title,
                    subtitle: selectedStyle.subtitle,
                    icon: selectedStyle.icon,
                    accent: accent.opacity(0.85),
                    action: onTapStyle
                )
            }
        }
    }

    private func presetChip(_ preset: FocusDurationPreset, label: String) -> some View {
        Button {
            selectedPreset = preset
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(selectedPreset == preset ? .white : Color.white.opacity(0.76))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            selectedPreset == preset
                            ? LinearGradient(
                                colors: [
                                    accent.opacity(0.28),
                                    Color.white.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.05),
                                    Color.white.opacity(0.025)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(selectedPreset == preset ? 0.11 : 0.05), lineWidth: 1)
                        )
                )
                .shadow(color: selectedPreset == preset ? accent.opacity(0.18) : .clear, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var customChip: some View {
        Button(action: onTapCustom) {
            Text(selectedPreset == .custom ? "\(customMinutes) dk" : "Özel")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(selectedPreset == .custom ? .white : Color.white.opacity(0.76))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            selectedPreset == .custom
                            ? LinearGradient(
                                colors: [
                                    accent.opacity(0.28),
                                    Color.white.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.05),
                                    Color.white.opacity(0.025)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(selectedPreset == .custom ? 0.11 : 0.05), lineWidth: 1)
                        )
                )
                .shadow(color: selectedPreset == .custom ? accent.opacity(0.18) : .clear, radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func selectionRow(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )

                Circle()
                    .fill(accent.opacity(0.16))
                    .frame(width: 86, height: 86)
                    .blur(radius: 24)
                    .offset(x: -120, y: 0)

                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))

                        Image(systemName: icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.92))
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.58))
                            .tracking(1)

                        Text(value)
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.96))

                        Text(subtitle)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.66))
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.40))
                }
                .padding(.horizontal, 14)
            }
            .frame(height: 66)
            .shadow(color: accent.opacity(0.08), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}
