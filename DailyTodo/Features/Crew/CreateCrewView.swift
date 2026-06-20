//
//  CreateCrewView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 10.03.2026.
//

import SwiftUI
import SwiftData
import Supabase

struct CreateCrewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var crewStore = CrewStore()

    @State private var crewName: String = ""
    @State private var selectedIcon: String = "person.3.fill"
    @State private var selectedColorHex: String = "#3B82F6"

    @State private var isCreating: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorText: String = ""

    @FocusState private var nameFocused: Bool

    private let iconOptions = [
        "person.3.fill",
        "books.vertical.fill",
        "hammer.fill",
        "laptopcomputer",
        "graduationcap.fill",
        "bolt.fill"
    ]

    private let colorOptions = [
        "#3B82F6",
        "#22C55E",
        "#F59E0B",
        "#EF4444",
        "#8B5CF6",
        "#14B8A6"
    ]

    private var trimmedName: String {
        crewName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Updo identity background: deep navy + soft accent glows
                UpdoTheme.background
                    .ignoresSafeArea()

                Circle()
                    .fill(Color(updoHex: selectedColorHex).opacity(0.10))
                    .frame(width: 300, height: 300)
                    .blur(radius: 95)
                    .offset(x: 150, y: -260)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.4), value: selectedColorHex)

                Circle()
                    .fill(UpdoTheme.purple.opacity(0.09))
                    .frame(width: 320, height: 320)
                    .blur(radius: 100)
                    .offset(x: -170, y: 380)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        previewSection
                        nameSection
                        iconSection
                        colorSection
                        createButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(tr("cc_create"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("common_cancel")) { dismiss() }
                }
            }
            .alert(tr("common_error_title"), isPresented: $showErrorAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(errorText)
            }
        }
        .preferredColorScheme(.dark)
        .tint(UpdoTheme.cyan)
    }

    // MARK: - Sections

    private var previewSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(updoHex: selectedColorHex).opacity(0.18))
                    .frame(width: 88, height: 88)

                Circle()
                    .stroke(Color(updoHex: selectedColorHex).opacity(0.35), lineWidth: 1.5)
                    .frame(width: 88, height: 88)

                Image(systemName: selectedIcon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color(updoHex: selectedColorHex))
            }
            .shadow(color: Color(updoHex: selectedColorHex).opacity(0.25), radius: 16, y: 6)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedIcon)
            .animation(.easeInOut(duration: 0.3), value: selectedColorHex)

            Text(trimmedName.isEmpty ? "Yeni Crew" : trimmedName)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(trimmedName.isEmpty ? .secondary : .primary)
                .lineLimit(1)
                .animation(nil, value: trimmedName)

            Text(tr("cc_tagline"))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(tr("cc_name_caps"))

            TextField(tr("cc_name_ph"), text: $crewName)
                .focused($nameFocused)
                .textInputAutocapitalization(.words)
                .font(.system(size: 17, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.045))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                )
        }
    }

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(tr("common_icon_caps"))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(iconOptions, id: \.self) { icon in
                    let isSelected = selectedIcon == icon

                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                            selectedIcon = icon
                        }
                    } label: {
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(isSelected ? Color(updoHex: selectedColorHex) : .white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.045))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(
                                                isSelected ? Color(updoHex: selectedColorHex) : Color.white.opacity(0.08),
                                                lineWidth: isSelected ? 1.5 : 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(tr("common_color_caps"))

            HStack(spacing: 12) {
                ForEach(colorOptions, id: \.self) { hex in
                    let isSelected = selectedColorHex == hex

                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedColorHex = hex
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(updoHex: hex))
                                .frame(width: 32, height: 32)

                            if isSelected {
                                Circle()
                                    .stroke(Color.white.opacity(0.95), lineWidth: 2.2)
                                    .frame(width: 40, height: 40)

                                Circle()
                                    .stroke(Color(updoHex: hex).opacity(0.22), lineWidth: 6)
                                    .frame(width: 46, height: 46)
                            }
                        }
                        .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var createButton: some View {
        Button {
            createCrew()
        } label: {
            HStack(spacing: 8) {
                if isCreating {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 17, weight: .bold))

                    Text(tr("cc_create"))
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [UpdoTheme.cyan, Color(updoHex: "#22D3EE")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .shadow(color: UpdoTheme.cyan.opacity(0.3), radius: 14, y: 6)
            .opacity(trimmedName.isEmpty ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(trimmedName.isEmpty || isCreating)
        .padding(.top, 8)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(.secondary.opacity(0.82))
            .padding(.leading, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func createCrew() {
        guard let userID = SupabaseManager.shared.client.auth.currentUser?.id else { return }
        guard !isCreating else { return }

        isCreating = true
        HapticManager.shared.action()

        Task {
            do {
                let dto = try await crewStore.createCrew(
                    name: trimmedName,
                    icon: selectedIcon,
                    colorHex: selectedColorHex,
                    ownerID: userID
                )

                let localCrew = Crew(
                    id: dto.id,
                    backendCrewID: dto.id,
                    name: dto.name,
                    icon: dto.icon,
                    colorHex: dto.color_hex
                )

                modelContext.insert(localCrew)
                try? modelContext.save()

                await MainActor.run {
                    isCreating = false
                    HapticManager.shared.success()
                    dismiss()
                }
            } catch {
                Log.debug("CREATE CREW ERROR:", error.localizedDescription)
                await MainActor.run {
                    isCreating = false
                    errorText = tr("cc_create_error")
                    showErrorAlert = true
                    HapticManager.shared.error()
                }
            }
        }
    }
}
