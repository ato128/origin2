//
//  NotificationIconRenderer.swift
//  DailyTodo
//
//  Renders the *currently selected* Updo app icon into a PNG and exposes it as a
//  notification attachment, so every Updo notification visually carries the icon
//  the user picked. iOS always shows the primary app icon in the banner chrome,
//  so we attach the chosen mark as rich media instead.
//
//  The mark is drawn from `UpdoLogoMark` + `UpdoIconTheme.current()` (the same
//  source the launch screen uses), guaranteeing the notification always matches
//  the live alternate-icon selection — no per-icon image assets required.
//

import SwiftUI
import UserNotifications

@MainActor
enum NotificationIconRenderer {

    /// Master PNG is cached per selected icon; each attachment gets its own copy
    /// because the notification system takes ownership of the attachment file.
    private static var cachedIconKey: String?
    private static var cachedMasterURL: URL?

    /// A fresh attachment pointing at the current icon, or nil if rendering fails.
    static func makeIconAttachment() -> UNNotificationAttachment? {
        guard let master = masterIconURL() else { return nil }

        let unique = FileManager.default.temporaryDirectory
            .appendingPathComponent("updo-noti-\(UUID().uuidString).png")

        do {
            try FileManager.default.copyItem(at: master, to: unique)
            return try UNNotificationAttachment(
                identifier: "updo-icon",
                url: unique,
                options: [UNNotificationAttachmentOptionsThumbnailHiddenKey: false]
            )
        } catch {
            Log.debug("NOTI ICON ATTACH ERROR:", error.localizedDescription)
            return nil
        }
    }

    /// Call when the user switches app icon so the next notification re-renders.
    static func invalidateCache() {
        cachedIconKey = nil
        cachedMasterURL = nil
    }

    // MARK: - Rendering

    private static func masterIconURL() -> URL? {
        let key = UIApplication.shared.alternateIconName ?? "default"

        if key == cachedIconKey,
           let url = cachedMasterURL,
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        guard let data = renderIconPNG() else { return nil }

        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("updo-noti-icon-\(key).png")

        do {
            try data.write(to: url, options: .atomic)
            cachedIconKey = key
            cachedMasterURL = url
            return url
        } catch {
            Log.debug("NOTI ICON WRITE ERROR:", error.localizedDescription)
            return nil
        }
    }

    private static func renderIconPNG() -> Data? {
        let theme = UpdoIconTheme.current()
        let side: CGFloat = 180

        // `animated: false` renders the mark fully drawn (the animated path starts
        // collapsed, which would render empty in an offscreen snapshot).
        let content = ZStack {
            RoundedRectangle(cornerRadius: side * 0.225, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(arenaHex: "#0C1224"), Color(arenaHex: "#05070F")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: side * 0.225, style: .continuous)
                        .stroke(theme.glow.opacity(0.25), lineWidth: 1.5)
                )

            UpdoLogoMark(fg: theme.fg, glow: theme.glow, size: side * 0.6, animated: false)
        }
        .frame(width: side, height: side)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 3

        guard let image = renderer.uiImage else {
            Log.debug("NOTI ICON RENDER: nil image")
            return nil
        }

        return image.pngData()
    }
}
