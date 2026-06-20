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
    @Environment(\.modelContext) var modelContext
    @AppStorage("appTheme") var appTheme = AppTheme.gradient.rawValue

    @State var draftMessage: String = ""
    @State var showCrewInfo = false
    @State var replyingTo: CrewChatMessageItem?

   
    @State var focusRoomSession: CrewFocusSessionDTO?

    @State var typingStopTask: Task<Void, Never>?
    @State var isCurrentlyTyping = false
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

                if let activeFocusSession {
                    focusLiveBanner(session: activeFocusSession)
                } else if let typingText {
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
        .contentShape(Rectangle())
        .hideKeyboardOnTap()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
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

            if let myID = session.currentUser?.id {
                Task(priority: .utility) {
                    await crewStore.sendTypingEvent(
                        crewID: crew.id,
                        userID: myID,
                        name: currentDisplayName(),
                        isTyping: false
                    )
                }
            }

            Task { @MainActor in
                ChatBackendSocketClient.shared.disconnect()

                crewStore.unsubscribeCrewAuxRealtime()
                crewStore.unsubscribeCrewFocusRealtime()
            }
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
                                .foregroundStyle(.white)
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
       
        .sheet(item: $focusRoomSession) { openedSession in
            NavigationStack {
                CrewFocusRoomBackendView(
                    crew: crew,
                    sessionDTO: openedSession
                )
                .environmentObject(crewStore)
                .environmentObject(session)
            }
        }
        .onChange(of: crewStore.activeFocusSessionByCrew[crew.id]) { _, newValue in
            localActiveFocusSession = newValue
        }
    }
}
