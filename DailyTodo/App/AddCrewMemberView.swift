//
//  AddMemberView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//
import SwiftUI

struct AddCrewMemberView: View {
    let crewID: UUID

    @EnvironmentObject var crewStore: CrewStore
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    Task {
                        await addMember()
                    }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Add Member")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .disabled(isLoading || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @MainActor
    func addMember() async {
        let clean = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
                    try await crewStore.addMember(by: username, to: crewID)
                    dismiss()
                } catch {
                    print("ADD MEMBER VIEW ERROR:", error.localizedDescription)
                    errorMessage = error.localizedDescription
                }
    }
}
