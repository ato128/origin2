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
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Button {
                    Task {
                        await addMember()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Add Member")
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .cornerRadius(12)

                Spacer()
            }
            .padding()
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    func addMember() async {
        guard !username.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await crewStore.addMember(by: username, to: crewID)
            dismiss()
        } catch {
            errorMessage = "User not found or already in crew"
        }

        isLoading = false
    }
}
