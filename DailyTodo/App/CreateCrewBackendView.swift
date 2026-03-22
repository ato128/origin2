//
//  CreateCrewBackendView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import SwiftUI

struct CreateCrewBackendView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var crewStore: CrewStore

    @State private var name = ""
    @State private var icon = "person.3.fill"
    @State private var colorHex = "#4F8CFF"
    @State private var isSaving = false
    @State private var errorMessage: String?

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

    private var canSave: Bool {
        !isSaving && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        previewCard
                        crewInfoSection
                        iconPickerSection
                        colorPickerSection

                        if let errorMessage {
                            errorCard(errorMessage)
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Create Crew")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveCrew() }
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                                .font(.headline.bold())
                        }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

private extension CreateCrewBackendView {

    var previewCard: some View {
        let tint = hexColor(colorHex)

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.28),
                                    tint.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 76, height: 76)

                    Image(systemName: icon)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your Crew" : name)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Build together, focus together, finish together.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                previewPill(text: "Preview", tint: tint)
                previewPill(text: icon, tint: .white.opacity(0.7))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    var crewInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Crew Info")

            VStack(spacing: 0) {
                textFieldRow(
                    title: "Crew name",
                    placeholder: "Enter crew name",
                    text: $name
                )

                Divider()
                    .overlay(Color.white.opacity(0.08))

                infoRow(
                    title: "Selected icon",
                    value: icon
                )

                Divider()
                    .overlay(Color.white.opacity(0.08))

                infoRow(
                    title: "Selected color",
                    value: colorHex
                )
            }
            .background(sectionCardBackground)
        }
    }

    var iconPickerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Choose Icon")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 10
            ) {
                ForEach(iconOptions, id: \.self) { item in
                    let isSelected = icon == item
                    let tint = hexColor(colorHex)

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            icon = item
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(isSelected ? tint.opacity(0.18) : Color.white.opacity(0.04))

                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(
                                    isSelected ? tint.opacity(0.45) : Color.white.opacity(0.06),
                                    lineWidth: 1
                                )

                            Image(systemName: item)
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(isSelected ? tint : .white.opacity(0.88))
                        }
                        .frame(height: 58)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(sectionCardBackground)
        }
    }

    var colorPickerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Choose Color")

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                spacing: 12
            ) {
                ForEach(colorOptions, id: \.self) { item in
                    let isSelected = colorHex == item
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

                            if isSelected {
                                Circle()
                                    .stroke(Color.white.opacity(0.95), lineWidth: 3)
                                    .frame(width: 50, height: 50)

                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(sectionCardBackground)
        }
    }

    func errorCard(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.red)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.red.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.red.opacity(0.20), lineWidth: 1)
                    )
            )
    }

    func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.title3.bold())
            .foregroundStyle(.white)
    }

    func textFieldRow(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.65))

            TextField(placeholder, text: text)
                .font(.body)
                .foregroundStyle(.white)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
        }
        .padding(16)
    }

    func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.72))

            Spacer()

            Text(value)
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .font(.subheadline)
        .padding(16)
    }

    func previewPill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.14))
            )
            .foregroundStyle(tint)
    }

    var sectionCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
    }
}

private extension CreateCrewBackendView {
    @MainActor
    func saveCrew() async {
        guard let ownerID = session.currentUserID else { return }

        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }

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
}
