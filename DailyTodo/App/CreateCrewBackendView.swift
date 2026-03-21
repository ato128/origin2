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

    var body: some View {
        NavigationStack {
            Form {
                Section("Crew") {
                    TextField("Crew name", text: $name)
                    TextField("SF Symbol icon", text: $icon)
                    TextField("Color hex", text: $colorHex)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Create Crew")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "Saving..." : "Save") {
                        Task { await saveCrew() }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    @MainActor
    private func saveCrew() async {
        guard let ownerID = session.currentUserID else { return }

        isSaving = true
        errorMessage = nil

        do {
          _ =  try await crewStore.createCrew(
                name: name,
                icon: icon.isEmpty ? "person.3.fill" : icon,
                colorHex: colorHex.isEmpty ? "#4F8CFF" : colorHex,
                ownerID: ownerID
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
