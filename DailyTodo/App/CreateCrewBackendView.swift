//
//  CreateCrewBackendView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import SwiftUI

private enum CreateCrewArenaPalette {
    static let backgroundTop = Color(arenaHex: "#05060D")
    static let backgroundMid = Color(arenaHex: "#070713")
    static let backgroundBottom = Color(arenaHex: "#07040C")

    static let blue = Color(arenaHex: "#1593FF")
    static let cyan = Color(arenaHex: "#2DD4FF")
    static let purple = Color(arenaHex: "#7C3AED")
    static let coral = Color(arenaHex: "#FF5A44")
    static let gold = Color(arenaHex: "#FBBF24")
    static let green = Color(arenaHex: "#A3E635")
    static let surface = Color(arenaHex: "#101118")

    static var appGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: "#1E6BFF"),
                Color(arenaHex: "#7C3AED")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct CreateCrewBackendView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var crewStore: CrewStore
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var name = ""
    @State private var icon = "person.3.fill"
    @State private var colorHex = "#4F8CFF"
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showPaywall = false

    private let iconOptions: [String] = [
        "person.3.fill",
        "person.2.fill",
        "bolt.fill",
        "book.fill",
        "graduationcap.fill",
        "briefcase.fill",
        "laptopcomputer",
        "desktopcomputer",
        "pencil.and.outline",
        "checklist",
        "calendar",
        "clock.fill",
        "star.fill",
        "flag.fill",
        "flame.fill",
        "target",
        "brain.head.profile",
        "heart.fill"
    ]

    private let colorOptions: [String] = [
        "#4F8CFF",
        "#6C63FF",
        "#FF6B6B",
        "#FF9F1C",
        "#2EC4B6",
        "#22C55E",
        "#E879F9",
        "#F43F5E",
        "#0EA5E9",
        "#F59E0B",
        "#8B5CF6",
        "#14B8A6"
    ]

    private var cleanName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !isSaving && !cleanName.isEmpty
    }

    var body: some View {
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: 4)

                    header

                    previewCard

                    crewInfoCard

                    iconPickerCard

                    colorPickerCard

                    if let errorMessage {
                        errorCard(errorMessage)
                    }

                    saveButton

                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: "crew_limit")
        }
    }
}

// MARK: - Layout

private extension CreateCrewBackendView {
    var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    CreateCrewArenaPalette.backgroundTop,
                    CreateCrewArenaPalette.backgroundMid,
                    CreateCrewArenaPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(CreateCrewArenaPalette.blue.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 96)
                .offset(x: 165, y: -245)

            Circle()
                .fill(CreateCrewArenaPalette.purple.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: -175, y: 500)

            Circle()
                .fill(hexColor(colorHex).opacity(0.10))
                .frame(width: 270, height: 270)
                .blur(radius: 100)
                .offset(x: 170, y: 280)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.16),
                    Color.clear,
                    Color.black.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark").accessibilityLabel(tr("event_close"))
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(Color.white.opacity(0.075))
                            .overlay(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(isSaving)

            Spacer()

            VStack(spacing: 3) {
                Text(tr("ccb_new_crew_caps"))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(CreateCrewArenaPalette.cyan)

                Text(tr("cc_create"))
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                Task {
                    await saveCrew()
                }
            } label: {
                ZStack {
                    if isSaving {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.black)
                    }
                }
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(canSave ? CreateCrewArenaPalette.green : Color.white.opacity(0.12))
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.55)
        }
    }
}

// MARK: - Cards

private extension CreateCrewBackendView {
    var previewCard: some View {
        let tint = hexColor(colorHex)
        let displayName = cleanName.isEmpty ? "Yeni Crew" : cleanName

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.95),
                                CreateCrewArenaPalette.purple.opacity(0.80),
                                CreateCrewArenaPalette.coral.opacity(0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 66, height: 66)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 29, weight: .black))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("ccb_preview_caps"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(CreateCrewArenaPalette.cyan)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(displayName)
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)

                        Text("crew")
                            .font(.system(size: 25, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(CreateCrewArenaPalette.cyan)
                    }

                    Text(tr("ccb_subtitle"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(2)
                }

                Spacer()
            }

            HStack(spacing: 9) {
                previewPill(text: "ACTIVE", tint: CreateCrewArenaPalette.green)
                previewPill(text: icon, tint: tint)
                previewPill(text: colorHex, tint: CreateCrewArenaPalette.gold)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.12),
                            CreateCrewArenaPalette.purple.opacity(0.12),
                            CreateCrewArenaPalette.surface.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 20, y: 12)
        )
    }

    var crewInfoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                eyebrow: tr("ccb_info_caps"),
                title: "Crew",
                italic: "bilgisi"
            )

            fieldBox(
                title: tr("cc_name_caps"),
                icon: "text.cursor",
                tint: CreateCrewArenaPalette.blue
            ) {
                TextField(tr("ccb_crew_name"), text: $name)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit {
                        guard canSave else { return }
                        Task {
                            await saveCrew()
                        }
                    }

                Text(tr("ccb_name_ph"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.38))
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var iconPickerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                eyebrow: tr("ccb_symbol_caps"),
                title: tr("ccb_icon_w"),
                italic: tr("ccb_pick_w")
            )

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(iconOptions, id: \.self) { item in
                    let selected = icon == item
                    let tint = hexColor(colorHex)

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            icon = item
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(selected ? tint.opacity(0.18) : Color.white.opacity(0.045))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(selected ? tint.opacity(0.42) : Color.white.opacity(0.07), lineWidth: 1)
                                )

                            Image(systemName: item)
                                .font(.system(size: 21, weight: .black))
                                .foregroundStyle(selected ? tint : .white.opacity(0.78))
                        }
                        .frame(height: 58)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var colorPickerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                eyebrow: tr("ccb_accent_caps"),
                title: tr("ccb_color"),
                italic: tr("ccb_pick_w")
            )

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                spacing: 12
            ) {
                ForEach(colorOptions, id: \.self) { item in
                    let selected = colorHex == item
                    let tint = hexColor(item)

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            colorHex = item
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(tint)
                                .frame(width: 42, height: 42)
                                .shadow(color: tint.opacity(selected ? 0.35 : 0.12), radius: selected ? 12 : 4, y: 4)

                            if selected {
                                Circle()
                                    .stroke(Color.white.opacity(0.95), lineWidth: 3)
                                    .frame(width: 52, height: 52)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(selected ? tint.opacity(0.10) : Color.white.opacity(0.035))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(selected ? tint.opacity(0.22) : Color.white.opacity(0.05), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var saveButton: some View {
        Button {
            Task {
                await saveCrew()
            }
        } label: {
            HStack(spacing: 10) {
                if isSaving {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 18, weight: .black))
                }

                Text(tr("cc_create"))
                    .font(.system(size: 16, weight: .black))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Capsule()
                    .fill(canSave ? CreateCrewArenaPalette.green : Color.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.55)
    }
}

// MARK: - Components

private extension CreateCrewBackendView {
    func sectionTitle(eyebrow: String, title: String, italic: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("— \(eyebrow) —")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.34))
                .lineLimit(1)
                .minimumScaleFactor(0.60)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)

                Text(italic)
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.white)
            }
        }
    }

    func fieldBox<Content: View>(
        title: String,
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(tint.opacity(0.13))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.36))

                content()
            }
        }
        .padding(14)
        .background(detailSurface(cornerRadius: 22, tint: tint))
    }

    func previewPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.20), lineWidth: 1)
                    )
            )
            .lineLimit(1)
    }

    func errorCard(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(CreateCrewArenaPalette.coral)

            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(3)

            Spacer()
        }
        .padding(16)
        .background(detailSurface(cornerRadius: 22, tint: CreateCrewArenaPalette.coral))
    }

    func detailSurface(cornerRadius: CGFloat, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.055),
                        CreateCrewArenaPalette.purple.opacity(0.040),
                        Color.white.opacity(0.038)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 14, y: 8)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        CreateCrewArenaPalette.blue.opacity(0.035),
                        CreateCrewArenaPalette.purple.opacity(0.045),
                        Color.white.opacity(0.040)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }
}

// MARK: - Logic

private extension CreateCrewBackendView {
    @MainActor
    func saveCrew() async {
        guard let ownerID = session.currentUserID else { return }

        let cleanName = cleanName
        guard !cleanName.isEmpty else { return }

        if crewStore.crews.count >= 1, !subscriptionManager.isPro {
            Analytics.shared.track("feature_gate_triggered", properties: ["gate": "crew_limit"])
            showPaywall = true
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            _ = try await crewStore.createCrew(
                name: cleanName,
                icon: icon,
                colorHex: colorHex,
                ownerID: ownerID
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    func hexColor(_ hex: String) -> Color {
        Color(arenaHex: hex)
    }
}

// MARK: - Color Hex
