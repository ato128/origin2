//
//  UserAvatarView.swift
//  DailyTodo
//
//  Renders any user's profile photo (own backend, GET /v1/avatar/:userID)
//  with an Updo-style initials fallback. RemoteAvatarStore keeps a memory +
//  disk cache and fetches each user at most once per session, so lists and
//  chat bubbles can drop this in without request storms.
//

import SwiftUI
import UIKit
import Combine

@MainActor
final class RemoteAvatarStore: ObservableObject {
    static let shared = RemoteAvatarStore()

    @Published private(set) var imagesByUserID: [String: UIImage] = [:]

    /// Users we already asked the backend about this session (hit or 404).
    private var fetchedThisSession: Set<String> = []

    private init() {}

    func image(for userID: UUID?) -> UIImage? {
        guard let userID else { return nil }
        return imagesByUserID[cacheKey(userID)]
    }

    /// Loads the disk copy immediately and refreshes from the backend once
    /// per user per session. Safe to call from onAppear of every row.
    func ensure(_ userID: UUID?) {
        guard let userID else { return }
        let key = cacheKey(userID)

        if imagesByUserID[key] == nil,
           let cached = UIImage(contentsOfFile: fileURL(for: key).path) {
            imagesByUserID[key] = cached
        }

        guard !fetchedThisSession.contains(key) else { return }
        fetchedThisSession.insert(key)

        Task { [weak self] in
            guard let data = await AvatarBackendClient.shared.fetch(userID: userID.uuidString),
                  let fetched = UIImage(data: data)
            else { return }

            guard let self else { return }
            try? self.ensureDirectory()
            try? data.write(to: self.fileURL(for: key), options: .atomic)
            self.imagesByUserID[key] = fetched
        }
    }

    /// Keeps other-surface renders of MY avatar in sync right after the user
    /// edits their photo (ProfileAvatarStore calls this on save/remove).
    func overrideLocal(_ image: UIImage?, for userID: UUID?) {
        guard let userID else { return }
        let key = cacheKey(userID)

        if let image {
            imagesByUserID[key] = image
        } else {
            imagesByUserID.removeValue(forKey: key)
            try? FileManager.default.removeItem(at: fileURL(for: key))
        }
    }

    // MARK: - Cache files

    private func cacheKey(_ userID: UUID) -> String {
        userID.uuidString.lowercased()
    }

    private func directoryURL() -> URL {
        let base = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0]
        return base.appendingPathComponent("RemoteAvatars", isDirectory: true)
    }

    private func fileURL(for key: String) -> URL {
        directoryURL().appendingPathComponent("avatar-\(key).jpg")
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: directoryURL(),
            withIntermediateDirectories: true
        )
    }
}

/// Circular user avatar: real photo when available, Updo initials otherwise.
struct UserAvatarView: View {
    let userID: UUID?
    let name: String
    var tint: Color = Color(arenaHex: AppArenaPalette.cyan)
    var size: CGFloat = 42

    @ObservedObject private var store = RemoteAvatarStore.shared

    private var initials: String {
        let parts = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }

        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        } else if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }

    var body: some View {
        ZStack {
            if let image = store.image(for: userID) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                    )
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.24),
                                Color(arenaHex: AppArenaPalette.purple).opacity(0.15),
                                Color.white.opacity(0.040)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(tint.opacity(0.26), lineWidth: 1.1)
                    )

                Text(initials)
                    .font(.system(size: size * 0.30, weight: .black))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .onAppear { store.ensure(userID) }
    }
}
