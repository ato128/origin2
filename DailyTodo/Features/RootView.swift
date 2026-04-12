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

    @AppStorage("didFinishOnboarding") private var didFinishOnboarding = false
    @AppStorage("didFinishPermissionOnboarding") private var didFinishPermissionOnboarding = false
    @AppStorage("didFinishIntroFlow") private var didFinishIntroFlow = false

    @State private var importExport: ScheduleExport? = nil
    @State private var showImportSheet: Bool = false

    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var friendStore: FriendStore

    var body: some View {
        Group {
            if !session.isSignedIn {
                AuthView()

            } else if !didFinishOnboarding {
                OnboardingView()

            } else if !didFinishPermissionOnboarding {
                PermissionOnboardingView()

            } else if !didFinishIntroFlow {
                IntroFlowView()

            } else {
                MainTabView(
                    openFocusFromNotification: $openFocusFromNotification
                )
                .onOpenURL { url in
                    handleIncomingFileURL(url)
                }
                .sheet(isPresented: $showImportSheet) {
                    if let export = importExport {
                        ImportScheduleView(export: export)
                    }
                }
            }
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
