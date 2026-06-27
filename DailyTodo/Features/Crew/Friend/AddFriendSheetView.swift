//
//  AddFriendSheetView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 21.03.2026.
//

import SwiftUI

private enum AddFriendArenaPalette {
    static let backgroundTop = Color(arenaHex: "#05060D")
    static let backgroundMid = Color(arenaHex: "#070713")
    static let backgroundBottom = Color(arenaHex: "#07040C")

    static let blue = Color(arenaHex: "#1593FF")
    static let cyan = Color(arenaHex: "#2DD4FF")
    static let purple = Color(arenaHex: "#7C3AED")
    static let coral = Color(arenaHex: "#FF5A44")
    static let gold = Color(arenaHex: "#FBBF24")
    static let green = Color(arenaHex: "#A3E635")
    static let surface = Color(arenaHex: "#101118")

    static var appGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(arenaHex: "#1E6BFF"),
                Color(arenaHex: "#7C3AED")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct AddFriendSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var session: SessionStore
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared

    @State private var username: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showPaywall = false

    private var cleanUsername: String {
        username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var canSubmit: Bool {
        !cleanUsername.isEmpty && !isLoading
    }

    var body: some View {
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: 4)

                    header

                    heroCard

                    usernameCard

                    helperCard

                    if let errorMessage {
                        errorCard(errorMessage)
                    }

                    if let successMessage {
                        successCard(successMessage)
                    }

                    sendButton

                    Color.clear.frame(height: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: "friend_limit")
        }
    }
}

// MARK: - Layout

private extension AddFriendSheetView {
    var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    AddFriendArenaPalette.backgroundTop,
                    AddFriendArenaPalette.backgroundMid,
                    AddFriendArenaPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(AddFriendArenaPalette.blue.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 96)
                .offset(x: 165, y: -245)

            Circle()
                .fill(AddFriendArenaPalette.purple.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: -175, y: 500)

            Circle()
                .fill(AddFriendArenaPalette.cyan.opacity(0.08))
                .frame(width: 270, height: 270)
                .blur(radius: 100)
                .offset(x: 170, y: 280)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.16),
                    Color.clear,
                    Color.black.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark").accessibilityLabel(tr("event_close"))
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(Color.white.opacity(0.075))
                            .overlay(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)

            Spacer()

            VStack(spacing: 3) {
                Text("ADD FRIEND")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(AddFriendArenaPalette.cyan)

                Text(!appLanguageIsEnglish() ? tr("af_add_friend") : "Add Friend")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(.white)
            }

            Spacer()

            Button {
                Task {
                    await sendRequest()
                }
            } label: {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(.black)
                    }
                }
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(canSubmit ? AddFriendArenaPalette.green : Color.white.opacity(0.12))
                )
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.55)
        }
    }
}

// MARK: - Cards

private extension AddFriendSheetView {
    var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AddFriendArenaPalette.appGradient)
                    .frame(width: 66, height: 66)
                    .overlay(
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 29, weight: .black))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("SOCIAL GRAPH")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(AddFriendArenaPalette.cyan)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(!appLanguageIsEnglish() ? "Yeni" : "New")
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(.white)

                        Text(!appLanguageIsEnglish() ? tr("ch_friend_word") : "friend")
                            .font(.system(size: 25, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(AddFriendArenaPalette.cyan)
                    }

                    Text(!appLanguageIsEnglish()
                         ? tr("af_subtitle")
                         : "Send a friend request by username and grow your study circle.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                        .lineLimit(3)
                }

                Spacer()
            }

            HStack(spacing: 9) {
                pill(text: "REQUEST", tint: AddFriendArenaPalette.green)

                if !cleanUsername.isEmpty {
                    pill(text: "@\(cleanUsername)", tint: AddFriendArenaPalette.gold)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AddFriendArenaPalette.blue.opacity(0.12),
                            AddFriendArenaPalette.purple.opacity(0.12),
                            AddFriendArenaPalette.surface.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(AddFriendArenaPalette.blue.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.24), radius: 20, y: 12)
        )
    }

    var usernameCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                eyebrow: "USER LOOKUP",
                title: !appLanguageIsEnglish() ? tr("uname_w1") : "Username",
                italic: !appLanguageIsEnglish() ? tr("uname_w2") : "search"
            )

            fieldBox(
                title: "USERNAME",
                icon: "at",
                tint: AddFriendArenaPalette.cyan
            ) {
                TextField(String(localized: "add_friend_username_placeholder"), text: $username)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit {
                        guard canSubmit else { return }

                        Task {
                            await sendRequest()
                        }
                    }
                    .onChange(of: username) { _, newValue in
                        let normalized = newValue
                            .lowercased()
                            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }

                        if normalized != newValue {
                            username = normalized
                        }
                    }

                Text(!appLanguageIsEnglish()
                     ? tr("uname_hint")
                     : "You can type it without @.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.38))
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    var helperCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(
                eyebrow: "HOW IT WORKS",
                title: !appLanguageIsEnglish() ? tr("how_w1") : "How it",
                italic: !appLanguageIsEnglish() ? tr("how_w2") : "works"
            )

            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(AddFriendArenaPalette.gold)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(AddFriendArenaPalette.gold.opacity(0.13))
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(!appLanguageIsEnglish()
                         ? tr("af_step1")
                         : "A request is sent.")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)

                    Text(!appLanguageIsEnglish()
                         ? tr("af_step2")
                         : "Once accepted, they appear in your friends list and social study features unlock.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.48))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(14)
            .background(detailSurface(cornerRadius: 22, tint: AddFriendArenaPalette.gold))
        }
        .padding(18)
        .background(cardBackground)
    }

    var sendButton: some View {
        Button {
            Task {
                await sendRequest()
            }
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.black)
                } else {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 18, weight: .black))
                }

                Text(isLoading ? String(localized: "add_friend_sending") : String(localized: "add_friend_send_request"))
                    .font(.system(size: 16, weight: .black))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Capsule()
                    .fill(canSubmit ? AddFriendArenaPalette.green : Color.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.55)
    }
}

// MARK: - Components

private extension AddFriendSheetView {
    func sectionTitle(eyebrow: String, title: String, italic: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("— \(eyebrow) —")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.34))
                .lineLimit(1)
                .minimumScaleFactor(0.60)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(.white)

                Text(italic)
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.white)
            }
        }
    }

    func fieldBox<Content: View>(
        title: String,
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(tint.opacity(0.13))
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.36))

                content()
            }
        }
        .padding(14)
        .background(detailSurface(cornerRadius: 22, tint: tint))
    }

    func pill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.20), lineWidth: 1)
                    )
            )
            .lineLimit(1)
    }

    func errorCard(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(AddFriendArenaPalette.coral)

            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(3)

            Spacer()
        }
        .padding(16)
        .background(detailSurface(cornerRadius: 22, tint: AddFriendArenaPalette.coral))
    }

    func successCard(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(AddFriendArenaPalette.green)

            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(3)

            Spacer()
        }
        .padding(16)
        .background(detailSurface(cornerRadius: 22, tint: AddFriendArenaPalette.green))
    }

    func detailSurface(cornerRadius: CGFloat, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.055),
                        AddFriendArenaPalette.purple.opacity(0.040),
                        Color.white.opacity(0.038)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 14, y: 8)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        AddFriendArenaPalette.blue.opacity(0.035),
                        AddFriendArenaPalette.purple.opacity(0.045),
                        Color.white.opacity(0.040)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(Color.white.opacity(0.075), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 16, y: 9)
    }
}

// MARK: - Logic

private extension AddFriendSheetView {
    @MainActor
    func sendRequest() async {
        guard let currentUserID = session.currentUser?.id else {
            errorMessage = String(localized: "add_friend_login_required")
            return
        }

        guard !cleanUsername.isEmpty else {
            errorMessage = String(localized: "add_friend_enter_username")
            return
        }

        let acceptedCount = friendStore.friendships.filter { $0.status == "accepted" }.count
        if acceptedCount >= 5, !subscriptionManager.isPro {
            Analytics.shared.track("feature_gate_triggered", properties: ["gate": "friend_limit"])
            showPaywall = true
            return
        }

        errorMessage = nil
        successMessage = nil
        isLoading = true

        do {
            await friendStore.loadAllFriendships(currentUserID: currentUserID)

            let targetProfile = try await friendStore.findUserByUsername(cleanUsername)

            if targetProfile.id == currentUserID {
                errorMessage = String(localized: "add_friend_cannot_add_self")
                isLoading = false
                return
            }

            let alreadyExists = friendStore.friendships.contains {
                ($0.requester_id == currentUserID && $0.addressee_id == targetProfile.id) ||
                ($0.requester_id == targetProfile.id && $0.addressee_id == currentUserID)
            }

            if alreadyExists {
                errorMessage = String(localized: "add_friend_already_exists")
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
            await friendStore.loadPresence(for: otherUserIDs)
            friendStore.markFriendsCacheRefreshed()

            if !appLanguageIsEnglish() {
                successMessage = tr("af_request_sent", cleanUsername)
            } else {
                successMessage = "Friend request sent to @\(cleanUsername)"
            }

            username = ""

            try? await Task.sleep(nanoseconds: 900_000_000)
            dismiss()
        } catch {
            errorMessage = String(localized: "add_friend_user_not_found")
        }

        isLoading = false
    }
}

// MARK: - Color Hex
