//
//  CrewChatView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 15.03.2026.
//
import SwiftUI
import SwiftData
import Combine

struct CrewChatView: View {
    let crew: Crew

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @AppStorage("appTheme") var appTheme = AppTheme.gradient.rawValue

    @Query(sort: \CrewMessage.createdAt, order: .forward)
    var allMessages: [CrewMessage]

    @Query var members: [CrewMember]
    @Query var focusSessions: [CrewFocusSession]

    @State var mentionQuery: String = ""
    @State var showMentionPicker = false

    @State var draftMessage: String = ""
    @State var animateMessages = false
    @State var showCrewInfo = false
    @State var replyingTo: CrewMessage?
    @State var reactionTarget: CrewMessage?
    @State var reactionAnchor: CGRect = .zero
    @State var pressedMessageID: UUID?
    @State var showFocusDurationSheet = false
    @State var customFocusMinutes: Int = 25
    
    let sessionCheckTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    @FocusState var isComposerFocused: Bool

    let palette = ThemePalette()
    let replyMarker = "[[reply]]"
    let bodyMarker = "[[body]]"

    var messages: [CrewMessage] {
        Array(allMessages.filter { $0.crewID == crew.id }.suffix(80))
    }

    var crewMembers: [CrewMember] {
        members.filter { $0.crewID == crew.id }
    }

    var filteredMentionMembers: [CrewMember] {
        guard showMentionPicker else { return [] }

        if mentionQuery.isEmpty {
            return crewMembers
        }

        return crewMembers.filter {
            $0.name.localizedCaseInsensitiveContains(mentionQuery)
        }
    }

    var activeFocusSession: CrewFocusSession? {
        focusSessions.first {
            $0.crewID == crew.id && $0.isActive
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()

            if reactionTarget != nil {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        reactionTarget = nil
                        pressedMessageID = nil
                    }
            }

            VStack(spacing: 0) {
                header

                if let activeFocusSession {
                    NavigationLink {
                        CrewFocusRoomView(session: activeFocusSession)
                    } label: {
                        ActiveFocusBanner(
                            session: activeFocusSession,
                            palette: palette
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .transition(.scale.combined(with: .opacity))
                    }
                    .buttonStyle(.plain)
                }

                if messages.isEmpty {
                    emptyState
                } else {
                    messagesList
                }

                composerBar
            }
        }
        .contentShape(Rectangle())
        .hideKeyboardOnTap()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            seedMessagesIfNeeded()
            markMessagesAsRead()
            finalizeExpiredCrewSessionsIfNeeded()
        }
        .onReceive(sessionCheckTimer) { _ in
            finalizeExpiredCrewSessionsIfNeeded()
        }
        .sheet(isPresented: $showCrewInfo) {
            NavigationStack {
                CrewChatInfoView(crew: crew)
            }
        }
        .sheet(isPresented: $showFocusDurationSheet) {
            focusDurationSheet
        }
    }
}
private extension CrewChatView {
    func finalizeExpiredCrewSessionsIfNeeded() {
        let activeSessions = focusSessions.filter {
            $0.crewID == crew.id && $0.isActive && !$0.isPaused
        }

        guard !activeSessions.isEmpty else { return }

        let now = Date()

        for session in activeSessions {
            let remaining = Int(ceil(session.endDate.timeIntervalSince(now)))
            guard remaining <= 0 else { continue }

            let elapsedSeconds = max(0, Int(now.timeIntervalSince(session.startedAt)))
            let completedMinutes = max(1, elapsedSeconds / 60)
            guard completedMinutes > 0 else { continue }

            for name in session.participantNames {
                let record = CrewFocusRecord(
                    crewID: session.crewID,
                    memberName: name,
                    minutes: completedMinutes
                )
                modelContext.insert(record)
            }

            if crew.id == session.crewID {
                crew.totalFocusMinutes += completedMinutes * session.participantNames.count
            }

            let activeMembers = members.filter { $0.crewID == session.crewID }
            for member in activeMembers {
                if session.participantNames.contains(member.name) {
                    member.presence = "online"
                }
            }

            let activity = CrewActivity(
                crewID: session.crewID,
                memberName: session.hostName,
                actionText: "completed a shared focus session"
            )
            modelContext.insert(activity)

            let message = CrewMessage(
                crewID: session.crewID,
                senderName: session.hostName,
                text: "ended the shared focus session",
                isFromMe: false,
                isRead: false
            )
            modelContext.insert(message)

            session.isActive = false
            session.isPaused = false
            session.pausedRemainingSeconds = nil
        }

        try? modelContext.save()
    }
}

