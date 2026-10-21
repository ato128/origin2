//
//  AddFriendSheetView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 21.03.2026.
//

import SwiftUI

private enum AddFriendArenaPalette {
    static let backgroundTop = Color.adaptive(light: Color(arenaHex: "#FBF6EC"), dark: Color(arenaHex: "#05060D"))
    static let backgroundMid = Color.adaptive(light: Color(arenaHex: "#F4EEE1"), dark: Color(arenaHex: "#070713"))
    static let backgroundBottom = Color.adaptive(light: Color(arenaHex: "#EFE7D6"), dark: Color(arenaHex: "#07040C"))

    static let blue = Color(arenaHex: "#1593FF")
    static let cyan = Color(arenaHex: "#2DD4FF")
    static let purple = Color(arenaHex: "#7C3AED")
    static let coral = Color(arenaHex: "#FF5A44")
    static let gold = Color(arenaHex: "#FBBF24")
    static let green = Color(arenaHex: "#A3E635")
    static let surface = Color.adaptive(light: Color(arenaHex: "#FFFDF7"), dark: Color(arenaHex: "#101118"))

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

            if UIDevice.current.userInterfaceIdiom == .pad {
                padLayout
            } else {
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
        }
        .updoPadSheet()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: "friend_limit")
        }
    }
}

// MARK: - iPad

private extension AddFriendSheetView {
    /// iPad: "be found" on the left (your username to share, the invite
    /// reward), "find someone" on the right (the username form and what a
    /// friendship unlocks).
    var padLayout: some View {
        VStack(alignment: .leading, spacing: 26) {
            padHeader

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    AddFriendMyCodeCard(session: session)
                    AddFriendInviteCard()
                }
                .frame(width: 380, alignment: .top)

                VStack(alignment: .leading, spacing: 16) {
                    padFormCard
                    padBenefitsCard
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 36)
        .padding(.top, 28)
        .padding(.bottom, 24)
        .frame(maxWidth: 1000)
        .frame(maxWidth: .infinity)
    }

    var padHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(UpdoTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .liquidGlass(in: Circle())
                    .overlay(Circle().strokeBorder(UpdoTheme.border, lineWidth: 1))
                    .contentShape(.hoverEffect, Circle())
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .keyboardShortcut(.cancelAction)
            .disabled(isLoading)
            .accessibilityLabel(tr("event_close"))

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(tr("afp_title_first"))
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(UpdoTheme.textPrimary)
                    Text(tr("afp_title_italic"))
                        .font(.system(size: 29, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(LinearGradient(colors: [AddFriendArenaPalette.cyan, AddFriendArenaPalette.purple],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                Text(tr("afp_subtitle"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(UpdoTheme.filmy(0.5))
            }
        }
    }

    // MARK: Find someone

    var padFormCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            padEyebrow(tr("afp_find_caps"), tint: AddFriendArenaPalette.cyan)

            Text(tr("afp_find_title"))
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(UpdoTheme.textPrimary)

            HStack(spacing: 10) {
                Text("@")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(AddFriendArenaPalette.cyan)

                TextField(tr("add_friend_username_placeholder"), text: $username)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(UpdoTheme.textPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit {
                        guard canSubmit else { return }
                        Task { await sendRequest() }
                    }
                    .onChange(of: username) { _, newValue in
                        let normalized = newValue
                            .lowercased()
                            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
                        if normalized != newValue { username = normalized }
                        errorMessage = nil
                        successMessage = nil
                    }

                if !username.isEmpty {
                    Button { username = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(UpdoTheme.filmy(0.35))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("afp_clear"))
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 62)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(UpdoTheme.filmy(0.05)))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(cleanUsername.isEmpty ? UpdoTheme.border : AddFriendArenaPalette.cyan.opacity(0.55),
                                  lineWidth: cleanUsername.isEmpty ? 1 : 1.5)
            )

            Text(tr("afp_field_hint"))
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(UpdoTheme.filmy(0.42))

            if let errorMessage {
                padStatus(errorMessage, icon: "exclamationmark.circle.fill", tint: AddFriendArenaPalette.coral)
            }
            if let successMessage {
                padStatus(successMessage, icon: "checkmark.circle.fill", tint: AddFriendArenaPalette.green)
            }

            Button {
                Task { await sendRequest() }
            } label: {
                HStack(spacing: 10) {
                    if isLoading {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "paperplane.fill").font(.system(size: 15, weight: .black))
                    }
                    Text(cleanUsername.isEmpty ? tr("afp_send") : tr("afp_send_to", cleanUsername))
                        .font(.system(size: 16, weight: .black))
                        .lineLimit(1)
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Capsule().fill(canSubmit
                                   ? AnyShapeStyle(LinearGradient(colors: [AddFriendArenaPalette.cyan, AddFriendArenaPalette.blue],
                                                                   startPoint: .leading, endPoint: .trailing))
                                   : AnyShapeStyle(UpdoTheme.filmy(0.12)))
                )
                .contentShape(.hoverEffect, Capsule())
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)
            .disabled(!canSubmit)
            .keyboardShortcut(.defaultAction)
        }
        .padding(22)
        .background(cardBackground)
    }

    var padBenefitsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            padEyebrow(tr("afp_unlock_caps"), tint: AddFriendArenaPalette.gold)

            VStack(spacing: 12) {
                benefitRow(icon: "timer", tint: AddFriendArenaPalette.purple,
                           title: tr("afp_b1_title"), subtitle: tr("afp_b1_sub"))
                benefitRow(icon: "bubble.left.and.bubble.right.fill", tint: AddFriendArenaPalette.blue,
                           title: tr("afp_b2_title"), subtitle: tr("afp_b2_sub"))
                benefitRow(icon: "chart.bar.xaxis", tint: AddFriendArenaPalette.green,
                           title: tr("afp_b3_title"), subtitle: tr("afp_b3_sub"))
            }
        }
        .padding(22)
        .background(cardBackground)
    }

    func benefitRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint.opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(UpdoTheme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(UpdoTheme.filmy(0.52))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    func padStatus(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(UpdoTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint.opacity(0.12)))
        .transition(.opacity)
    }

    func padEyebrow(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .black, design: .monospaced))
            .tracking(1.8)
            .foregroundStyle(tint)
    }
}

// MARK: - iPad: be found

/// Your own username, ready to copy or share — so friends can add you.
private struct AddFriendMyCodeCard: View {
    @ObservedObject var session: SessionStore
    @State private var copied = false

    private var username: String { session.currentUser?.username ?? "" }
    private var name: String {
        let full = session.currentUser?.fullName.trimmingCharacters(in: .whitespaces) ?? ""
        return full.isEmpty ? username : full
    }
    private var shareText: String { tr("afp_share_text", username, AppLinks.appStore) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("afp_me_caps"))
                .font(.system(size: 10.5, weight: .black, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(AddFriendArenaPalette.purple)

            HStack(spacing: 14) {
                UserAvatarView(userID: session.currentUser?.id, name: name,
                               tint: AddFriendArenaPalette.purple, size: 58)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(UpdoTheme.textPrimary)
                        .lineLimit(1)
                    Text("@\(username)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [AddFriendArenaPalette.cyan, AddFriendArenaPalette.purple],
                                                        startPoint: .leading, endPoint: .trailing))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
            }

            Text(tr("afp_me_sub"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(UpdoTheme.filmy(0.52))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    UIPasteboard.general.string = "@\(username)"
                    Haptics.notify(.success)
                    withAnimation(.snappy) { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        withAnimation(.snappy) { copied = false }
                    }
                } label: {
                    Label(copied ? tr("afp_copied") : tr("afp_copy"),
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(UpdoTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Capsule().fill(UpdoTheme.filmy(0.07)))
                        .overlay(Capsule().strokeBorder(UpdoTheme.border, lineWidth: 1))
                        .contentTransition(.symbolEffect(.replace))
                        .contentShape(.hoverEffect, Capsule())
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)

                ShareLink(item: shareText) {
                    Label(tr("afp_share"), systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(UpdoTheme.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Capsule().fill(LinearGradient(colors: [AddFriendArenaPalette.blue, AddFriendArenaPalette.purple],
                                                                  startPoint: .leading, endPoint: .trailing)))
                        .contentShape(.hoverEffect, Capsule())
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
            }
            .disabled(username.isEmpty)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [AddFriendArenaPalette.purple.opacity(0.16), AddFriendArenaPalette.blue.opacity(0.08),
                                              AddFriendArenaPalette.surface.opacity(0.96)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AddFriendArenaPalette.purple.opacity(0.22), lineWidth: 1))
        )
    }
}

/// The invite reward (3 new friends → 1 month Premium), with real progress.
private struct AddFriendInviteCard: View {
    @State private var status: ReferralBackendClient.Status?

    var body: some View {
        let needed = max(status?.needed ?? 3, 1)
        let qualified = min(status?.qualified ?? 0, needed)
        let granted = status?.rewardGranted ?? false
        let link = status?.link ?? AppLinks.appStore

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: granted ? "checkmark.seal.fill" : "gift.fill")
                    .foregroundStyle(AddFriendArenaPalette.gold)
                Text(tr("afp_invite_caps"))
                    .font(.system(size: 10.5, weight: .black, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(AddFriendArenaPalette.gold)
            }

            Text(granted ? tr("afp_invite_done") : tr("afp_invite_title", needed))
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(UpdoTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if !granted {
                HStack(spacing: 8) {
                    ForEach(0..<needed, id: \.self) { index in
                        Capsule()
                            .fill(index < qualified ? AnyShapeStyle(AddFriendArenaPalette.gold) : AnyShapeStyle(UpdoTheme.filmy(0.12)))
                            .frame(height: 8)
                    }
                }
                Text(tr("afp_invite_progress", qualified, needed))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(UpdoTheme.filmy(0.5))
            }

            ShareLink(item: tr("afp_invite_text", link)) {
                Label(tr("afp_invite_share"), systemImage: "link")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Capsule().fill(AddFriendArenaPalette.gold))
                    .contentShape(.hoverEffect, Capsule())
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LinearGradient(colors: [AddFriendArenaPalette.gold.opacity(0.12), AddFriendArenaPalette.surface.opacity(0.96)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(AddFriendArenaPalette.gold.opacity(0.22), lineWidth: 1))
        )
        .task { status = try? await ReferralBackendClient.shared.status() }
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
                    UpdoTheme.overlayScrim(0.16),
                    Color.clear,
                    UpdoTheme.overlayScrim(0.42)
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
                    .foregroundStyle(UpdoTheme.textPrimary)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(UpdoTheme.filmy(0.075))
                            .overlay(
                                RoundedRectangle(cornerRadius: 17, style: .continuous)
                                    .stroke(UpdoTheme.filmy(0.10), lineWidth: 1)
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
                    .foregroundStyle(UpdoTheme.textPrimary)
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
                        .fill(canSubmit ? AddFriendArenaPalette.green : UpdoTheme.filmy(0.12))
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
                            .foregroundStyle(UpdoTheme.textPrimary)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text("SOCIAL GRAPH")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(AddFriendArenaPalette.cyan)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(!appLanguageIsEnglish() ? "Yeni" : "New")
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(UpdoTheme.textPrimary)

                        Text(!appLanguageIsEnglish() ? tr("ch_friend_word") : "friend")
                            .font(.system(size: 25, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(AddFriendArenaPalette.cyan)
                    }

                    Text(!appLanguageIsEnglish()
                         ? tr("af_subtitle")
                         : "Send a friend request by username and grow your study circle.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(UpdoTheme.filmy(0.50))
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
                .shadow(color: UpdoTheme.cardShadow(0.24), radius: 20, y: 12)
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
                TextField(tr("add_friend_username_placeholder"), text: $username)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(UpdoTheme.textPrimary)
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
                    .foregroundStyle(UpdoTheme.filmy(0.38))
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
                        .foregroundStyle(UpdoTheme.textPrimary)

                    Text(!appLanguageIsEnglish()
                         ? tr("af_step2")
                         : "Once accepted, they appear in your friends list and social study features unlock.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(UpdoTheme.filmy(0.48))
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

                Text(isLoading ? tr("add_friend_sending") : tr("add_friend_send_request"))
                    .font(.system(size: 16, weight: .black))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Capsule()
                    .fill(canSubmit ? AddFriendArenaPalette.green : UpdoTheme.filmy(0.12))
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
                .foregroundStyle(UpdoTheme.filmy(0.34))
                .lineLimit(1)
                .minimumScaleFactor(0.60)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(UpdoTheme.textPrimary)

                Text(italic)
                    .font(.system(size: 23, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(UpdoTheme.textPrimary)
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
                    .foregroundStyle(UpdoTheme.filmy(0.36))

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
                .foregroundStyle(UpdoTheme.filmy(0.74))
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
                .foregroundStyle(UpdoTheme.filmy(0.74))
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
                        UpdoTheme.filmy(0.038)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.13), lineWidth: 1)
            )
            .shadow(color: UpdoTheme.cardShadow(0.22), radius: 14, y: 8)
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        AddFriendArenaPalette.blue.opacity(0.035),
                        AddFriendArenaPalette.purple.opacity(0.045),
                        UpdoTheme.filmy(0.040)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(UpdoTheme.filmy(0.075), lineWidth: 1)
            )
            .shadow(color: UpdoTheme.cardShadow(0.22), radius: 16, y: 9)
    }
}

// MARK: - Logic

private extension AddFriendSheetView {
    @MainActor
    func sendRequest() async {
        guard let currentUserID = session.currentUser?.id else {
            errorMessage = tr("add_friend_login_required")
            return
        }

        guard !cleanUsername.isEmpty else {
            errorMessage = tr("add_friend_enter_username")
            return
        }

        // Arkadaş ekleme sınırsız — Pro limiti kaldırıldı.

        errorMessage = nil
        successMessage = nil
        isLoading = true

        do {
            await friendStore.loadAllFriendships(currentUserID: currentUserID)

            let targetProfile = try await friendStore.findUserByUsername(cleanUsername)

            if targetProfile.id == currentUserID {
                errorMessage = tr("add_friend_cannot_add_self")
                isLoading = false
                return
            }

            let alreadyExists = friendStore.friendships.contains {
                ($0.requester_id == currentUserID && $0.addressee_id == targetProfile.id) ||
                ($0.requester_id == targetProfile.id && $0.addressee_id == currentUserID)
            }

            if alreadyExists {
                errorMessage = tr("add_friend_already_exists")
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
            errorMessage = tr("add_friend_user_not_found")
        }

        isLoading = false
    }
}

// MARK: - Color Hex
