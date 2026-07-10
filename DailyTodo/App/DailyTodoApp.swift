//
//  DailyTodoApp.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData
import WidgetKit
import UserNotifications
import UIKit
import RevenueCat
import PostHog

@main
struct DailyTodoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    private let container: ModelContainer
    private let appGroupID = "group.com.atakan.updo"

    @StateObject private var session = SessionStore()
    @StateObject private var crewStore = CrewStore()
    @StateObject private var friendStore = FriendStore()
    @StateObject private var todoStore: TodoStore
    @StateObject private var languageManager = LanguageManager()
    @StateObject private var focusSession = FocusSessionManager.shared
    @StateObject private var studentStore: StudentStore
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    @State private var openFocusFromNotification: Bool = false
    @State private var crewFocusInvitePayload: CrewFocusInvitePayload?
    @State private var friendFocusInvitePayload: FriendFocusInvitePayload?

    init() {
        do {
            guard let groupURL = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroupID
            ) else {
                fatalError("App Group container bulunamadı")
            }

            let supportURL = groupURL.appendingPathComponent("Library/Application Support")

            try FileManager.default.createDirectory(
                at: supportURL,
                withIntermediateDirectories: true
            )

            let storeURL = supportURL.appendingPathComponent("default.store")

            let schema = Schema([
                DTTaskItem.self,
                WorkoutExerciseItem.self,
                WorkoutExerciseHistoryItem.self,
                EventItem.self,
                ExamItem.self,
                StudentProfile.self,
                Course.self,
                ExamStudyPlanItem.self,
                IdentityProgressState.self,
                FocusSessionRecord.self,
                Crew.self,
                CrewMember.self,
                CrewTask.self,
                CrewActivity.self,
                Friend.self,
                FriendMessage.self,
                ChatCachedMessage.self,
                ChatCachedConversation.self,
                SharedWeekItem.self,
                FriendFocusSession.self,
                CrewMessage.self,
                CrewFocusSession.self,
                CrewFocusRecord.self,
                FriendRequest.self,
                ChatCachedConversationMessage.self
            ])

            let configuration = ModelConfiguration(
                schema: schema,
                url: storeURL
            )

            // Resilient creation: if an in-place migration of the existing store
            // fails (e.g. after a schema change), don't crash on launch — back up
            // the incompatible store and start fresh so the app stays usable.
            do {
                container = try ModelContainer(
                    for: schema,
                    configurations: [configuration]
                )
            } catch {
                Log.debug("⚠️ ModelContainer migration failed, recovering store:", error)
                Self.backupIncompatibleStore(at: storeURL)
                container = try ModelContainer(
                    for: schema,
                    configurations: [configuration]
                )
            }

            FocusCompletionRecorder.shared.configure(container: container)

            let context = ModelContext(container)

            _todoStore = StateObject(
                wrappedValue: TodoStore(context: context)
            )

            _studentStore = StateObject(
                wrappedValue: StudentStore(context: context)
            )

        } catch {
            fatalError("SwiftData container oluşturulamadı: \(error)")
        }
    }

    /// Moves an incompatible SwiftData store aside (keeping a timestamped backup)
    /// so a fresh store can be created instead of crashing at launch.
    private static func backupIncompatibleStore(at storeURL: URL) {
        let fm = FileManager.default
        let stamp = Int(Date().timeIntervalSince1970)
        for suffix in ["", "-wal", "-shm"] {
            let src = URL(fileURLWithPath: storeURL.path + suffix)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = URL(fileURLWithPath: storeURL.path + ".bak\(stamp)" + suffix)
            try? fm.moveItem(at: src, to: dst)
        }
    }

    var body: some Scene {
        WindowGroup {
            rootContent
        }
    }

    private var rootContent: some View {
        RootView(
            openFocusFromNotification: $openFocusFromNotification
        )
        .id(languageManager.selectedLanguage)
        .modelContainer(container)
        .environmentObject(todoStore)
        .environmentObject(session)
        .environmentObject(crewStore)
        .environmentObject(friendStore)
        .environmentObject(languageManager)
        .environmentObject(focusSession)
        .environment(\.locale, languageManager.activeLocale)
        .environmentObject(studentStore)
        .environmentObject(subscriptionManager)
        .overlay {
            InAppBannerOverlay()
        }
        .sheet(item: $focusSession.completionSummary) { summary in
            // Sheets presented from this level sit OUTSIDE the environmentObject
            // chain above — inject explicitly or the celebration crashes.
            FocusCelebrationView(summary: summary) {
                focusSession.dismissCompletionSummary()
            }
            .environmentObject(todoStore)
        }
        .sheet(item: $crewFocusInvitePayload) { payload in
            CrewFocusInviteSheet(
                payload: payload,
                onJoin: {
                    handleCrewFocusInviteJoin(payload)
                },
                onDismiss: {
                    crewFocusInvitePayload = nil
                }
            )
            .interactiveDismissDisabled(false)
        }
        .sheet(item: $friendFocusInvitePayload) { payload in
            FriendFocusInviteSheet(
                payload: payload,
                onJoin: {
                    handleFriendFocusInviteJoin(payload)
                },
                onDecline: {
                    friendFocusInvitePayload = nil
                    Task { await FriendFocusBackendClient.shared.decline(sessionID: payload.sessionID) }
                }
            )
            .interactiveDismissDisabled(false)
        }
        .onAppear {
            handleAppAppear()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveAPNSToken)) { _ in
            handleAPNSTokenNotification()
        }
        .onReceive(NotificationCenter.default.publisher(for: .appIconDidChange)) { _ in
            rescheduleLocalNotificationsAndRegisterPush(reason: "app icon changed")
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSessionRecordSaved)) { _ in
            let context = ModelContext(container)
            let currentUserID = session.currentUser?.id.uuidString

            Task {
                await SmartNotificationScheduler.shared.reschedule(
                    context: context,
                    currentUserID: currentUserID,
                    reason: "focus record saved"
                )
            }
        }
        .onChange(of: session.currentUser?.id) { _, newID in
            handleCurrentUserChanged(newID)
        }
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChanged(newPhase)
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openURLFromNotification)) { output in
            guard let url = output.object as? URL else { return }
            handleIncomingURL(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .presentActiveCrewFocusFromNotification)) { _ in
            openFocusFromNotification = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .presentCrewFocusInviteSheet)) { output in
            guard let userInfo = output.object as? [AnyHashable: Any] else { return }
            handleCrewFocusInviteReceived(userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .presentFriendFocusInviteSheet)) { output in
            guard let userInfo = output.object as? [AnyHashable: Any] else { return }
            handleFriendFocusInviteReceived(userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .friendFocusPeerEvent)) { output in
            guard let userInfo = output.object as? [AnyHashable: Any] else { return }
            handleFriendFocusPeerEvent(userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .presentFocusCompletionFromPush)) { output in
            handleFocusCompletionPush(output.object as? [AnyHashable: Any])
        }
    }
    
    private var resolvedCurrentDisplayName: String {
        if let user = session.currentUser {
            if !user.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return user.fullName
            }

            if !user.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return user.username
            }

            if !user.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return user.email.components(separatedBy: "@").first ?? user.email
            }
        }

        return focusSession.currentUserDisplayName
    }

    private func handleAppAppear() {
        SubscriptionManager.shared.configure()
        Analytics.shared.configure()
        Analytics.shared.track("app_opened")

        // Wire focus dependencies at launch — an expired background session must
        // finalize (and show its celebration) no matter which tab opens first.
        focusSession.configure(sessionStore: session, crewStore: crewStore)

        observeAPNSTokenNotificationIfNeeded()

        Task {
            await session.restoreSupabaseSessionIfNeeded()

            await MainActor.run {
                PushTokenStore.shared.saveCurrentTokenWithRetry(
                    reason: "onAppear after session restore"
                )
            }
        }

        let context = ModelContext(container)

        WidgetAppSync.refreshFromSwiftData(context: context)

        LiveActivityScheduler.shared.registerBGTask()
        LiveActivityScheduler.shared.startForegroundLoop(container: container)

        let currentUserID = session.currentUser?.id.uuidString

        todoStore.setCurrentUserID(currentUserID)
        studentStore.setCurrentUserID(currentUserID)
        LiveActivityScheduler.shared.setCurrentUserID(currentUserID)

        syncCurrentUserIDToDefaults(session.currentUser?.id)

        if let userID = session.currentUser?.id {
            updateFriendPresence(isOnline: true)
            bootstrapFriendRealtime(for: userID)
        }

        rescheduleLocalNotificationsAndRegisterPush(reason: "onAppear")
        
        startInboxSocket()

        Task {
            await ChatBackendClient.shared.testMe()
        }
    }
    
    // MARK: - Friend focus (duo) invite handling

    private func handleFriendFocusInviteReceived(_ userInfo: [AnyHashable: Any]) {
        guard let payload = FriendFocusInvitePayload.from(userInfo: userInfo) else {
            Log.debug("⚠️ FriendFocusInvitePayload parse FAILED")
            return
        }

        if focusSession.isSessionActive,
           focusSession.currentFriendSessionID == payload.sessionID {
            Log.debug("⚪️ FRIEND INVITE SKIPPED: already in this session")
            return
        }

        friendFocusInvitePayload = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            friendFocusInvitePayload = payload
        }
    }

    private func handleFriendFocusInviteJoin(_ payload: FriendFocusInvitePayload) {
        Task {
            guard let dto = await FriendFocusBackendClient.shared.join(sessionID: payload.sessionID) else {
                await MainActor.run { friendFocusInvitePayload = nil }
                return
            }

            await MainActor.run {
                let started = focusSession.startFriendSessionAsGuest(
                    sessionID: dto.id,
                    hostUserID: dto.host_id,
                    hostName: dto.host_name.isEmpty ? payload.hostName : dto.host_name,
                    durationMinutes: dto.duration_minutes,
                    startedAt: dto.startedAtDate ?? payload.startedAt
                )
                friendFocusInvitePayload = nil

                if !started {
                    Log.debug("⚠️ FRIEND FOCUS GUEST START FAILED")
                }
            }
        }
    }

    /// Live duo updates (joined / left / declined / ended) arriving as pushes.
    private func handleFriendFocusPeerEvent(_ userInfo: [AnyHashable: Any]) {
        guard let type = userInfo["type"] as? String else { return }

        switch type {
        case "friend_focus_joined":
            let name = (userInfo["joined_name"] as? String) ?? "Arkadaşın"
            focusSession.handleFriendFocusJoined(name: name, friendUserID: nil)

        case "friend_focus_left", "friend_focus_declined", "friend_focus_ended":
            focusSession.handleFriendFocusPeerLeft()

        default:
            break
        }
    }

    private func handleCrewFocusInviteReceived(_ userInfo: [AnyHashable: Any]) {
        Log.debug("📨 RECEIVED INVITE NOTIFICATION:", userInfo)
        
        guard let payload = CrewFocusInvitePayload.from(userInfo: userInfo) else {
            Log.debug("⚠️ CrewFocusInvitePayload parse FAILED")
            return
        }
        
        Log.debug("✅ INVITE PARSED:", payload.crewName, payload.hostName)
     
        handleCrewFocusInviteReceivedPayload(payload)
    }
    
    private func handleCrewFocusInviteReceivedPayload(_ payload: CrewFocusInvitePayload) {
        if focusSession.isSessionActive,
           focusSession.currentCrewBackendSessionID == payload.sessionID {
            Log.debug("⚪️ INVITE SKIPPED: already in this session")
            return
        }

        crewFocusInvitePayload = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            crewFocusInvitePayload = payload
            Log.debug("📤 INVITE SHEET ATANDI")
        }
    }
     
    private func handleCrewFocusInviteJoin(_ payload: CrewFocusInvitePayload) {
        Task {
            do {
                try await crewStore.joinCrewFocusSession(
                    sessionID: payload.sessionID,
                    crewID: payload.crewID,
                    userID: session.currentUser?.id,
                    memberName: resolvedCurrentDisplayName
                )
     
                await crewStore.loadActiveFocusSession(for: payload.crewID)
     
                guard let dto = crewStore.activeFocusSessionByCrew[payload.crewID] else {
                    await MainActor.run {
                        crewFocusInvitePayload = nil
                    }
                    return
                }
     
                await crewStore.loadFocusParticipants(sessionID: dto.id)
                let participants = crewStore.focusParticipantsBySession[dto.id] ?? []
     
                await MainActor.run {
                    focusSession.hydrateFromCrewSessionDTO(
                        dto,
                        crewID: payload.crewID,
                        participantsDTO: participants,
                        preferredGoal: .study,
                        preferredStyle: .silent
                    )

                    crewFocusInvitePayload = nil
                    openFocusFromNotification = true
                }
            } catch {
                Log.debug("JOIN INVITE FROM SHEET ERROR:", error.localizedDescription)
                await MainActor.run {
                    crewFocusInvitePayload = nil
                }
            }
        }
    }

    private func observeAPNSTokenNotificationIfNeeded() {
        NotificationCenter.default.removeObserver(
            self,
            name: .didReceiveAPNSToken,
            object: nil
        )

        NotificationCenter.default.addObserver(
            forName: .didReceiveAPNSToken,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                Log.debug("🔥 TOKEN RECEIVED -> SAVE WITH RETRY")
                PushTokenStore.shared.saveCurrentTokenWithRetry(
                    reason: "didReceiveAPNSToken observer"
                )
            }
        }
    }

    private func handleAPNSTokenNotification() {
        Task { @MainActor in
            Log.debug("🔥 TOKEN RECEIVED -> SAVE WITH RETRY FROM ONRECEIVE")
            PushTokenStore.shared.saveCurrentTokenWithRetry(
                reason: "didReceiveAPNSToken onReceive"
            )
        }
    }

    private func handleCurrentUserChanged(_ newID: UUID?) {
        let userIDString = newID.map { $0.uuidString }

        if let userIDString {
            Analytics.shared.identify(userID: userIDString)
        } else {
            Analytics.shared.reset()
        }

        todoStore.setCurrentUserID(userIDString)
        studentStore.setCurrentUserID(userIDString)
        LiveActivityScheduler.shared.setCurrentUserID(userIDString)

        syncCurrentUserIDToDefaults(newID)

        friendStore.unsubscribePresenceRealtime()
        friendStore.unsubscribeFriendshipsRealtime()

        if let newID {
            updateFriendPresence(isOnline: true)
            bootstrapFriendRealtime(for: newID)
        }

        let context = ModelContext(container)
        WidgetAppSync.refreshFromSwiftData(context: context)

        Task { @MainActor in
            LiveActivityScheduler.shared.rescheduleBackgroundTask(container: container)
        }

        rescheduleLocalNotificationsAndRegisterPush(reason: "session user changed")

        guard newID != nil else { return }

        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            await MainActor.run {
                Log.debug("💾 TOKEN SAVE RETRY (user change)...")
                PushTokenStore.shared.forceResaveCurrentToken(
                    reason: "session user changed"
                )
            }
        }
    }
    
    private func handleFocusCompletionPush(_ userInfo: [AnyHashable: Any]?) {
        guard let userInfo else { return }

        // Fallback only: if this device ran the session, reconcile already built
        // the real summary (right mode, goal, participants) — never overwrite it
        // with this degraded push-based one.
        guard focusSession.completionSummary == nil else { return }
     
        let durationMinutes: Int = {
            if let intValue = userInfo["duration_minutes"] as? Int {
                return intValue
            }
            if let stringValue = userInfo["duration_minutes"] as? String,
               let parsed = Int(stringValue) {
                return parsed
            }
            return 0
        }()
     
        guard durationMinutes > 0 else { return }
     
        let previousMinutes: Int? = {
            if let intValue = userInfo["previous_minutes"] as? Int {
                return intValue > 0 ? intValue : nil
            }
            if let stringValue = userInfo["previous_minutes"] as? String,
               let parsed = Int(stringValue), parsed > 0 {
                return parsed
            }
            return nil
        }()
     
        // Real numbers — a push-built summary must not invent a streak.
        let context = ModelContext(container)
        let records = (try? context.fetch(FetchDescriptor<FocusSessionRecord>())) ?? []
        let todayMinutes = FocusStats.todayMinutes(records, for: session.currentUser?.id.uuidString)

        let summary = FocusCompletionSummary(
            id: UUID(),
            mode: .crew,
            durationMinutes: durationMinutes,
            completedAt: Date(),
            totalTodayMinutes: max(todayMinutes, durationMinutes),
            streakDays: ProgressionManager.shared.currentStreak,
            completedSessionsToday: 1,
            goal: .study,
            style: .silent,
            participantCount: 1,
            previousMinutes: previousMinutes
        )

        focusSession.completionSummary = summary
    }

    private func handleScenePhaseChanged(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            LiveActivityScheduler.shared.startForegroundLoop(container: container)
            Task { await SubscriptionManager.shared.refresh() }

            focusSession.reconcileExpiredSessionIfNeeded(reason: "scene active")
            
            let context = ModelContext(container)
            WidgetAppSync.refreshFromSwiftData(context: context)

            friendStore.setAppActive(true)
            updateFriendPresence(isOnline: true)

            if let userID = session.currentUser?.id {
                bootstrapFriendRealtime(for: userID)
            }

            Task { @MainActor in
                Log.debug("🔥 PUSH TOKEN SAVE ON ACTIVE")
                PushTokenStore.shared.saveCurrentTokenWithRetry(
                    reason: "scene active"
                )
            }
            startInboxSocket()
            rescheduleSmartNotifications(reason: "scene active")

        case .inactive:
            friendStore.setAppActive(false)

        case .background:
            friendStore.setAppActive(false)
            updateFriendPresence(isOnline: false)

            LiveActivityScheduler.shared.stopForegroundLoop()
            LiveActivityScheduler.shared.rescheduleBackgroundTask(container: container)

            // Last look before the app sleeps: cancels pending nudges whose
            // condition the user just satisfied (e.g. streak saved via a task).
            rescheduleSmartNotifications(reason: "scene background")

        @unknown default:
            break
        }
    }
    
    private func rescheduleSmartNotifications(reason: String) {
        let context = ModelContext(container)
        let currentUserID = session.currentUser?.id.uuidString

        Task {
            await SmartNotificationScheduler.shared.reschedule(
                context: context,
                currentUserID: currentUserID,
                reason: reason
            )
        }
    }

    private func startInboxSocket() {
        Task { @MainActor in
            await ChatBackendInboxSocketClient.shared.connect(
                onMessageCreated: { message, conversation in
                    upsertInboxCachedConversation(conversation)

                    saveInboxMessageToCache(
                        message: message,
                        conversation: conversation
                    )
                },
                onConversationUpdated: { conversation in
                    upsertInboxCachedConversation(conversation)
                },
                onMessageSeen: { payload in
                    updateInboxSeenCache(payload)
                }
            )
        }
    }

    private func saveInboxMessageToCache(
        message: ChatBackendMessageDTO,
        conversation: ChatBackendConversationDTO?
    ) {
        guard let friendshipID = conversation?.supabaseFriendshipId else {
            Log.debug("⚪️ INBOX CACHE SKIPPED: missing friendshipID")
            return
        }

        let currentUserID = session.currentUser?.id
        let isFromMe = message.senderID == currentUserID

        let item = FriendChatMessageItem(
            id: message.id,
            serverID: message.id,
            clientID: message.clientID,
            friendshipID: friendshipID,
            senderID: message.senderID,
            senderName: isFromMe ? "You" : "Friend",
            text: message.text ?? "",
            createdAt: message.createdDate ?? Date(),
            reaction: nil,
            isSystemMessage: false,
            isFromMe: isFromMe,
            isPending: false,
            isFailed: false,
            deliveredAt: nil,
            seenAt: nil,
            messageType: message.messageType,
            mediaURL: message.mediaURL,
            fileName: message.fileName,
            fileSizeBytes: message.fileSizeBytes.map { Int64($0) },
            mimeType: message.mimeType,
            messageStatus: "sent"
        )

        upsertInboxCachedMessage(
            item,
            conversationID: message.conversationID
        )
    }

    private func upsertInboxCachedMessage(
        _ message: FriendChatMessageItem,
        conversationID: UUID?
    ) {
        let context = ModelContext(container)

        let serverKey = message.serverID.map { "server-\($0.uuidString)" }
        let clientKey = message.clientID.flatMap { $0.isEmpty ? nil : "client-\($0)" }

        do {
            var existing: ChatCachedMessage?

            if let serverKey {
                var descriptor = FetchDescriptor<ChatCachedMessage>(
                    predicate: #Predicate<ChatCachedMessage> { cached in
                        cached.cacheKey == serverKey
                    }
                )
                descriptor.fetchLimit = 1
                existing = try context.fetch(descriptor).first
            }

            if existing == nil, let clientKey {
                var descriptor = FetchDescriptor<ChatCachedMessage>(
                    predicate: #Predicate<ChatCachedMessage> { cached in
                        cached.cacheKey == clientKey
                    }
                )
                descriptor.fetchLimit = 1
                existing = try context.fetch(descriptor).first
            }

            if let existing {
                existing.update(from: message, conversationID: conversationID)
            } else {
                let created = ChatCachedMessage(
                    id: message.serverID ?? message.id,
                    serverID: message.serverID,
                    clientID: message.clientID,
                    conversationID: conversationID,
                    friendshipID: message.friendshipID,
                    senderID: message.senderID,
                    senderName: message.senderName,
                    text: message.text,
                    createdAt: message.createdAt,
                    reaction: message.reaction,
                    isSystemMessage: message.isSystemMessage,
                    isFromMe: message.isFromMe,
                    isPending: message.isPending,
                    isFailed: message.isFailed,
                    deliveredAt: message.deliveredAt,
                    seenAt: message.seenAt,
                    messageType: message.messageType,
                    mediaURL: message.mediaURL,
                    fileName: message.fileName,
                    fileSizeBytes: message.fileSizeBytes,
                    mimeType: message.mimeType,
                    messageStatus: message.messageStatus
                )

                context.insert(created)
            }

            try context.save()

            Log.debug("🟢 INBOX CACHE UPSERTED:", message.id.uuidString)
        } catch {
            Log.debug("❌ INBOX CACHE UPSERT ERROR:", error.localizedDescription)
        }
    }
    
    private func upsertInboxCachedConversation(_ conversation: ChatBackendConversationDTO?) {
        guard let conversation else { return }
        guard let ownerUserID = session.currentUser?.id else { return }

        let context = ModelContext(container)
        let cacheKey = "\(ownerUserID.uuidString)-\(conversation.id.uuidString)"

        do {
            let descriptor = FetchDescriptor<ChatCachedConversation>()
            let cached = try context.fetch(descriptor)

            if let existing = cached.first(where: { $0.cacheKey == cacheKey }) {
                existing.update(from: conversation)
            } else {
                let created = ChatCachedConversation(
                    ownerUserID: ownerUserID,
                    conversation: conversation
                )
                context.insert(created)
            }

            try context.save()

            Log.debug("🟢 INBOX CONVERSATION CACHE UPSERTED:", conversation.id.uuidString)
        } catch {
            Log.debug("❌ INBOX CONVERSATION CACHE ERROR:", error.localizedDescription)
        }
    }

    private func updateInboxSeenCache(_ payload: ChatBackendMessageSeenPayload) {
        let context = ModelContext(container)

        let conversationID = payload.conversationID
        let ids = Set(payload.messages.map { $0.id })
        let seenAt = Date()

        guard !ids.isEmpty else {
            Log.debug("⚪️ INBOX CACHE SEEN SKIPPED: empty ids")
            return
        }

        do {
            let descriptor = FetchDescriptor<ChatCachedMessage>(
                predicate: #Predicate<ChatCachedMessage> { cached in
                    cached.conversationID == conversationID
                }
            )

            let cachedMessages = try context.fetch(descriptor)

            for cached in cachedMessages {
                let effectiveID = cached.serverID ?? cached.id

                guard ids.contains(cached.id) || ids.contains(effectiveID) else {
                    continue
                }

                cached.seenAt = seenAt
                cached.isPending = false
                cached.isFailed = false
                cached.messageStatus = "seen"
                cached.updatedAt = Date()
            }

            try context.save()

            Log.debug("🟢 INBOX CACHE SEEN UPDATED:", ids.count)
        } catch {
            Log.debug("❌ INBOX CACHE SEEN ERROR:", error.localizedDescription)
        }
    }

    private func rescheduleLocalNotificationsAndRegisterPush(reason: String) {
        let context = ModelContext(container)
        let currentUserID = session.currentUser?.id.uuidString

        let descriptor = FetchDescriptor<EventItem>(
            sortBy: [SortDescriptor(\EventItem.startMinute, order: .forward)]
        )

        let allEvents = (try? context.fetch(descriptor)) ?? []
        let scopedEvents = allEvents.filter { $0.ownerUserID == currentUserID }

        Task {
            await NotificationManager.shared.requestPermissionIfNeeded()
            await NotificationManager.shared.rescheduleAll(events: scopedEvents)
            await SmartNotificationScheduler.shared.reschedule(
                context: context,
                currentUserID: currentUserID,
                reason: reason
            )
            
            await MainActor.run {
                Log.debug("📡 REGISTERING FOR REMOTE NOTIFICATIONS:", reason)
                UIApplication.shared.registerForRemoteNotifications()

                PushTokenStore.shared.saveCurrentTokenWithRetry(
                    reason: "register remote notifications - \(reason)"
                )
            }
        }
    }

    private func updateFriendPresence(isOnline: Bool) {
        guard let userID = session.currentUser?.id else { return }

        Task {
            await friendStore.setPresence(
                currentUserID: userID,
                isOnline: isOnline
            )
        }
    }

    private func bootstrapFriendRealtime(for userID: UUID) {
        Task {
            await friendStore.loadAllFriendships(currentUserID: userID)

            let otherUserIDs = friendStore.friendships.compactMap { friendship -> UUID? in
                if friendship.requester_id == userID {
                    return friendship.addressee_id
                }

                if friendship.addressee_id == userID {
                    return friendship.requester_id
                }

                return nil
            }

            await friendStore.loadPresence(for: otherUserIDs)

            await MainActor.run {
                friendStore.subscribeToFriendshipsRealtime(currentUserID: userID)
                friendStore.subscribeToPresenceRealtime(for: otherUserIDs)
            }
        }
    }

    private func syncCurrentUserIDToDefaults(_ userID: UUID?) {
        if let userID {
            UserDefaults.standard.set(userID.uuidString, forKey: "current_user_id")
        } else {
            UserDefaults.standard.removeObject(forKey: "current_user_id")
        }
    }

    private func handleIncomingURL(_ url: URL) {
        guard url.scheme == "dailytodo" else { return }
        
        if url.host == "auth" {
            handleAuthCallbackURL(url)
            return
        }

        if url.host == "live" {
            handleLiveActivityURL(url)
            return
        }

        if url.host == "week" {
            NotificationCenter.default.post(name: .openWeekFromWidget, object: nil)
            return
        }

        if url.host == "insights" {
            NotificationCenter.default.post(name: .openInsightsTab, object: nil)
            return
        }
        
        if url.host == "focus" {
            handleFocusInviteURL(url)
            return
        }

        if url.host == "join-crew" {
            handleIncomingInviteURL(url)
            return
        }

        if url.host == "friend-chat" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let friendshipID = components.queryItems?.first(where: { $0.name == "friendship_id" })?.value
            else {
                return
            }

            NotificationCenter.default.post(
                name: .openFriendChatFromNotification,
                object: friendshipID
            )
            return
        }

        if url.host == "crew-chat" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let crewID = components.queryItems?.first(where: { $0.name == "crew_id" })?.value
            else {
                return
            }

            NotificationCenter.default.post(
                name: .openCrewChatFromNotification,
                object: crewID
            )
            return
        }
    }
    
    private func handleAuthCallbackURL(_ url: URL) {
        Log.debug("🔐 AUTH CALLBACK URL:", url.absoluteString)

        Task {
            await session.handleAuthCallback(url: url)

            await MainActor.run {
                let currentUserID = session.currentUser?.id.uuidString

                todoStore.setCurrentUserID(currentUserID)
                studentStore.setCurrentUserID(currentUserID)
                LiveActivityScheduler.shared.setCurrentUserID(currentUserID)
                syncCurrentUserIDToDefaults(session.currentUser?.id)

                if let userID = session.currentUser?.id {
                    updateFriendPresence(isOnline: true)
                    bootstrapFriendRealtime(for: userID)
                }
            }
        }
    }
    
    private func handleFocusInviteURL(_ url: URL) {
        NotificationCenter.default.post(name: .openFocusTabFromHome, object: nil)

        // Widget "start" button: flag a pending autostart; FocusView consumes it
        // once it is on screen (works from cold launch too).
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           components.queryItems?.contains(where: { $0.name == "autostart" && $0.value == "1" }) == true {
            UserDefaults.standard.set(true, forKey: "focus.pendingWidgetAutostart")
            NotificationCenter.default.post(name: .startFocusFromWidget, object: nil)
            return
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let crewIDString = components.queryItems?.first(where: { $0.name == "crew_id" })?.value,
              let sessionIDString = components.queryItems?.first(where: { $0.name == "session_id" })?.value,
              let crewID = UUID(uuidString: crewIDString),
              let sessionID = UUID(uuidString: sessionIDString)
        else {
            Log.debug("⚠️ FOCUS INVITE URL PARSE FAILED:", url.absoluteString)
            return
        }

        Task {
            await crewStore.loadActiveFocusSession(for: crewID)

            guard let dto = crewStore.activeFocusSessionByCrew[crewID],
                  dto.id == sessionID,
                  dto.is_active,
                  dto.ended_at == nil
            else {
                Log.debug("⚪️ FOCUS INVITE URL SESSION NOT ACTIVE:", sessionIDString)
                return
            }

            await crewStore.loadFocusParticipants(sessionID: dto.id)
            let participants = crewStore.focusParticipantsBySession[dto.id] ?? []

            let payload = CrewFocusInvitePayload(
                crewID: crewID,
                sessionID: dto.id,
                crewName: crewStore.crews.first(where: { $0.id == crewID })?.name ?? "Crew",
                hostName: dto.host_name,
                durationMinutes: dto.duration_minutes,
                taskTitle: dto.task_title,
                startedAt: CrewDateParser.parse(dto.started_live_at ?? dto.started_at),
                participantNames: participants.map(\.member_name),
                totalParticipants: max((dto.invited_count ?? 0) + 1, participants.count)
            )

            await MainActor.run {
                handleCrewFocusInviteReceivedPayload(payload)
            }
        }
    }

    private func handleLiveActivityURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }

        let action = components.path.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )

        if action == "stop" {
            Task {
                await LiveActivityManager.shared.end()
            }
        }
    }

    private func handleIncomingInviteURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return
        }

        NotificationCenter.default.post(
            name: .openCrewInviteFromLink,
            object: code
        )
    }
}

extension Notification.Name {
    static let openWeekFromWidget = Notification.Name("openWeekFromWidget")
    static let openCrewInviteFromLink = Notification.Name("openCrewInviteFromLink")
}
