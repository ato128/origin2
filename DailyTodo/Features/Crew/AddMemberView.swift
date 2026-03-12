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

    private let iconOptions = [
        "person.fill",
        "paintpalette.fill",
        "gearshape.fill",
        "books.vertical.fill",
        "laptopcomputer",
        "hammer.fill",
        "graduationcap.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Member name", text: $name)
                }

                Section("Role") {
                    TextField("Designer", text: $role)
                }

                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(iconOptions, id: \.self) { item in
                                Button {
                                    icon = item
                                } label: {
                                    Image(systemName: item)
                                        .font(.title3)
                                        .frame(width: 42, height: 42)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(
                                                    icon == item
                                                    ? Color.accentColor.opacity(0.18)
                                                    : Color.secondary.opacity(0.10)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button("Add Member") {
                        addMember()
                    }
                    .disabled(
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
        }
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
        dismiss()
    }
}
