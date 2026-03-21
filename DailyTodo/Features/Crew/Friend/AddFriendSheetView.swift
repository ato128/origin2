//
//  AddFriendSheetView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 21.03.2026.
//

import SwiftUI

struct AddFriendSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var session: SessionStore

    @AppStorage("appTheme") private var appTheme = AppTheme.gradient.rawValue
    private let palette = ThemePalette()

    @State private var username: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Add Friend")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(palette.primaryText)

                        Text("Enter a username and send a friend request.")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Username")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.primaryText)

                        TextField("exampleusername", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.send)
                            .onSubmit {
                                Task {
                                    await sendRequest()
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(palette.secondaryCardFill)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(palette.cardStroke, lineWidth: 1)
                                    )
                            )

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        if let successMessage {
                            Text(successMessage)
                                .font(.caption)
                                .foregroundStyle(.green)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        Task {
                            await sendRequest()
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "person.badge.plus")
                            }

                            Text(isLoading ? "Sending..." : "Send Request")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.accentColor)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading || cleanUsername.isEmpty)

                    Spacer()
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var cleanUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    @MainActor
    private func sendRequest() async {
        guard let currentUserID = session.currentUser?.id else {
            errorMessage = "You need to be logged in."
            return
        }

        guard !cleanUsername.isEmpty else {
            errorMessage = "Please enter a username."
            return
        }

        errorMessage = nil
        successMessage = nil
        isLoading = true

        do {
            await friendStore.loadAllFriendships(currentUserID: currentUserID)
            let targetProfile = try await friendStore.findUserByUsername(cleanUsername)

            if targetProfile.id == currentUserID {
                errorMessage = "You cannot add yourself."
                isLoading = false
                return
            }

            let alreadyExists = friendStore.friendships.contains {
                ($0.requester_id == currentUserID && $0.addressee_id == targetProfile.id) ||
                ($0.requester_id == targetProfile.id && $0.addressee_id == currentUserID)
            }

            if alreadyExists {
                errorMessage = "A friendship or request already exists."
                isLoading = false
                return
            }

            try await friendStore.sendFriendRequest(
                to: targetProfile.id,
                currentUserID: currentUserID
            )

            await friendStore.loadAllFriendships(currentUserID: currentUserID)

            let otherUserIDs = friendStore.friendships.compactMap { friendship -> UUID? in
                if friendship.requester_id == currentUserID {
                    return friendship.addressee_id
                } else if friendship.addressee_id == currentUserID {
                    return friendship.requester_id
                } else {
                    return nil
                }
            }

            await friendStore.loadProfiles(for: otherUserIDs)

           

            successMessage = "Friend request sent to @\(cleanUsername)"
            username = ""

            try? await Task.sleep(nanoseconds: 900_000_000)
            dismiss()
        } catch {
            errorMessage = "User not found or request could not be sent."
        }

        isLoading = false
    }
}
