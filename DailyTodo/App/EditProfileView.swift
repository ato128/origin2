//
//  EditProfileView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: SessionStore

    @State private var fullName: String = ""
    @State private var username: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    VStack(spacing: 14) {
                        TextField("Full name", text: $fullName)
                            .textInputAutocapitalization(.words)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .foregroundStyle(.white)

                        TextField("Username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .foregroundStyle(.white)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task {
                            await saveProfile()
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.blue)

                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Save Changes")
                                    .font(.headline.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(height: 56)
                    }
                    .disabled(isSaving || fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .onAppear {
                fullName = session.currentUser?.fullName ?? ""
                username = session.currentUser?.username ?? ""
            }
        }
    }

    @MainActor
    private func saveProfile() async {
        isSaving = true
        errorMessage = nil

        do {
            try await session.updateProfile(fullName: fullName, username: username)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
