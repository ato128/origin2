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

    var body: some View {
        NavigationStack {
            formContent
                .navigationTitle("Create Crew")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var formContent: some View {
        Form {
            Section("Crew Name") {
                TextField("App Dev Crew", text: $crewName)
            }

            Section("Icon") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 42, height: 42)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(
                                                selectedIcon == icon
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

            Section("Color") {
                HStack(spacing: 12) {
                    ForEach(colorOptions, id: \.self) { hex in
                        Button {
                            selectedColorHex = hex
                        } label: {
                            Circle()
                                .fill(hexColor(hex))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            selectedColorHex == hex ? Color.primary : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                Button("Create Crew") {
                    createCrew()
                }
                .disabled(crewName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func createCrew() {
        guard let userID = SupabaseManager.shared.client.auth.currentUser?.id else { return }

        Task {
            do {
                let dto = try await crewStore.createCrew(
                    name: crewName,
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

            } catch {
                print("CREATE CREW ERROR:", error.localizedDescription)
            }
        }
    }
}
