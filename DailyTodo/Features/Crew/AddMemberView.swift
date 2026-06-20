//
//  AddMemberView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 12.03.2026.
//

import SwiftUI
import SwiftData

struct AddMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var crew: Crew

    @State private var name: String = ""
    @State private var role: String = ""
    @State private var icon: String = "person.fill"

    @FocusState private var nameFocused: Bool
    @FocusState private var roleFocused: Bool

    private let iconOptions = [
        "person.fill",
        "paintpalette.fill",
        "gearshape.fill",
        "books.vertical.fill",
        "laptopcomputer",
        "hammer.fill",
        "graduationcap.fill"
    ]

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                UpdoTheme.background
                    .ignoresSafeArea()

                Circle()
                    .fill(UpdoTheme.cyan.opacity(0.07))
                    .frame(width: 280, height: 280)
                    .blur(radius: 90)
                    .offset(x: 150, y: -260)
                    .ignoresSafeArea()

                Circle()
                    .fill(UpdoTheme.purple.opacity(0.09))
                    .frame(width: 320, height: 320)
                    .blur(radius: 100)
                    .offset(x: -170, y: 380)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        previewSection
                        fieldSection(label: tr("common_name_caps"), placeholder: tr("am_member_name_ph"), text: $name, focused: $nameFocused, capitalization: .words)
                        fieldSection(label: tr("common_role_caps"), placeholder: tr("am_role_ph"), text: $role, focused: $roleFocused, capitalization: .words)
                        iconSection
                        addButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(tr("am_add_member"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("common_cancel")) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(UpdoTheme.cyan)
    }

    private var previewSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(UpdoTheme.cyan.opacity(0.18))
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(UpdoTheme.cyan)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: icon)

            Text(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? tr("am_new_member") : name)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .primary)
                .lineLimit(1)

            if !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(role)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func fieldSection(
        label: String,
        placeholder: String,
        text: Binding<String>,
        focused: FocusState<Bool>.Binding,
        capitalization: TextInputAutocapitalization
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel(label)

            TextField(placeholder, text: text)
                .focused(focused)
                .textInputAutocapitalization(capitalization)
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

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(iconOptions, id: \.self) { item in
                    let isSelected = icon == item

                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                            icon = item
                        }
                    } label: {
                        Image(systemName: item)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(isSelected ? UpdoTheme.cyan : .white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.white.opacity(0.045))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(
                                                isSelected ? UpdoTheme.cyan : Color.white.opacity(0.08),
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

    private var addButton: some View {
        Button {
            addMember()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 17, weight: .bold))

                Text(tr("am_add_member"))
                    .font(.system(size: 17, weight: .bold))
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
            .opacity(canAdd ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!canAdd)
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

    private func addMember() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRole = role.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedRole.isEmpty else { return }

        let member = CrewMember(
            crewID: crew.id,
            name: trimmedName,
            role: trimmedRole,
            isOnline: false,
            avatarSymbol: icon
        )

        modelContext.insert(member)

        let activity = CrewActivity(
            crewID: crew.id,
            memberName: "You",
            actionText: "added \(trimmedName) to the crew"
        )
        modelContext.insert(activity)

        try? modelContext.save()
        HapticManager.shared.success()
        dismiss()
    }
}
