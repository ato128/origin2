//
//  RootView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Binding var openFocusFromNotification: Bool

    @AppStorage("didFinishFullOnboardingV2") private var didFinishFullOnboarding = false
    
   

    @State private var importExport: ScheduleExport? = nil
    @State private var showImportSheet: Bool = false

    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var studentStore: StudentStore

    var body: some View {
        Group {
            if !session.isSignedIn {
                AuthView()

            } else if !studentStore.didResolveRemoteProfile || studentStore.isLoading {
                studentLoadingView

            } else if !didFinishFullOnboarding {
                AppOnboardingFlowView()
            } else {
                MainTabView(
                    openFocusFromNotification: $openFocusFromNotification
                )
                .onOpenURL { url in
                    handleIncomingFileURL(url)
                }
                .onReceive(NotificationCenter.default.publisher(for: .openCrewFocusFromNotification)) { _ in
                    DispatchQueue.main.async {
                        openFocusFromNotification = true
                    }
                }
                .sheet(isPresented: $showImportSheet) {
                    if let export = importExport {
                        ImportScheduleView(export: export)
                    }
                }
            }
        }
        .task(id: session.currentUser?.id) {
            guard session.isSignedIn else {
                studentStore.clearForSignOut()
                return
            }

            await studentStore.loadFromRemote()
        }
    }
    private var studentLoadingView: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 18) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.1)

                Text("Preparing your student profile...")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.white.opacity(0.08))
            )
            .padding(.horizontal, 24)
        }
    }

    private func handleIncomingFileURL(_ url: URL) {
        guard url.isFileURL else { return }

        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let tempURL = try copyToTemporaryIfNeeded(url)
            let export = try ScheduleShare.readJSON(from: tempURL)
            importExport = export
            showImportSheet = true
        } catch {
            print("Import error:", error)
        }
    }

    private func copyToTemporaryIfNeeded(_ url: URL) throws -> URL {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
        let targetURL = tempDir.appendingPathComponent(url.lastPathComponent)

        if fm.fileExists(atPath: targetURL.path) {
            try fm.removeItem(at: targetURL)
        }

        try fm.copyItem(at: url, to: targetURL)
        return targetURL
    }
}
