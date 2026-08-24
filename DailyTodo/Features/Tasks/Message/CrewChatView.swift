//
//  CrewChatView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 15.03.2026.
//
import SwiftUI
import Combine
import PhotosUI
import UIKit

struct CrewChatView: View {
    let crew: WeekCrewItem

    @Environment(\.dismiss) var dismiss
    @Environment(\.locale) private var locale
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var friendStore: FriendStore
    @Environment(\.modelContext) var modelContext
    @AppStorage("appTheme") var appTheme = AppTheme.gradient.rawValue

    @State var draftMessage: String = ""
    @State var showCrewInfo = false
    @State var replyingTo: CrewChatMessageItem?
    @State var reactingMessageID: UUID?
    // Güvenlik (App Store Guideline 1.2)
    @State var reportTargetMessage: CrewChatMessageItem?
    @State var blockTargetMessage: CrewChatMessageItem?
    @State var safetyInfoText: String?
    @State var isProcessingSafety = false

    @State var typingStopTask: Task<Void, Never>?
    @State var isCurrentlyTyping = false
    @State var lastTypingSentAt: Date = .distantPast
    // Yazan üyeler — backend socket'ten (Supabase crew_typing_status yerine).
    @State var socketTypingUserIDs: Set<UUID> = []
    @State var socketTypingClearTasks: [UUID: Task<Void, Never>] = [:]
    @State private var didInitialLoad = false
    @State private var localActiveFocusSession: CrewFocusSessionDTO?
    @State var backendConversationID: UUID?
    @State var backendMessages: [CrewChatMessageItem] = []

    /// Başarısız foto gönderimlerinin retry için bellekte tutulan içeriği (clientID → payload).
    @State var crewMediaRetryPayloads: [String: (data: Data, caption: String?)] = [:]
    @State var seenMessageIDs: Set<UUID> = []
    @State var didLoadCachedMessages = false
    @State var isSyncingBackendConversation = false
    @State var hasCompletedBackendInitialSync = false
    @State var backendSyncError: String?
    @State var isSendingBackendMessage = false
    @State var didBootstrapBackendMessages = false
    @State var selectedPhotoItem: PhotosPickerItem?
    @State var draftPhotoImage: UIImage?
    @State var showAttachmentAlert = false
    @State var attachmentAlertText = ""
    @State var showPhotoPicker = false
   

    @FocusState var isComposerFocused: Bool

    let palette = ThemePalette()
    let replyMarker = "[[reply]]"
    let bodyMarker = "[[body]]"

    var activeFocusSession: CrewFocusSessionDTO? {
        localActiveFocusSession ?? crewStore.activeFocusSessionByCrew[crew.id]
    }

    var body: some View {
        ZStack {
            ambientBackground

            VStack(spacing: 0) {
                if messages.isEmpty, isSyncingBackendConversation, !didLoadCachedMessages  {
                    VStack {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                        Spacer()
                    }
                } else if messages.isEmpty {
                    emptyState
                } else {
                    messagesList
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 8) {
                floatingTopControls

                // Odak kartı kaldırıldı: canlı odak artık sağ üstteki focus pill'de
                // (dokununca odak odasını açar). Burada yalnız "yazıyor…" göster.
                if let typingText {
                    typingBanner(text: typingText)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 6)
            .background(Color.clear)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composerBar
                .padding(.top, 6)
                .background(Color.clear)
        }
        // NOT: tüm body'de .hideKeyboardOnTap() vardı; geri/crew pill/focus pill
        // tap'lerini ve scroll'u çalıyordu. Klavye artık messagesList'te
        // .scrollDismissesKeyboard(.interactively) ile kapanıyor.
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .enableInteractivePopGesture()
        .onAppear {
            guard !didInitialLoad else { return }
            didInitialLoad = true

            Task(priority: .userInitiated) {
                await loadChatData()
                await crewStore.loadActiveFocusSession(for: crew.id)

                let loadedSession = crewStore.activeFocusSessionByCrew[crew.id]
                await MainActor.run {
                    localActiveFocusSession = loadedSession
                }

                if let loadedSession {
                    await crewStore.loadFocusParticipants(sessionID: loadedSession.id)
                }

                await MainActor.run {
                    
                }
            }
            
        }
        .onDisappear {
            typingStopTask?.cancel()

            // "yazıyor durdu" backend socket üzerinden (Supabase yerine).
            ChatBackendSocketClient.shared.sendTyping(isTyping: false)

            for (_, task) in socketTypingClearTasks { task.cancel() }
            socketTypingClearTasks = [:]
            socketTypingUserIDs = []

            Task { @MainActor in
                ChatBackendSocketClient.shared.disconnect()

                crewStore.unsubscribeCrewAuxRealtime()
                crewStore.unsubscribeCrewFocusRealtime()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatBackendTyping)) { note in
            handleIncomingCrewTyping(note)
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }

            Task {
                do {
                    if let data = try await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            draftPhotoImage = image
                        }
                    }
                } catch {
                    await MainActor.run {
                        attachmentAlertText = "\(tr("fc_photo_load_failed")): \(error.localizedDescription)"
                        showAttachmentAlert = true
                    }
                }
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .alert("Bilgi", isPresented: $showAttachmentAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(attachmentAlertText)
        }
        .confirmationDialog(
            reportTargetMessage.map { appLanguageIsEnglish() ? "Report \($0.senderName)?" : "\($0.senderName) bildirilsin mi?" } ?? "",
            isPresented: Binding(
                get: { reportTargetMessage != nil },
                set: { if !$0 { reportTargetMessage = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(appLanguageIsEnglish() ? "Spam or scam" : "Spam veya dolandırıcılık") { submitCrewReport(reason: "spam") }
            Button(appLanguageIsEnglish() ? "Harassment or bullying" : "Taciz veya zorbalık") { submitCrewReport(reason: "harassment") }
            Button(appLanguageIsEnglish() ? "Inappropriate content" : "Uygunsuz içerik") { submitCrewReport(reason: "inappropriate") }
            Button(appLanguageIsEnglish() ? "Other" : "Diğer") { submitCrewReport(reason: "other") }
            Button(appLanguageIsEnglish() ? "Cancel" : "Vazgeç", role: .cancel) { reportTargetMessage = nil }
        } message: {
            Text(appLanguageIsEnglish()
                 ? "We review reports within 24 hours and take action on violations."
                 : "Şikayetleri 24 saat içinde inceler, ihlallere yaptırım uygularız.")
        }
        .confirmationDialog(
            blockTargetMessage.map { appLanguageIsEnglish() ? "Block \($0.senderName)?" : "\($0.senderName) engellensin mi?" } ?? "",
            isPresented: Binding(
                get: { blockTargetMessage != nil },
                set: { if !$0 { blockTargetMessage = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(appLanguageIsEnglish() ? "Block" : "Engelle", role: .destructive) { submitCrewBlock() }
            Button(appLanguageIsEnglish() ? "Cancel" : "Vazgeç", role: .cancel) { blockTargetMessage = nil }
        } message: {
            Text(appLanguageIsEnglish()
                 ? "You won't see their messages anymore."
                 : "Artık bu kişinin mesajlarını görmezsin.")
        }
        .alert(
            appLanguageIsEnglish() ? "Thanks" : "Teşekkürler",
            isPresented: Binding(get: { safetyInfoText != nil }, set: { if !$0 { safetyInfoText = nil } })
        ) {
            Button(appLanguageIsEnglish() ? "OK" : "Tamam", role: .cancel) { }
        } message: {
            Text(safetyInfoText ?? "")
        }
        .sheet(isPresented: $showCrewInfo) {
            NavigationStack {
                Group {
                    if let backendCrew = crewStore.crews.first(where: { $0.id == crew.id }) {
                        BackendCrewDetailView(crew: backendCrew)
                            .environmentObject(crewStore)
                            .environmentObject(session)
                    } else {
                        ZStack {
                            AppBackground()

                            ProgressView("crew_chat_loading_crew_info")
                                .foregroundStyle(UpdoTheme.textPrimary)
                        }
                        .task {
                            if crewStore.crews.isEmpty {
                                await crewStore.loadCrews()
                            }
                        }
                    }
                }
            }
        }
       
        // Eski CrewFocusRoomBackendView odası emekliye ayrıldı: focus pill artık
        // yeni focus sistemine (CrewFocusInviteSheet → FocusSessionManager) bağlanıyor.
        .onChange(of: crewStore.activeFocusSessionByCrew[crew.id]) { _, newValue in
            localActiveFocusSession = newValue
        }
    }
}
