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

    // ✅ Import state
    @State private var importExport: ScheduleExport? = nil
    @State private var showImportSheet: Bool = false

    var body: some View {

        if !didFinishOnboarding {

            OnboardingView()

        } else if !didFinishPermissionOnboarding {

            PermissionOnboardingView()

        } else {

            MainTabView()
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
    

    // MARK: - Import Handler

    private func handleIncomingFileURL(_ url: URL) {
        guard url.isFileURL else { return }

        // iOS'ta Dosyalar / Paylaşım ile gelen URL bazen security-scoped olur.
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            // Bazı durumlarda direkt okumak yerine temp'e kopyalayınca kesin çalışıyor.
            let tempURL = try copyToTemporaryIfNeeded(url)

            let export = try ScheduleShare.readJSON(from: tempURL)
            importExport = export
            showImportSheet = true
        } catch {
            print("Import error:", error)
        }
    }

    private func copyToTemporaryIfNeeded(_ url: URL) throws -> URL {
        // Aynı URL uygulama sandbox’ında ise kopyalamaya gerek yok.
        // Ama dışarıdan gelenlerde temp’e kopyalamak daha stabil.
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
        let targetURL = tempDir.appendingPathComponent(url.lastPathComponent)

        // Aynı isimde varsa sil
        if fm.fileExists(atPath: targetURL.path) {
            try fm.removeItem(at: targetURL)
        }

        try fm.copyItem(at: url, to: targetURL)
        return targetURL
    }
}
