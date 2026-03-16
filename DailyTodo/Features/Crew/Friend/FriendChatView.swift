//
//  FriendChatView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI
import SwiftData

struct FriendChatView: View {
    let friend: Friend

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @AppStorage("appTheme") var appTheme = AppTheme.gradient.rawValue
    let palette = ThemePalette()

    @Query(sort: \FriendMessage.createdAt, order: .forward)
    var allMessages: [FriendMessage]

    @State var draftMessage: String = ""
    @State var animateMessages = false
    @State var sendPressed = false
    @State var showFriendInfo = false
    @State var replyingTo: FriendMessage?
    @State var reactionTarget: FriendMessage?
    @State var pressedMessageID: UUID?

    @FocusState var isComposerFocused: Bool

    let replyMarker = "[[reply]]"
    let bodyMarker = "[[body]]"

    var messages: [FriendMessage] {
        allMessages.filter { $0.friendID == friend.id }
    }

    var body: some View {
        ZStack(alignment: .top) {
            ambientBackground

            VStack(spacing: 0) {
                customHeader

                if messages.isEmpty {
                    emptyState
                } else {
                    messagesList
                }

                composerBar
            }

            if reactionTarget != nil {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        reactionTarget = nil
                        pressedMessageID = nil
                    }
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
        .overlay {
            if reactionTarget != nil {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        reactionTarget = nil
                        pressedMessageID = nil
                    }
            }
        }
        .sheet(isPresented: $showFriendInfo) {
            NavigationStack {
                FriendChatInfoView(friend: friend)
            }
        }
    }
}
