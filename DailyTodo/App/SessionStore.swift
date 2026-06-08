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

private struct BackendVerificationResponse: Decodable {
    let ok: Bool
    let sent: Bool?
    let alreadyVerified: Bool?
    let error: String?
}

private struct BackendVerificationStatusResponse: Decodable {
    let ok: Bool
    let email: String?
    let isVerified: Bool
    let verifiedAt: String?
    let error: String?
}

@MainActor
final class SessionStore: ObservableObject {
    @Published var currentUser: AppUser? = nil
    @Published var isLoading: Bool = false
    @Published var didResolveInitialSession: Bool = false
    private var didStartInitialSessionResolve: Bool = false

    @Published var pendingVerificationEmail: String? = nil
    @Published var isEmailVerified: Bool = false
    @Published var verificationMessage: String? = nil

    private let storageKey = "dailytodo_mock_user"
    private let pendingEmailStorageKey = "updo_pending_verification_email"
    private let emailVerifiedStorageKey = "updo_cached_email_verified"
    
    init() {
        restoreSession()
        restorePendingVerificationEmail()
    }

    var isSignedIn: Bool {
        currentUser != nil && isEmailVerified
    }

    var currentUserID: UUID? {
        currentUser?.id
    }

    var needsEmailVerification: Bool {
        pendingVerificationEmail != nil && !isEmailVerified
    }
    var shouldShowEmailVerificationGate: Bool {
        didResolveInitialSession &&
        pendingVerificationEmail != nil &&
        !isEmailVerified
    }

    // MARK: - Local Restore

    func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        guard let user = try? JSONDecoder().decode(AppUser.self, from: data) else { return }

        let cachedVerified = UserDefaults.standard.bool(forKey: emailVerifiedStorageKey)
        let pendingEmail = UserDefaults.standard.string(forKey: pendingEmailStorageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let pendingEmail, !pendingEmail.isEmpty, !cachedVerified {
            currentUser = nil
            pendingVerificationEmail = pendingEmail
            isEmailVerified = false
            return
        }

        currentUser = user
        isEmailVerified = cachedVerified

        if cachedVerified {
            pendingVerificationEmail = nil
            removePendingVerificationEmail()
        }
    }
    private func restorePendingVerificationEmail() {
        let email = UserDefaults.standard.string(forKey: pendingEmailStorageKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let email, !email.isEmpty, currentUser == nil {
            pendingVerificationEmail = email
            isEmailVerified = false
        }
    }

    // MARK: - Auth

    func signIn(email: String, password: String) async throws {
        isLoading = true
        didResolveInitialSession = true
        verificationMessage = nil
        defer { isLoading = false }

        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let response = try await SupabaseManager.shared.client.auth.signIn(
                email: cleanEmail,
                password: password
            )

            let user = response.user

            let isVerified = try await fetchBackendVerificationStatus()

            guard isVerified else {
                currentUser = nil
                isEmailVerified = false
                saveCachedEmailVerified(false)
                pendingVerificationEmail = cleanEmail
                savePendingVerificationEmail(cleanEmail)
                verificationMessage = "Emailini onaylaman gerekiyor."
                throw AuthFlowError.emailNotVerified
            }

            try await loadProfileAndSetCurrentUser(userID: user.id)

            isEmailVerified = true
            pendingVerificationEmail = nil
            removePendingVerificationEmail()
            verificationMessage = nil

        } catch let error as AuthFlowError {
            throw error
        } catch {
            let lower = error.localizedDescription.lowercased()

            if lower.contains("email not confirmed") ||
                lower.contains("email_not_confirmed") ||
                lower.contains("not confirmed") {
                pendingVerificationEmail = cleanEmail
                savePendingVerificationEmail(cleanEmail)
                currentUser = nil
                isEmailVerified = false
                verificationMessage = "Emailini onaylaman gerekiyor."
                throw AuthFlowError.emailNotVerified
            }

            throw error
        }
    }

    func signUp(
        fullName: String,
        email: String,
        username: String,
        password: String
    ) async throws {
        isLoading = true
        didResolveInitialSession = true
        verificationMessage = nil
        defer { isLoading = false }

        let cleanFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            print("EMAIL SENT:", cleanEmail)
            print("USERNAME SENT:", cleanUsername)

            _ = try await SupabaseManager.shared.client.auth.signUp(
                email: cleanEmail,
                password: cleanPassword,
                data: [
                    "full_name": AnyJSON.string(cleanFullName),
                    "username": AnyJSON.string(cleanUsername)
                ]
            )

            currentUser = nil
            isEmailVerified = false
            pendingVerificationEmail = cleanEmail
            saveCachedEmailVerified(false)
            savePendingVerificationEmail(cleanEmail)

            try await requestBackendVerificationEmail(email: cleanEmail)

            verificationMessage = "Onay bağlantısı \(cleanEmail) adresine gönderildi."

        } catch {
            print("SIGN UP ERROR FULL:", error)
            print("SIGN UP ERROR DESC:", error.localizedDescription)
            throw error
        }
    }

    func signOut() {
        didResolveInitialSession = true
        didStartInitialSessionResolve = true
        Task {
            try? await SupabaseManager.shared.client.auth.signOut()
        }

        currentUser = nil
        isEmailVerified = false
        pendingVerificationEmail = nil
        verificationMessage = nil
        saveCachedEmailVerified(false)

        UserDefaults.standard.removeObject(forKey: storageKey)
        removePendingVerificationEmail()
    }

    // MARK: - Email Verification

    func refreshEmailVerificationStatus() async {
        isLoading = true
        verificationMessage = nil
        defer { isLoading = false }

        do {
            let authSession = try await SupabaseManager.shared.client.auth.session
            let user = authSession.user

            let verified = try await fetchBackendVerificationStatus()

            guard verified else {
                currentUser = nil
                isEmailVerified = false
                saveCachedEmailVerified(false)

                if pendingVerificationEmail == nil {
                    pendingVerificationEmail = user.email
                    if let email = user.email {
                        savePendingVerificationEmail(email)
                    }
                }

                verificationMessage = "Email henüz onaylanmamış görünüyor."
                return
            }

            try await loadProfileAndSetCurrentUser(userID: user.id)

            isEmailVerified = true
            pendingVerificationEmail = nil
            removePendingVerificationEmail()
            verificationMessage = "Email onaylandı. Devam edebilirsin."

        } catch {
            print("EMAIL VERIFICATION REFRESH FAILED:", error.localizedDescription)
            verificationMessage = "Onay durumu kontrol edilemedi. Biraz sonra tekrar dene."
        }
    }

    func resendVerificationEmail() async {
        guard let email = pendingVerificationEmail?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !email.isEmpty else {
            verificationMessage = "Onay maili için email bulunamadı."
            return
        }

        isLoading = true
        verificationMessage = nil
        defer { isLoading = false }

        do {
            try await resendBackendVerificationEmail(email: email)
            verificationMessage = "Onay maili tekrar gönderildi."
        } catch {
            print("RESEND VERIFICATION EMAIL ERROR:", error.localizedDescription)
            verificationMessage = readableBackendError(error)
        }
    }

    func handleAuthCallback(url: URL) async {
        verificationMessage = nil

        if url.scheme == "dailytodo",
           url.host == "auth",
           url.path.contains("verified") {
            await refreshEmailVerificationStatus()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await SupabaseManager.shared.client.auth.session(from: url)
            await refreshEmailVerificationStatus()
        } catch {
            print("AUTH CALLBACK ERROR:", error.localizedDescription)
            await refreshEmailVerificationStatus()
        }
    }
    func resolveInitialSessionIfNeeded() async {
        if didResolveInitialSession {
            return
        }

        if didStartInitialSessionResolve {
            while !didResolveInitialSession {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            return
        }

        didStartInitialSessionResolve = true
        await restoreSupabaseSessionIfNeeded()
    }

    func restoreSupabaseSessionIfNeeded() async {
        defer {
            didResolveInitialSession = true
        }

        do {
            let authSession = try await SupabaseManager.shared.client.auth.session
            let user = authSession.user

            let verified = try await fetchBackendVerificationStatus()

            guard verified else {
                currentUser = nil
                isEmailVerified = false
                saveCachedEmailVerified(false)

                if let email = user.email {
                    pendingVerificationEmail = email
                    savePendingVerificationEmail(email)
                }

                print("⚠️ SUPABASE SESSION EXISTS BUT CUSTOM EMAIL NOT VERIFIED")
                return
            }

            try await loadProfileAndSetCurrentUser(userID: user.id)

            isEmailVerified = true
            pendingVerificationEmail = nil
            removePendingVerificationEmail()

            print("✅ SUPABASE SESSION RESTORED:", user.id.uuidString)
        } catch {
            print("⚠️ SUPABASE SESSION RESTORE FAILED:", error.localizedDescription)

            if currentUser == nil {
                isEmailVerified = false
            }
        }
    }
    

    // MARK: - Backend Verification API

    private func backendURL(path: String) throws -> URL {
        guard let url = URL(string: "\(ChatBackendEnvironment.httpBaseURL)\(path)") else {
            throw AuthFlowError.invalidBackendURL
        }

        return url
    }

    private func accessToken() async throws -> String {
        let session = try await SupabaseManager.shared.client.auth.session
        return session.accessToken
    }

    private func makeBackendRequest(
        path: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> URLRequest {
        let token = try await accessToken()
        let url = try backendURL(path: path)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        return request
    }

    private func requestBackendVerificationEmail(email: String) async throws {
        let request = try await makeBackendRequest(
            path: "/v1/auth/request-email-verification",
            method: "POST",
            body: [
                "email": email
            ]
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthFlowError.invalidBackendResponse
        }

        let decoded = try JSONDecoder().decode(BackendVerificationResponse.self, from: data)

        guard (200...299).contains(http.statusCode), decoded.ok else {
            throw AuthFlowError.backend(decoded.error ?? "Onay maili gönderilemedi.")
        }
    }

    private func resendBackendVerificationEmail(email: String) async throws {
        let request = try await makeBackendRequest(
            path: "/v1/auth/resend-email-verification",
            method: "POST",
            body: [
                "email": email
            ]
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthFlowError.invalidBackendResponse
        }

        let decoded = try JSONDecoder().decode(BackendVerificationResponse.self, from: data)

        guard (200...299).contains(http.statusCode), decoded.ok else {
            throw AuthFlowError.backend(decoded.error ?? "Onay maili tekrar gönderilemedi.")
        }
    }

    private func fetchBackendVerificationStatus() async throws -> Bool {
        let request = try await makeBackendRequest(
            path: "/v1/auth/email-verification-status",
            method: "GET"
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthFlowError.invalidBackendResponse
        }

        let decoded = try JSONDecoder().decode(BackendVerificationStatusResponse.self, from: data)

        guard (200...299).contains(http.statusCode), decoded.ok else {
            throw AuthFlowError.backend(decoded.error ?? "Onay durumu alınamadı.")
        }

        return decoded.isVerified
    }

    // MARK: - Profile

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

    private func loadProfileAndSetCurrentUser(userID: UUID) async throws {
        let profileResponse = try await SupabaseManager.shared.client
            .from("profiles")
            .select()
            .eq("id", value: userID.uuidString)
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

    // MARK: - Helpers

    private func saveUser(_ user: AppUser) {
        guard let data = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
    
    private func saveCachedEmailVerified(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: emailVerifiedStorageKey)
    }

    private func savePendingVerificationEmail(_ email: String) {
        UserDefaults.standard.set(email, forKey: pendingEmailStorageKey)
    }

    private func removePendingVerificationEmail() {
        UserDefaults.standard.removeObject(forKey: pendingEmailStorageKey)
    }

    private func readableBackendError(_ error: Error) -> String {
        let message = error.localizedDescription

        if message.lowercased().contains("too many requests") {
            return "Çok sık denedin. Biraz bekleyip tekrar dene."
        }

        return message
    }
}

// MARK: - Auth Flow Error

enum AuthFlowError: LocalizedError {
    case emailNotVerified
    case invalidBackendURL
    case invalidBackendResponse
    case backend(String)

    var errorDescription: String? {
        switch self {
        case .emailNotVerified:
            return "Emailini onaylaman gerekiyor."
        case .invalidBackendURL:
            return "Backend bağlantı adresi geçersiz."
        case .invalidBackendResponse:
            return "Backend yanıtı okunamadı."
        case .backend(let message):
            return message
        }
    }
}
