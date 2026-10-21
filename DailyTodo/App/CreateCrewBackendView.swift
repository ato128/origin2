//
//  CreateCrewBackendView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import SwiftUI
import UIKit
import PhotosUI

private enum CreateCrewArenaPalette {
    static let backgroundTop = Color.adaptive(light: Color(arenaHex: "#FBF6EC"), dark: Color(arenaHex: "#05060D"))
    static let backgroundMid = Color.adaptive(light: Color(arenaHex: "#F4EEE1"), dark: Color(arenaHex: "#070713"))
    static let backgroundBottom = Color.adaptive(light: Color(arenaHex: "#EFE7D6"), dark: Color(arenaHex: "#07040C"))

    static let blue = Color(arenaHex: "#1593FF")
    static let cyan = Color(arenaHex: "#2DD4FF")
    static let purple = Color(arenaHex: "#7C3AED")
    static let coral = Color(arenaHex: "#FF5A44")
    static let gold = Color(arenaHex: "#FBBF24")
    static let green = Color(arenaHex: "#A3E635")
    static let surface = Color.adaptive(light: Color(arenaHex: "#FFFDF7"), dark: Color(arenaHex: "#101118"))

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
    @State private var photoItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
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

            if UIDevice.current.userInterfaceIdiom == .pad {
                padLayout
            } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: 4)

                    header

                    crewPhotoCard

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
        }
        .updoPadSheet()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: "crew_limit")
        }
    }
}

// MARK: - iPad

private extension CreateCrewBackendView {
    /// iPad: the crew as it will look (photo + live preview) stays on the
    /// left while you shape it on the right.
    var padLayout: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
                .padding(.horizontal, 32)
                .padding(.top, 28)

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    crewPhotoCard
                    padPreviewCard
                    padNextStepsCard
                }
                .frame(width: 400, alignment: .top)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        crewInfoCard
                        iconPickerCard
                        colorPickerCard

                        if let errorMessage {
                            errorCard(errorMessage)
                        }

                        saveButton
                    }
                    .padding(.bottom, 28)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 32)
        }
        .frame(maxWidth: 1040)
        .frame(maxWidth: .infinity)
    }
}

private extension CreateCrewBackendView {
    var padDisplayName: String { cleanName.isEmpty ? tr("ccp_placeholder_name") : cleanName }

    /// The crew's mark: the picked photo, or its icon on its color.
    func padCrewMark(size: CGFloat) -> some View {
        let tint = hexColor(colorHex)
        let shape = RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
        return ZStack {
            if let pickedImage {
                Image(uiImage: pickedImage).resizable().scaledToFill()
            } else {
                shape.fill(LinearGradient(colors: [tint, CreateCrewArenaPalette.purple.opacity(0.85)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: icon)
                    .font(.system(size: size * 0.42, weight: .black))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
    }

    /// Live preview: the crew as it will appear in Social and in its chat.
    var padPreviewCard: some View {
        let tint = hexColor(colorHex)
        return VStack(alignment: .leading, spacing: 14) {
            Text(tr("ccp_preview_caps"))
                .font(.system(size: 10.5, weight: .black, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(CreateCrewArenaPalette.cyan)

            // As a card in the Social list
            HStack(spacing: 13) {
                ZStack(alignment: .bottomTrailing) {
                    padCrewMark(size: 54)
                    Circle()
                        .fill(Color(arenaHex: "#34D44A"))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(CreateCrewArenaPalette.surface, lineWidth: 2))
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(padDisplayName)
                        .font(.system(size: 17, weight: .black))
                        .foregroundStyle(UpdoTheme.textPrimary)
                        .lineLimit(1)
                    Text(tr("ccp_members_line"))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(UpdoTheme.filmy(0.4))
                    Capsule()
                        .fill(LinearGradient(colors: [tint, CreateCrewArenaPalette.purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 120, height: 4)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(UpdoTheme.filmy(0.3))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(UpdoTheme.filmy(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(UpdoTheme.border, lineWidth: 1))

            // As the chat header + a first message
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    padCrewMark(size: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(padDisplayName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(UpdoTheme.textPrimary)
                            .lineLimit(1)
                        Text(tr("ccp_chat_sub"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(UpdoTheme.filmy(0.45))
                    }
                    Spacer(minLength: 0)
                }
                HStack {
                    Spacer(minLength: 40)
                    Text(tr("ccp_chat_bubble"))
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tint))
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(UpdoTheme.filmy(0.035)))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [tint.opacity(0.14), CreateCrewArenaPalette.surface.opacity(0.97)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(tint.opacity(0.22), lineWidth: 1))
        )
        .animation(.snappy, value: colorHex)
        .animation(.snappy, value: icon)
    }

    /// What happens after "Create".
    var padNextStepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("ccp_next_caps"))
                .font(.system(size: 10.5, weight: .black, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(CreateCrewArenaPalette.gold)
            padStep(1, title: tr("ccp_s1_title"), subtitle: tr("ccp_s1_sub"))
            padStep(2, title: tr("ccp_s2_title"), subtitle: tr("ccp_s2_sub"))
            padStep(3, title: tr("ccp_s3_title"), subtitle: tr("ccp_s3_sub"))
        }
        .padding(18)
        .background(cardBackground)
    }

    func padStep(_ number: Int, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .frame(width: 26, height: 26)
                .background(Circle().fill(CreateCrewArenaPalette.gold))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(UpdoTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(UpdoTheme.filmy(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
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
                    UpdoTheme.overlayScrim(0.16),
                    Color.clear,
                    UpdoTheme.overlayScrim(0.42)
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
                    .foregroundStyle(UpdoTheme.textPrimary)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(UpdoTheme.filmy(0.075))
                            .overlay(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .stroke(UpdoTheme.filmy(0.10), lineWidth: 1)
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
                    .foregroundStyle(UpdoTheme.textPrimary)
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
                        .fill(canSave ? CreateCrewArenaPalette.green : UpdoTheme.filmy(0.12))
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
                            .foregroundStyle(UpdoTheme.textPrimary)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("ccb_preview_caps"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(CreateCrewArenaPalette.cyan)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(displayName)
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(UpdoTheme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.62)

                        Text("crew")
                            .font(.system(size: 25, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(CreateCrewArenaPalette.cyan)
                    }

                    Text(tr("ccb_subtitle"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(UpdoTheme.filmy(0.50))
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
                .shadow(color: UpdoTheme.cardShadow(0.24), radius: 20, y: 12)
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
                    .foregroundStyle(UpdoTheme.textPrimary)
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
                    .foregroundStyle(UpdoTheme.filmy(0.38))
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
                                .fill(selected ? tint.opacity(0.18) : UpdoTheme.filmy(0.045))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(selected ? tint.opacity(0.42) : UpdoTheme.filmy(0.07), lineWidth: 1)
                                )

                            Image(systemName: item)
                                .font(.system(size: 21, weight: .black))
                                .foregroundStyle(selected ? tint : UpdoTheme.filmy(0.78))
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
                                    .stroke(UpdoTheme.filmy(0.95), lineWidth: 3)
                                    .frame(width: 52, height: 52)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(UpdoTheme.textPrimary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(selected ? tint.opacity(0.10) : UpdoTheme.filmy(0.035))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(selected ? tint.opacity(0.22) : UpdoTheme.filmy(0.05), lineWidth: 1)
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
                    .fill(canSave ? CreateCrewArenaPalette.green : UpdoTheme.filmy(0.12))
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
                .foregroundStyle(UpdoTheme.filmy(0.34))
                .lineLimit(1)
                .minimumScaleFactor(0.60)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(UpdoTheme.textPrimary)

                Text(italic)
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(UpdoTheme.textPrimary)
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
                    .foregroundStyle(UpdoTheme.filmy(0.36))

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
                .foregroundStyle(UpdoTheme.filmy(0.74))
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
                        UpdoTheme.filmy(0.038)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: UpdoTheme.cardShadow(0.22), radius: 14, y: 8)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        CreateCrewArenaPalette.blue.opacity(0.035),
                        CreateCrewArenaPalette.purple.opacity(0.045),
                        UpdoTheme.filmy(0.040)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(UpdoTheme.filmy(0.075), lineWidth: 1)
            )
            .shadow(color: UpdoTheme.cardShadow(0.22), radius: 16, y: 9)
    }
}

// MARK: - Logic

private extension CreateCrewBackendView {
    var crewPhotoCard: some View {
        HStack(spacing: 14) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let pickedImage {
                            Image(uiImage: pickedImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            hexColor(colorHex).opacity(0.95),
                                            Color(arenaHex: "#7C3AED").opacity(0.82)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: icon)
                                        .font(.system(size: 26, weight: .black))
                                        .foregroundStyle(UpdoTheme.textPrimary)
                                )
                        }
                    }

                    Image(systemName: "camera.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(UpdoTheme.textPrimary)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle().fill(hexColor(colorHex))
                                .overlay(Circle().stroke(Color.black.opacity(0.45), lineWidth: 2))
                        )
                        .offset(x: 4, y: 4)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(tr("ccb_crew_photo"))
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(UpdoTheme.textPrimary)

                Text(tr("ccb_crew_photo_sub"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(UpdoTheme.filmy(0.5))
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(UpdoTheme.filmy(0.045))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(UpdoTheme.filmy(0.06), lineWidth: 1)
                )
        )
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run { pickedImage = image }
                }
            }
        }
    }

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
            let created = try await crewStore.createCrew(
                name: cleanName,
                icon: icon,
                colorHex: colorHex,
                ownerID: ownerID
            )

            // Kurulumda foto seçildiyse yeni crew'a yükle.
            if let pickedImage {
                let resized = crewDownscaledImage(pickedImage, maxDimension: 512)
                RemoteAvatarStore.shared.overrideLocal(resized, for: created.id)
                if let jpeg = resized.jpegData(compressionQuality: 0.82) {
                    await AvatarBackendClient.shared.uploadCrewAvatar(
                        crewID: created.id.uuidString,
                        jpegData: jpeg
                    )
                }
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }

    func hexColor(_ hex: String) -> Color {
        Color(arenaHex: hex)
    }

    private func crewDownscaledImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let largest = max(image.size.width, image.size.height)
        guard largest > maxDimension else { return image }

        let scale = maxDimension / largest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

// MARK: - Color Hex
