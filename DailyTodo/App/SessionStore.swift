//
//  SessionStore.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.03.2026.
//

import SwiftUI
import Combine
import Supabase

struct AppUser: Codable, Equatable {
    let id: UUID
    var fullName: String
    var email: String
    var username: String
}

struct Profile: Decodable {
    let id: UUID
    let email: String
    let username: String?
    let full_name: String?
}

@MainActor
final class SessionStore: ObservableObject {
    @Published var currentUser: AppUser? = nil
    @Published var isLoading: Bool = false

    private let storageKey = "dailytodo_mock_user"

    init() {
        restoreSession()
    }

    var isSignedIn: Bool {
        currentUser != nil
    }
    
    var currentUserID: UUID? {
        currentUser?.id
    }

    func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        guard let user = try? JSONDecoder().decode(AppUser.self, from: data) else { return }
        currentUser = user
    }

    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        let response = try await SupabaseManager.shared.client.auth.signIn(
            email: cleanEmail,
            password: password
        )

        let user = response.user

        let profileResponse = try await SupabaseManager.shared.client
            .from("profiles")
            .select()
            .eq("id", value: user.id.uuidString)
            .single()
            .execute()

        let profile = try JSONDecoder().decode(Profile.self, from: profileResponse.data)

        let appUser = AppUser(
            id: profile.id,
            fullName: profile.full_name ?? "User",
            email: profile.email,
            username: profile.username ?? ""
        )

        currentUser = appUser
        saveUser(appUser)
    }

    func signUp(fullName: String, email: String, username: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let cleanFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            print("EMAIL SENT:", cleanEmail)
            print("USERNAME SENT:", cleanUsername)

            let response = try await SupabaseManager.shared.client.auth.signUp(
                email: cleanEmail,
                password: cleanPassword,
                data: [
                    "full_name": AnyJSON.string(cleanFullName),
                    "username": AnyJSON.string(cleanUsername)
                ]
            )

            let user = response.user

            let appUser = AppUser(
                id: user.id,
                fullName: cleanFullName,
                email: cleanEmail,
                username: cleanUsername
            )

            currentUser = appUser
            saveUser(appUser)

        } catch {
            print("SIGN UP ERROR FULL:", error)
            print("SIGN UP ERROR DESC:", error.localizedDescription)
            throw error
        }
    }

    func signOut() {
        Task {
            try? await SupabaseManager.shared.client.auth.signOut()
        }
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    func updateProfile(fullName: String, username: String) async throws {
        guard let currentUser else { return }

        let cleanFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        try await SupabaseManager.shared.client
            .from("profiles")
            .update([
                "full_name": cleanFullName,
                "username": cleanUsername
            ])
            .eq("id", value: currentUser.id.uuidString)
            .execute()

        var updatedUser = currentUser
        updatedUser.fullName = cleanFullName
        updatedUser.username = cleanUsername

        self.currentUser = updatedUser
        saveUser(updatedUser)
    }

    private func saveUser(_ user: AppUser) {
        guard let data = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
