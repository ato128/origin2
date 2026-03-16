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

    @FocusState var isComposerFocused: Bool

    let palette = ThemePalette()
    let replyMarker = "[[reply]]"
    let bodyMarker = "[[body]]"

    var messages: [CrewMessage] {
        allMessages.filter { $0.crewID == crew.id }
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
