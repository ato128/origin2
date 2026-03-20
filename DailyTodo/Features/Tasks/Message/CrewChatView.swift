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

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore
    @AppStorage("appTheme") var appTheme = AppTheme.gradient.rawValue

    @State var draftMessage: String = ""
    @State var showCrewInfo = false
    @State var replyingTo: CrewChatMessageItem?
    @State var showFocusDurationSheet = false
    @State var customFocusMinutes: Int = 25
    @State var typingStopTask: Task<Void, Never>?
    @State var isCurrentlyTyping = false

    @FocusState var isComposerFocused: Bool

    let palette = ThemePalette()
    let replyMarker = "[[reply]]"
    let bodyMarker = "[[body]]"

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()

            VStack(spacing: 0) {
                header

                if let typingText {
                    HStack {
                        Text(typingText)
                            .font(.caption)
                            .foregroundStyle(palette.secondaryText)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
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
            Task {
                await loadChatData()
            }
        }
        .onDisappear {
            typingStopTask?.cancel()

            if let myID = session.currentUser?.id {
                DispatchQueue.main.async {
                    Task {
                        await crewStore.sendTypingEvent(
                            crewID: crew.id,
                            userID: myID,
                            name: currentDisplayName(),
                            isTyping: false
                        )
                    }
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
