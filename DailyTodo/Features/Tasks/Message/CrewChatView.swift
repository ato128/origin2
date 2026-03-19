//
//  CrewChatView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 15.03.2026.
//
import SwiftUI
import Combine

struct CrewChatView: View {
    let crew: WeekCrewItem

    @Environment(\.dismiss)  var dismiss
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore
    @AppStorage("appTheme")  var appTheme = AppTheme.gradient.rawValue

    @State  var mentionQuery: String = ""
    @State  var showMentionPicker = false
    @State  var draftMessage: String = ""
    @State  var showCrewInfo = false
    @State  var replyingTo: CrewMessageDTO?
    @State  var reactionTarget: CrewMessageDTO?
    @State  var pressedMessageID: UUID?
    @State  var showFocusDurationSheet = false
    @State  var customFocusMinutes: Int = 25
    @State  var optimisticMessages: [OptimisticCrewMessage] = []
    @State  var typingStopTask: Task<Void, Never>?
    @State  var lastSentTypingState: Bool = false

    @FocusState  var isComposerFocused: Bool

    let palette = ThemePalette()
    let replyMarker = "[[reply]]"
    let bodyMarker = "[[body]]"

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

                if messages.isEmpty {
                    emptyState
                } else {
                    messagesList
                }

                typingIndicatorView
                composerBar
            }
        }
        .contentShape(Rectangle())
        .hideKeyboardOnTap()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            Task {
                await loadChatData()
            }
        }
        .onDisappear {
            Task {
                if let userID = session.currentUser?.id {
                    await crewStore.sendTypingEvent(
                        crewID: crew.id,
                        userID: userID,
                        name: currentDisplayName(),
                        isTyping: false
                    )
                }
            }
            crewStore.unsubscribeCrewChat()
        }
        .sheet(isPresented: $showCrewInfo) {
            NavigationStack {
                CrewChatInfoBackendView(crew: crew)
            }
        }
        .sheet(isPresented: $showFocusDurationSheet) {
            focusDurationSheet
        }
    }
}
