//
//  ProfileAvatarStore.swift
//  DailyTodo
//
//  Profile photo with our own backend as the source of truth. The local JPEG
//  in Application Support is an offline cache for instant rendering; every
//  save/remove is mirrored to PUT/DELETE /v1/avatar, and load() pulls the
//  backend copy once per user per session (new device → photo comes back).
//

import SwiftUI
import UIKit
import Combine

@MainActor
final class ProfileAvatarStore: ObservableObject {
    static let shared = ProfileAvatarStore()

    @Published private(set) var image: UIImage?

    private var loadedUserID: String?
    private var backendSyncedUserID: String?

    private init() {}

    func load(for userID: String?) {
        guard let userID, !userID.isEmpty else {
            image = nil
            loadedUserID = nil
            return
        }

        if loadedUserID != userID || image == nil {
            loadedUserID = userID
            image = UIImage(contentsOfFile: fileURL(for: userID).path)
        }

        syncFromBackendIfNeeded(userID: userID)
    }

    /// Pulls the backend avatar once per user per session — covers fresh
    /// installs / new devices and edits made elsewhere.
    private func syncFromBackendIfNeeded(userID: String) {
        guard backendSyncedUserID != userID else { return }
        backendSyncedUserID = userID

        Task { [weak self] in
            guard let self else { return }
            guard let data = await AvatarBackendClient.shared.fetch(userID: userID) else { return }
            guard let fetched = UIImage(data: data) else { return }

            try? self.ensureDirectory()
            try? data.write(to: self.fileURL(for: userID), options: .atomic)

            if self.loadedUserID == userID {
                self.image = fetched
            }
        }
    }

    func save(_ newImage: UIImage, for userID: String?) {
        guard let userID, !userID.isEmpty else { return }

        let resized = newImage.avatarResized(maxDimension: 512)
        guard let data = resized.jpegData(compressionQuality: 0.85) else { return }

        do {
            try ensureDirectory()
            try data.write(to: fileURL(for: userID), options: .atomic)
            loadedUserID = userID
            image = resized
        } catch {
            Log.debug("AVATAR SAVE ERROR:", error.localizedDescription)
        }

        RemoteAvatarStore.shared.overrideLocal(resized, for: UUID(uuidString: userID))

        // Mirror to the backend — local copy already renders, so a failed
        // upload just retries on the next save.
        Task {
            await AvatarBackendClient.shared.upload(jpegData: data)
        }
    }

    func remove(for userID: String?) {
        guard let userID, !userID.isEmpty else { return }
        try? FileManager.default.removeItem(at: fileURL(for: userID))
        if loadedUserID == userID { image = nil }

        RemoteAvatarStore.shared.overrideLocal(nil, for: UUID(uuidString: userID))

        Task {
            await AvatarBackendClient.shared.remove()
        }
    }

    // MARK: - Files

    private func directoryURL() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return base.appendingPathComponent("ProfileAvatars", isDirectory: true)
    }

    private func fileURL(for userID: String) -> URL {
        directoryURL().appendingPathComponent("avatar-\(userID).jpg")
    }

    private func ensureDirectory() throws {
        try FileManager.default.createDirectory(
            at: directoryURL(),
            withIntermediateDirectories: true
        )
    }
}

private extension UIImage {
    /// Square center-crop + downscale so stored avatars stay small and render
    /// crisp inside circular frames.
    func avatarResized(maxDimension: CGFloat) -> UIImage {
        let side = min(size.width, size.height)
        let cropRect = CGRect(
            x: (size.width - side) / 2,
            y: (size.height - side) / 2,
            width: side,
            height: side
        )

        let scaleFactor = min(1, maxDimension / side)
        let target = CGSize(width: side * scaleFactor, height: side * scaleFactor)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1

        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            let drawRect = CGRect(
                x: -cropRect.minX * scaleFactor,
                y: -cropRect.minY * scaleFactor,
                width: size.width * scaleFactor,
                height: size.height * scaleFactor
            )
            draw(in: drawRect)
        }
    }
}
