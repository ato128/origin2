//
//  RootView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("didFinishOnboarding") private var didFinishOnboarding = false
    @AppStorage("didFinishPermissionOnboarding") private var didFinishPermissionOnboarding = false

    @StateObject private var guide = AppGuideManager()

    @State private var importExport: ScheduleExport? = nil
    @State private var showImportSheet: Bool = false

    var body: some View {
        if !didFinishOnboarding {
            OnboardingView()

        } else if !didFinishPermissionOnboarding {
            PermissionOnboardingView()

        } else {
            MainTabView()
                .environmentObject(guide)
                .onAppear {
                    guide.forceStart()
                }
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
