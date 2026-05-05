//
//  FriendChatView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit
import Photos
import AVFoundation

private enum FriendChatArenaPalette {
    static let backgroundTop = Color(friendChatHex: "#05060D")
    static let backgroundMid = Color(friendChatHex: "#070713")
    static let backgroundBottom = Color(friendChatHex: "#07040C")

    static let blue = Color(friendChatHex: "#1593FF")
    static let cyan = Color(friendChatHex: "#2DD4FF")
    static let purple = Color(friendChatHex: "#7C3AED")
    static let coral = Color(friendChatHex: "#FF5A44")
    static let gold = Color(friendChatHex: "#FBBF24")
    static let green = Color(friendChatHex: "#A3E635")
    static let surface = Color(friendChatHex: "#101118")

    static var appGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(friendChatHex: "#1E6BFF"),
                Color(friendChatHex: "#7C3AED")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var sentBubbleGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(friendChatHex: "#1593FF"),
                Color(friendChatHex: "#7C3AED")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private enum FriendChatFormatters {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()
}

struct FriendChatView: View {
    let friend: Friend

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var session: SessionStore

    private let palette = ThemePalette()

    @State private var draftMessage: String = ""
    @State private var showFriendInfo = false
    @State private var composerBarHeight: CGFloat = 90
    @State private var showCamera = false
    @State private var showFileImporter = false
    @State private var showAttachmentAlert = false
    @State private var attachmentAlertText = ""

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedFileURL: URL?
    @State private var capturedImage: UIImage?
    @State private var draftAttachment: DraftAttachment?
    @State private var showMicPermissionAlert = false

    @State private var lastScrolledMessageID: UUID?
    @StateObject private var audioRecorder = AudioRecorderManager()
    @State private var liveRefreshTask: Task<Void, Never>?
    @State private var scrollTask: Task<Void, Never>?
    @State private var typingStopTask: Task<Void, Never>?
    @State private var lastTypingTextWasEmpty = true

    enum DraftAttachment {
        case photo(UIImage)
        case file(URL)
    }

    @FocusState private var isComposerFocused: Bool

    private var friendshipID: UUID? {
        friend.backendFriendshipID
    }

    private var messages: [FriendChatMessageItem] {
        guard let friendshipID else { return [] }
        return friendStore.friendMessagesByFriendship[friendshipID] ?? []
    }

    private var chatRootContent: some View {
        ZStack(alignment: .top) {
            ambientBackground

            VStack(spacing: 0) {
                if messages.isEmpty {
                    emptyState
                } else {
                    messagesList
                }
            }

            floatingTopControls
        }
    }

    private var chatMainView: some View {
        chatRootContent
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composerBar
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isComposerFocused = false
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
    }

    var body: some View {
        chatMainView
            .sheet(isPresented: $showFriendInfo) {
                NavigationStack {
                    FriendChatInfoView(friend: friend)
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.item, .data, .content, .image, .pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    selectedFileURL = url
                    draftAttachment = .file(url)

                case .failure(let error):
                    attachmentAlertText = "Dosya seçilemedi: \(error.localizedDescription)"
                    showAttachmentAlert = true
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(image: $capturedImage)
            }
            .onChange(of: capturedImage) { _, newImage in
                guard let newImage else { return }
                draftAttachment = .photo(newImage)
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }

                Task {
                    do {
                        if let data = try await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                draftAttachment = .photo(image)
                            }
                        }
                    } catch {
                        await MainActor.run {
                            attachmentAlertText = "Fotoğraf yüklenemedi: \(error.localizedDescription)"
                            showAttachmentAlert = true
                        }
                    }
                }
            }
            .alert("Bilgi", isPresented: $showAttachmentAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(attachmentAlertText)
            }
            .task(id: friendshipID) {
                guard let friendshipID else { return }

                print("🟡 CHAT TASK START:", friendshipID.uuidString)

                FriendStore.sharedRetryBridge = { message in
                    await friendStore.retryMessage(message)
                }

                friendStore.setActiveChat(friendshipID)
                UserDefaults.standard.set(friendshipID.uuidString, forKey: "active_friendship_id")

                if let currentUserID = session.currentUser?.id {
                    await friendStore.resetUnreadForCurrentUser(
                        friendshipID: friendshipID,
                        currentUserID: currentUserID
                    )
                }

                if friendStore.friendMessagesByFriendship[friendshipID] == nil {
                    await friendStore.loadInitialMessages(
                        for: friendshipID,
                        currentUserID: session.currentUser?.id
                    )
                } else {
                    await friendStore.loadNewMessages(
                        for: friendshipID,
                        currentUserID: session.currentUser?.id
                    )
                }

                await friendStore.markMessagesSeen(
                    friendshipID: friendshipID,
                    currentUserID: session.currentUser?.id
                )

                friendStore.subscribeToFriendMessagesRealtime(
                    friendshipID: friendshipID,
                    currentUserID: session.currentUser?.id
                )

                friendStore.subscribeToTypingRealtime(
                    friendshipID: friendshipID,
                    currentUserID: session.currentUser?.id
                )

                startLiveRefreshFallback()
            }
            .onDisappear {
                print("🔴 CHAT DISAPPEAR")

                liveRefreshTask?.cancel()
                liveRefreshTask = nil

                scrollTask?.cancel()
                scrollTask = nil
                
                typingStopTask?.cancel()
                typingStopTask = nil
                lastTypingTextWasEmpty = true

                friendStore.setActiveChat(nil)
                UserDefaults.standard.removeObject(forKey: "active_friendship_id")
                friendStore.unsubscribeFriendMessagesRealtime()
                friendStore.unsubscribeTypingRealtime()
            }
            .onChange(of: messages.count) { _, _ in
                guard let friendshipID else { return }

                Task {
                    await friendStore.markMessagesSeen(
                        friendshipID: friendshipID,
                        currentUserID: session.currentUser?.id
                    )
                }
            }
            .alert("Mikrofon izni gerekli", isPresented: $showMicPermissionAlert) {
                Button("Ayarlar") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }

                Button("İptal", role: .cancel) { }
            } message: {
                Text("Ses mesajı göndermek için mikrofon izni vermen gerekiyor.")
            }
    }
}

// MARK: - Background

private extension FriendChatView {
    var ambientBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    FriendChatArenaPalette.backgroundTop,
                    FriendChatArenaPalette.backgroundMid,
                    FriendChatArenaPalette.backgroundBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(hexColor(friend.colorHex).opacity(0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 105)
                .offset(x: -175, y: 520)

            Circle()
                .fill(FriendChatArenaPalette.blue.opacity(0.10))
                .frame(width: 260, height: 260)
                .blur(radius: 96)
                .offset(x: 165, y: -245)

            Circle()
                .fill(FriendChatArenaPalette.purple.opacity(0.14))
                .frame(width: 300, height: 300)
                .blur(radius: 110)
                .offset(x: 180, y: 260)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.clear,
                    Color.black.opacity(0.44)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Top Controls

private extension FriendChatView {
    var floatingTopControls: some View {
        ZStack(alignment: .top) {
            chatHeaderScrim
                .allowsHitTesting(false)

            HStack(alignment: .center, spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(arenaCircleBackground)
                }
                .buttonStyle(.plain)

                Button {
                    showFriendInfo = true
                } label: {
                    HStack(spacing: 10) {
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            hexColor(friend.colorHex).opacity(0.90),
                                            FriendChatArenaPalette.purple.opacity(0.75)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 38, height: 38)
                                .overlay(
                                    Image(systemName: friend.avatarSymbol)
                                        .font(.system(size: 16, weight: .black))
                                        .foregroundStyle(.white)
                                )

                            Circle()
                                .fill(isFriendOnline ? FriendChatArenaPalette.green : Color.gray.opacity(0.65))
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(FriendChatArenaPalette.surface, lineWidth: 2)
                                )
                                .offset(x: 1, y: 1)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(friend.name)
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            if isTypingNow {
                                HStack(spacing: 5) {
                                    Text(headerStatusText)
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(FriendChatArenaPalette.green)

                                    TypingDotsView()
                                        .foregroundStyle(FriendChatArenaPalette.green)
                                }
                            } else {
                                Text(headerStatusText)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.58))
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 8)
                    .padding(.trailing, 12)
                    .frame(height: 46)
                    .background(arenaCapsuleBackground)
                }
                .buttonStyle(.plain)

                Button {
                    showFriendInfo = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(arenaCircleBackground)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }
    private var friendPresence: FriendPresenceDTO? {
        guard let userID = friend.backendUserID else { return nil }
        return friendStore.presenceByUserID[userID]
    }

    private var isTypingNow: Bool {
        guard let friendshipID else { return false }
        return friendStore.typingStatusByFriendship[friendshipID] == true
    }

    private var isFriendOnline: Bool {
        FriendPresenceEngine.isOnline(friendPresence)
    }

    private var headerStatusText: String {
        if let friendshipID,
           friendStore.typingStatusByFriendship[friendshipID] == true {
            return tr("chat_typing_suffix")
        }

        return FriendPresenceEngine.statusText(
            presence: friendPresence,
            locale: locale
        )
    }
}

// MARK: - Empty State

private extension FriendChatView {
    var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(FriendChatArenaPalette.appGradient)
                .frame(width: 76, height: 76)
                .overlay(
                    Image(systemName: "message.fill")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white)
                )

            VStack(spacing: 7) {
                Text(tr("chat_no_messages_yet"))
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)

                Text(tr("chat_start_conversation_format", friend.name))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 26)
        .padding(.top, 80)
    }
}

// MARK: - Messages List

private extension FriendChatView {
    var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(groupedMessages, id: \.date) { group in
                        DaySeparatorView(date: group.date)
                            .padding(.vertical, 8)

                        ForEach(group.messages) { message in
                            ChatMessageRow(
                                message: message,
                                palette: palette,
                                onDelete: {
                                    guard let friendshipID else { return }

                                    Task {
                                        await friendStore.deleteMessage(
                                            message,
                                            friendshipID: friendshipID
                                        )
                                    }
                                }
                            )
                            .id(message.id)
                        }
                    }

                    if isTypingNow {
                        HStack {
                            HStack(spacing: 6) {
                                TypingDotsBubble()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white.opacity(0.055))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            )

                            Spacer(minLength: 56)
                        }
                        .padding(.top, 4)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("chat-bottom-anchor")
                }
                .padding(.horizontal, 16)
                .padding(.top, 64)
                .padding(.bottom, composerBarHeight + 18)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                lastScrolledMessageID = messages.last?.id

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }
            .onChange(of: messages.last?.id) { _, newValue in
                guard let newValue else { return }
                guard newValue != lastScrolledMessageID else { return }

                lastScrolledMessageID = newValue

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    scrollToBottom(proxy: proxy, animated: true)
                }
            }
            .onChange(of: isComposerFocused) { _, focused in
                guard focused else { return }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    scrollToBottom(proxy: proxy, animated: true)
                }
            }
        }
    }

    private struct TypingDotsBubble: View {
        @State private var tick = 0
        @State private var task: Task<Void, Never>?

        var body: some View {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(tick == i ? 0.95 : 0.35))
                        .frame(width: 6, height: 6)
                        .scaleEffect(tick == i ? 1.0 : 0.78)
                        .animation(.easeInOut(duration: 0.18), value: tick)
                }
            }
            .onAppear {
                task?.cancel()

                task = Task { @MainActor in
                    while !Task.isCancelled {
                        tick = (tick + 1) % 3
                        try? await Task.sleep(nanoseconds: 350_000_000)
                    }
                }
            }
            .onDisappear {
                task?.cancel()
                task = nil
            }
        }
    }

    var groupedMessages: [MessageGroup] {
        let calendar = Calendar.current
        var groups: [MessageGroup] = []
        var currentDate: Date?
        var currentMessages: [FriendChatMessageItem] = []

        for message in messages {
            let day = calendar.startOfDay(for: message.createdAt)

            if let cd = currentDate, calendar.isDate(cd, inSameDayAs: day) {
                currentMessages.append(message)
            } else {
                if !currentMessages.isEmpty, let cd = currentDate {
                    groups.append(MessageGroup(date: cd, messages: currentMessages))
                }

                currentDate = day
                currentMessages = [message]
            }
        }

        if !currentMessages.isEmpty, let cd = currentDate {
            groups.append(MessageGroup(date: cd, messages: currentMessages))
        }

        return groups
    }

    struct MessageGroup {
        let date: Date
        let messages: [FriendChatMessageItem]
    }
}

// MARK: - Composer

private extension FriendChatView {
    var composerBar: some View {
        VStack(spacing: 8) {
            if let draftAttachment {
                attachmentPreviewCard(attachment: draftAttachment)
                    .padding(.horizontal, 16)
            }

            if audioRecorder.isRecording {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ses kaydı")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.white)

                        HStack(spacing: 3) {
                            ForEach(0..<18, id: \.self) { index in
                                Capsule()
                                    .fill(Color.white.opacity(0.75))
                                    .frame(width: 3, height: barHeight(for: index))
                            }
                        }
                    }

                    Spacer()

                    Text(audioRecorder.durationText())
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))

                    Button("İptal") {
                        audioRecorder.cancelRecording()
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.065))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.09), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
            }

            HStack(alignment: .center, spacing: 10) {
                Menu {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Fotoğraf", systemImage: "photo")
                    }

                    Button {
                        showCamera = true
                    } label: {
                        Label("Kamera", systemImage: "camera")
                    }

                    Button {
                        showFileImporter = true
                    } label: {
                        Label("Dosya", systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(width: 42, height: 42)
                        .background(arenaCircleBackground)
                }

                HStack(spacing: 10) {
                    TextField(tr("chat_message_placeholder"), text: $draftMessage)
                        .focused($isComposerFocused)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .tint(FriendChatArenaPalette.cyan)
                        .submitLabel(.send)
                        .onSubmit {
                            sendMessage()
                        }
                        .onChange(of: draftMessage) { _, newValue in
                            handleTypingChange(newValue)
                        }

                    Button {
                        if hasSendableContent {
                            sendMessage()
                            return
                        }

                        Task {
                            if audioRecorder.isRecording {
                                audioRecorder.stopRecording()

                                guard let recordedURL = audioRecorder.recordedURL,
                                      let friendshipID else { return }

                                await friendStore.sendVoiceMessage(
                                    audioURL: recordedURL,
                                    friendshipID: friendshipID,
                                    senderID: session.currentUser?.id,
                                    senderName: senderDisplayName(),
                                    durationText: audioRecorder.durationText()
                                )

                                if let senderID = session.currentUser?.id {
                                    let receiverUserID: UUID? = {
                                        if let friendship = friendStore.friendships.first(where: { $0.id == friendshipID }) {
                                            return friendship.requester_id == senderID
                                            ? friendship.addressee_id
                                            : friendship.requester_id
                                        }

                                        return friend.backendUserID
                                    }()

                                    if let receiverUserID {
                                        PushService.shared.sendFriendMessagePush(
                                            toUserId: receiverUserID.uuidString,
                                            friendshipID: friendshipID.uuidString,
                                            senderName: senderDisplayName(),
                                            message: "🎤 Ses mesajı"
                                        )
                                    }
                                }

                                audioRecorder.recordedURL = nil
                                audioRecorder.elapsedSeconds = 0
                            } else {
                                let granted = await audioRecorder.requestPermission()

                                guard granted else {
                                    showMicPermissionAlert = true
                                    return
                                }

                                do {
                                    try audioRecorder.startRecording()
                                } catch {
                                    print("VOICE RECORD START ERROR:", error.localizedDescription)
                                }
                            }
                        }
                    } label: {
                        Image(
                            systemName:
                                hasSendableContent
                            ? "arrow.up.circle.fill"
                            : (audioRecorder.isRecording ? "stop.circle.fill" : "mic.fill")
                        )
                        .font(.system(size: hasSendableContent ? 24 : 20, weight: .semibold))
                        .foregroundStyle(
                            hasSendableContent
                            ? FriendChatArenaPalette.blue
                            : (audioRecorder.isRecording ? Color.red : Color.white.opacity(0.78))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(arenaCapsuleBackground)
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 10)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        let height = geo.size.height
                        if abs(composerBarHeight - height) > 0.5 {
                            composerBarHeight = height
                        }
                    }
                    .onChange(of: geo.size.height) { _, newHeight in
                        if abs(composerBarHeight - newHeight) > 0.5 {
                            composerBarHeight = newHeight
                        }
                    }
            }
        )
    }
    func barHeight(for index: Int) -> CGFloat {
        let normalized = max(0.08, CGFloat((audioRecorder.averagePower + 50) / 50))
        let base = 6 + CGFloat((index % 5) * 2)
        return base + (normalized * 18)
    }
}

// MARK: - Helpers

private extension FriendChatView {
    var arenaCircleBackground: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.105),
                        Color.black.opacity(0.34),
                        Color.white.opacity(0.055)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.28)
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 14, y: 7)
    }

    var arenaCapsuleBackground: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        FriendChatArenaPalette.blue.opacity(0.075),
                        FriendChatArenaPalette.purple.opacity(0.060),
                        Color.white.opacity(0.055)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 12, y: 6)
    }
    
    var chatHeaderScrim: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.96), location: 0.00),
                    .init(color: Color.black.opacity(0.88), location: 0.24),
                    .init(color: Color.black.opacity(0.64), location: 0.50),
                    .init(color: Color.black.opacity(0.31), location: 0.74),
                    .init(color: Color.black.opacity(0.10), location: 0.90),
                    .init(color: Color.clear, location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 168)
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [
                        Color(friendChatHex: "#05060D").opacity(0.92),
                        Color(friendChatHex: "#05060D").opacity(0.58),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 108)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(0.10))
                    .frame(height: 34)
                    .blur(radius: 18)
                    .offset(y: 12)
            }

            Spacer(minLength: 0)
        }
    }

    var glassCircleBackground: some View {
        arenaCircleBackground
    }

    var glassCapsuleBackground: some View {
        arenaCapsuleBackground
    }

    func senderDisplayName() -> String {
        if let email = session.currentUser?.email, !email.isEmpty {
            return email.components(separatedBy: "@").first ?? email
        }

        return tr("chat_you")
    }
    
    func handleTypingChange(_ newValue: String) {
        guard let friendshipID else { return }

        let clean = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if clean.isEmpty {
            typingStopTask?.cancel()

            guard lastTypingTextWasEmpty == false else {
                return
            }

            lastTypingTextWasEmpty = true

            typingStopTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 220_000_000)

                guard !Task.isCancelled else { return }

                await friendStore.setTyping(
                    friendshipID: friendshipID,
                    currentUserID: session.currentUser?.id,
                    currentUserName: senderDisplayName(),
                    isTyping: false
                )
            }

            return
        }

        typingStopTask?.cancel()
        typingStopTask = nil

        if lastTypingTextWasEmpty {
            lastTypingTextWasEmpty = false
        }

        friendStore.userDidType(
            friendshipID: friendshipID,
            currentUserID: session.currentUser?.id,
            currentUserName: senderDisplayName()
        )
    }

    func startLiveRefreshFallback() {
        liveRefreshTask?.cancel()

        liveRefreshTask = Task {
            while !Task.isCancelled {
                guard let friendshipID else { return }

                await friendStore.loadNewMessages(
                    for: friendshipID,
                    currentUserID: session.currentUser?.id
                )

                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    func sendMessage() {
        guard let friendshipID else { return }
        guard let senderID = session.currentUser?.id else { return }

        let clean = draftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let attachmentToSend = draftAttachment

        let receiverUserID: UUID? = {
            if let friendship = friendStore.friendships.first(where: { $0.id == friendshipID }) {
                return friendship.requester_id == senderID
                ? friendship.addressee_id
                : friendship.requester_id
            }

            return friend.backendUserID
        }()

        guard let receiverUserID else {
            print("❌ FRIEND PUSH SKIPPED: receiver userID nil")
            return
        }

        draftMessage = ""
        draftAttachment = nil
        selectedPhotoItem = nil
        selectedFileURL = nil
        capturedImage = nil

        Task {
            if let attachment = attachmentToSend {
                switch attachment {
                case .photo(let image):
                    guard let jpegData = image.jpegData(compressionQuality: 0.82) else {
                        await MainActor.run {
                            attachmentAlertText = "Fotoğraf hazırlanamadı."
                            showAttachmentAlert = true
                        }
                        return
                    }

                    await friendStore.sendPhotoMessage(
                        imageData: jpegData,
                        friendshipID: friendshipID,
                        senderID: senderID,
                        senderName: senderDisplayName(),
                        caption: clean.isEmpty ? nil : clean
                    )

                    await MainActor.run {
                        ChatFeedbackManager.shared.playSent()
                    }

                    PushService.shared.sendFriendMessagePush(
                        toUserId: receiverUserID.uuidString,
                        friendshipID: friendshipID.uuidString,
                        senderName: senderDisplayName(),
                        message: clean.isEmpty ? "📷 Fotoğraf" : clean
                    )

                    return

                case .file(let fileURL):
                    await friendStore.sendFileMessage(
                        fileURL: fileURL,
                        friendshipID: friendshipID,
                        senderID: senderID,
                        senderName: senderDisplayName(),
                        caption: clean.isEmpty ? nil : clean
                    )

                    await MainActor.run {
                        ChatFeedbackManager.shared.playSent()
                    }

                    PushService.shared.sendFriendMessagePush(
                        toUserId: receiverUserID.uuidString,
                        friendshipID: friendshipID.uuidString,
                        senderName: senderDisplayName(),
                        message: clean.isEmpty ? "📎 Dosya" : clean
                    )

                    return
                }
            }

            guard !clean.isEmpty else { return }

            await friendStore.sendMessage(
                text: clean,
                friendshipID: friendshipID,
                senderID: senderID,
                senderName: senderDisplayName()
            )

            await MainActor.run {
                print("🔊 PLAY SENT FEEDBACK")
                ChatFeedbackManager.shared.playSent()
            }

            PushService.shared.sendFriendMessagePush(
                toUserId: receiverUserID.uuidString,
                friendshipID: friendshipID.uuidString,
                senderName: senderDisplayName(),
                message: clean
            )
        }
    }

    func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        scrollTask?.cancel()

        scrollTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: animated ? 80_000_000 : 20_000_000)

            guard !Task.isCancelled else { return }

            if animated {
                withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
                    proxy.scrollTo("chat-bottom-anchor", anchor: .bottom)
                }
            } else {
                proxy.scrollTo("chat-bottom-anchor", anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    func attachmentPreviewCard(attachment: DraftAttachment) -> some View {
        HStack(spacing: 12) {
            switch attachment {
            case .photo(let image):
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    removeAttachmentButton
                        .offset(x: 6, y: -6)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Fotoğraf hazır")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.white)

                    Text("Göndermeden önce istersen mesaj ekleyebilirsin.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(2)
                }

                Spacer()

            case .file(let url):
                HStack(spacing: 12) {
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 64, height: 64)
                            .overlay(
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(FriendChatArenaPalette.cyan)
                            )

                        removeAttachmentButton
                            .offset(x: 6, y: -6)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(url.lastPathComponent)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        Text("Dosya hazır")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.48))
                    }

                    Spacer()
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            FriendChatArenaPalette.blue.opacity(0.055),
                            FriendChatArenaPalette.purple.opacity(0.045),
                            Color.white.opacity(0.040)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.20), radius: 12, y: 7)
        )
    }

    var removeAttachmentButton: some View {
        Button {
            draftAttachment = nil
            selectedPhotoItem = nil
            selectedFileURL = nil
            capturedImage = nil
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white, Color.black.opacity(0.45))
                .background(Circle().fill(Color.black.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }

    private var hasSendableContent: Bool {
        !draftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draftAttachment != nil
    }
}

// MARK: - Subviews

private extension FriendChatView {
    struct TypingDotsView: View {
        @State private var tick = 0
        @State private var task: Task<Void, Never>?

        var body: some View {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .frame(width: 5, height: 5)
                        .opacity(tick == i ? 1 : 0.28)
                        .scaleEffect(tick == i ? 1.0 : 0.8)
                        .animation(.easeInOut(duration: 0.18), value: tick)
                }
            }
            .onAppear {
                task?.cancel()

                task = Task { @MainActor in
                    while !Task.isCancelled {
                        tick = (tick + 1) % 3
                        try? await Task.sleep(nanoseconds: 350_000_000)
                    }
                }
            }
            .onDisappear {
                task?.cancel()
                task = nil
            }
        }
    }
}

// MARK: - Day Separator

private struct DaySeparatorView: View {
    let date: Date

    private var label: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return tr("chat_today")
        }

        if calendar.isDateInYesterday(date) {
            return tr("chat_yesterday")
        }

        return FriendChatFormatters.dayFormatter.string(from: date)
    }
    
    var body: some View {
        HStack {
            line

            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 10)

            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 0.5)
    }
}

// MARK: - Message Row

private struct ChatMessageRow: View {
    let message: FriendChatMessageItem
    let palette: ThemePalette
    let onDelete: () -> Void

    @State private var showTime = false
    @State private var showImageViewer = false
    @State private var isSavingImage = false
    @State private var imageSaveAlertText = ""
    @State private var showImageSaveAlert = false

    private var timeText: String {
        FriendChatFormatters.timeFormatter.string(from: message.createdAt)
    }

    private var isImageMessage: Bool {
        message.messageType == "image" && message.mediaURL != nil
    }

    private var isFileMessage: Bool {
        message.messageType == "file" && message.mediaURL != nil
    }

    private var isVoiceMessage: Bool {
        message.messageType == "voice" && message.mediaURL != nil
    }

    var body: some View {
        VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 2) {
            HStack(alignment: .bottom, spacing: 0) {
                if message.isFromMe {
                    Spacer(minLength: 56)
                }

                VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: 4) {
                    messageContent
                        .contextMenu {
                            if !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button {
                                    UIPasteboard.general.string = message.text
                                } label: {
                                    Label(tr("common_copy"), systemImage: "doc.on.doc")
                                }
                            }

                            if isImageMessage {
                                Button {
                                    saveImageToPhotos()
                                } label: {
                                    Label("Fotoğrafı Kaydet", systemImage: "square.and.arrow.down")
                                }
                            }

                            if message.isFailed && message.isFromMe {
                                Button {
                                    Task {
                                        await FriendStore.sharedRetryBridge?(message)
                                    }
                                } label: {
                                    Label("Tekrar Gönder", systemImage: "arrow.clockwise")
                                }
                            }

                            if message.isFromMe {
                                Button(role: .destructive) {
                                    onDelete()
                                } label: {
                                    Label(tr("common_delete"), systemImage: "trash")
                                }
                            }
                        }

                    if showTime {
                        Text(timeText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.horizontal, 4)
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }

                    if message.isFromMe {
                        HStack(spacing: 0) {
                            messageStatusSymbol
                        }
                        .foregroundStyle(messageStatusColor)
                        .padding(.horizontal, 6)
                        .padding(.top, 1)
                    }
                }

                if !message.isFromMe {
                    Spacer(minLength: 56)
                }
            }
        }
        .padding(.vertical, 3)
        .onTapGesture {
            if isImageMessage {
                showImageViewer = true
            } else {
                withAnimation(.spring(response: 0.28)) {
                    showTime.toggle()
                }
            }
        }
        .fullScreenCover(isPresented: $showImageViewer) {
            if let mediaURL = message.mediaURL {
                FullScreenImageViewer(
                    imageURLString: mediaURL,
                    onSave: {
                        saveImageToPhotos()
                    }
                )
            }
        }
        .alert("Bilgi", isPresented: $showImageSaveAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(imageSaveAlertText)
        }
        .transition(
            .asymmetric(
                insertion: .move(edge: message.isFromMe ? .trailing : .leading)
                    .combined(with: .opacity),
                removal: .opacity
            )
        )
    }

    @ViewBuilder
    private var messageContent: some View {
        if isImageMessage {
            imageMessageBubble
        } else if isFileMessage {
            fileMessageBubble
        } else if isVoiceMessage {
            voiceMessageBubble
        } else {
            textMessageBubble
        }
    }

    private var voiceMessageBubble: some View {
        VoiceMessageBubble(message: message)
    }

    private struct VoiceMessageBubble: View {
        let message: FriendChatMessageItem

        @State private var player: AVPlayer?
        @State private var isPlaying = false
        @State private var observer: Any?

        var body: some View {
            Button {
                togglePlayback()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(message.isFromMe ? 0.18 : 0.08))
                            .frame(width: 40, height: 40)

                        if message.messageStatus == "uploading" || message.isPending {
                            ProgressView()
                                .scaleEffect(0.85)
                                .tint(message.isFromMe ? .white : FriendChatArenaPalette.blue)
                        } else {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(message.isFromMe ? .white : FriendChatArenaPalette.blue)
                        }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 3) {
                            ForEach(0..<20, id: \.self) { i in
                                Capsule()
                                    .fill((message.isFromMe ? Color.white : Color.white.opacity(0.9)).opacity(
                                        isPlaying ? (i % 2 == 0 ? 0.95 : 0.45) : (i % 3 == 0 ? 0.95 : 0.5)
                                    ))
                                    .frame(width: 3, height: CGFloat(8 + (i % 6) * 3))
                                    .scaleEffect(y: isPlaying ? (i % 2 == 0 ? 1.15 : 0.88) : 1.0)
                                    .animation(.easeInOut(duration: 0.22), value: isPlaying)
                            }
                        }

                        Text(message.text.isEmpty ? "Ses mesajı" : message.text)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(message.isFromMe ? .white.opacity(0.88) : .white.opacity(0.72))
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(message.isFromMe ? AnyShapeStyle(FriendChatArenaPalette.sentBubbleGradient) : AnyShapeStyle(Color.white.opacity(0.055)))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(message.isFromMe ? Color.white.opacity(0.08) : Color.white.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(message.messageStatus == "uploading" || message.isPending)
            .onDisappear {
                player?.pause()
                isPlaying = false

                if let observer {
                    NotificationCenter.default.removeObserver(observer)
                }
            }
        }

        private func togglePlayback() {
            guard let mediaURL = message.mediaURL,
                  let url = URL(string: mediaURL) else { return }

            if isPlaying {
                player?.pause()
                isPlaying = false
                return
            }

            let item = AVPlayerItem(url: url)
            let newPlayer = AVPlayer(playerItem: item)
            player = newPlayer

            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }

            observer = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { _ in
                isPlaying = false
                player?.seek(to: .zero)
            }

            newPlayer.play()
            isPlaying = true
        }
    }

    private var textMessageBubble: some View {
        Text(message.text)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(message.isFromMe ? .white : .white.opacity(0.96))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(messageBubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var imageMessageBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let mediaURL = message.mediaURL,
                   let url = URL(string: mediaURL) {
                    AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
                        switch phase {
                        case .empty:
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.08))

                                ProgressView()
                                    .tint(.white.opacity(0.8))
                            }
                            .frame(width: 220, height: 260)

                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 220, height: 260)
                                .clipped()

                        case .failure:
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.08))

                                VStack(spacing: 8) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 26, weight: .medium))

                                    Text("Görsel yüklenemedi")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(.white.opacity(0.75))
                            }
                            .frame(width: 220, height: 260)

                        @unknown default:
                            EmptyView()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 220, height: 260)
                }

                if message.messageStatus == "uploading" || message.isPending {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.22))
                        .frame(width: 220, height: 260)
                        .overlay {
                            VStack(spacing: 10) {
                                ProgressView()
                                    .tint(.white)

                                Text(message.messageStatus == "uploading" ? "Fotoğraf yükleniyor" : "Hazırlanıyor")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
            }

            if !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               message.text != "📷 Fotoğraf" {
                Text(message.text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(message.isFromMe ? .white : .white.opacity(0.96))
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
            }
        }
        .padding(8)
        .background(messageBubbleBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func presentShareSheet(url: URL) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }

        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        root.present(vc, animated: true)
    }

    private func downloadFile() {
        guard let mediaURL = message.mediaURL,
              let url = URL(string: mediaURL) else {
            return
        }

        URLSession.shared.downloadTask(with: url) { tempURL, _, error in
            guard let tempURL, error == nil else {
                print("❌ Dosya indirilemedi")
                return
            }

            let fileName = message.fileName ?? url.lastPathComponent
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            do {
                try? FileManager.default.removeItem(at: destination)
                try FileManager.default.copyItem(at: tempURL, to: destination)

                DispatchQueue.main.async {
                    presentShareSheet(url: destination)
                }
            } catch {
                print("❌ Dosya kaydedilemedi:", error)
            }
        }.resume()
    }

    private var fileMessageBubble: some View {
        Button {
            downloadFile()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(message.isFromMe ? 0.16 : 0.08))
                        .frame(width: 46, height: 46)

                    Image(systemName: "doc.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(message.isFromMe ? .white : FriendChatArenaPalette.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(message.fileName ?? "Dosya")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(message.isFromMe ? .white : .white.opacity(0.96))
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        if let mimeType = message.mimeType, !mimeType.isEmpty {
                            Text(shortMimeText(mimeType))
                        }

                        if let size = message.fileSizeBytes {
                            Text(fileSizeText(size))
                        }
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(message.isFromMe ? .white.opacity(0.78) : .white.opacity(0.58))
                }

                Spacer(minLength: 0)

                Group {
                    if message.isFailed {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    } else if message.messageStatus == "uploading" || message.isPending {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(message.isFromMe ? .white : FriendChatArenaPalette.blue)
                    } else {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(message.isFromMe ? .white.opacity(0.9) : .white.opacity(0.72))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(messageBubbleBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var messageStatusSymbol: some View {
        if message.isFailed {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 10, weight: .bold))
        } else if message.messageStatus == "uploading" {
            ProgressView()
                .scaleEffect(0.55)
                .tint(.white.opacity(0.9))
        } else if message.isPending {
            Image(systemName: "clock")
                .font(.system(size: 9, weight: .medium))
        } else if message.seenAt != nil {
            HStack(spacing: -3) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.system(size: 9, weight: .bold))
        } else if message.deliveredAt != nil {
            HStack(spacing: -3) {
                Image(systemName: "checkmark")
                Image(systemName: "checkmark")
            }
            .font(.system(size: 9, weight: .bold))
        } else if message.serverID != nil {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
        } else {
            Image(systemName: "clock")
                .font(.system(size: 9, weight: .medium))
        }
    }

    private var messageStatusColor: Color {
        if message.isFailed {
            return .red.opacity(0.92)
        }

        if message.messageStatus == "uploading" {
            return Color.white.opacity(0.78)
        }

        if message.isPending {
            return Color.white.opacity(0.42)
        }

        if message.seenAt != nil {
            return FriendChatArenaPalette.cyan
        }

        if message.deliveredAt != nil {
            return Color.white.opacity(0.72)
        }

        return Color.white.opacity(0.58)
    }

    @ViewBuilder
    private var messageBubbleBackground: some View {
        if message.isFromMe {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(FriendChatArenaPalette.sentBubbleGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: FriendChatArenaPalette.blue.opacity(0.16), radius: 8, y: 4)
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.060),
                            Color.white.opacity(0.040)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.085), lineWidth: 1)
                )
        }
    }

    private func fileSizeText(_ bytes: Int64) -> String {
        FriendChatFormatters.byteFormatter.string(fromByteCount: bytes)
    }

    private func shortMimeText(_ mime: String) -> String {
        if mime == "application/pdf" { return "PDF" }
        if mime.contains("image") { return "Görsel" }
        return "Dosya"
    }

    private func saveImageToPhotos() {
        guard let mediaURL = message.mediaURL,
              let url = URL(string: mediaURL) else {
            imageSaveAlertText = "Görsel bulunamadı."
            showImageSaveAlert = true
            return
        }

        isSavingImage = true

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                isSavingImage = false

                guard let data,
                      let image = UIImage(data: data),
                      error == nil else {
                    imageSaveAlertText = "Görsel indirilemedi."
                    showImageSaveAlert = true
                    return
                }

                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    DispatchQueue.main.async {
                        guard status == .authorized || status == .limited else {
                            imageSaveAlertText = "Fotoğraflara kaydetme izni verilmedi."
                            showImageSaveAlert = true
                            return
                        }

                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        imageSaveAlertText = "Fotoğraf galerine kaydedildi."
                        showImageSaveAlert = true
                    }
                }
            }
        }.resume()
    }
}

// MARK: - Full Screen Image Viewer

private struct FullScreenImageViewer: View {
    let imageURLString: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let url = URL(string: imageURLString) {
                AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .tint(.white)

                    case .success(let image):
                        FullScreenImageContent(image: image)

                    case .failure:
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 36))

                            Text("Görsel yüklenemedi")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.8))

                    @unknown default:
                        EmptyView()
                    }
                }
            }

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        onSave()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(.black.opacity(0.35), in: Circle())
                    }

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(.black.opacity(0.35), in: Circle())
                    }
                }
                .padding(.top, 18)
                .padding(.trailing, 16)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct FullScreenImageContent: View {
    let image: Image

    var body: some View {
        GeometryReader { geo in
            image
                .resizable()
                .scaledToFit()
                .frame(width: geo.size.width, height: geo.size.height)
                .background(Color.black)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Camera Picker

private struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }

            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Color Hex

private extension Color {
    init(friendChatHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch cleaned.count {
        case 3:
            a = 255
            r = (int >> 8) * 17
            g = ((int >> 4) & 0xF) * 17
            b = (int & 0xF) * 17

        case 6:
            a = 255
            r = int >> 16
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        case 8:
            a = int >> 24
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        default:
            a = 255
            r = 255
            g = 255
            b = 255
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
