//
//  NotificationService.swift
//  NotificationService
//
//  Gelen chat push'unu WhatsApp tarzı "communication notification"a çevirir:
//  gönderenin/crew'in fotoğrafı + köşede uygulama ikonu. Avatarı backend'den
//  (GET /v1/avatar/:id) çeker; token'ı uygulama App Group üzerinden paylaşır.
//

import UserNotifications
import Intents
import UIKit

final class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    private let appGroupID = "group.com.atakan.updo"
    private let tokenKey = "updo_shared_access_token_v1"
    private let baseURL = "https://updo-chat-backend-production.up.railway.app"

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        guard let content = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        let info = request.content.userInfo
        guard let avatarID = info["avatar_id"] as? String, !avatarID.isEmpty else {
            contentHandler(content)
            return
        }

        Task {
            let image = await fetchAvatar(id: avatarID)
            let updated = await makeCommunicationContent(
                content,
                senderName: content.title,
                image: image
            )
            contentHandler(updated)
        }
    }

    private func fetchAvatar(id: String) async -> UIImage? {
        // 1) App Group cache: uygulama avatarı gösterdiğinde buraya yazar.
        //    Token/ağ gerektirmez → app uzun süre kapalı olsa da hep çalışır.
        if let cached = cachedAvatar(id: id) {
            return cached
        }
        // 2) Ağ fallback (token taze ise): nadir cache-miss için.
        return await networkAvatar(id: id)
    }

    private func cachedAvatar(id: String) -> UIImage? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return nil }

        let url = container
            .appendingPathComponent("RemoteAvatars", isDirectory: true)
            .appendingPathComponent("avatar-\(id.lowercased()).jpg")

        return UIImage(contentsOfFile: url.path)
    }

    private func networkAvatar(id: String) async -> UIImage? {
        guard let url = URL(string: "\(baseURL)/v1/avatar/\(id)") else { return nil }

        var request = URLRequest(url: url)
        if let token = UserDefaults(suiteName: appGroupID)?.string(forKey: tokenKey),
           !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 8

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let image = UIImage(data: data) else { return nil }

        return image
    }

    private func makeCommunicationContent(
        _ content: UNMutableNotificationContent,
        senderName: String,
        image: UIImage?
    ) async -> UNNotificationContent {
        var inImage: INImage?
        if let image, let data = image.jpegData(compressionQuality: 0.9) {
            inImage = INImage(imageData: data)
        }

        let handle = INPersonHandle(value: "updo-\(UUID().uuidString)", type: .unknown)
        let sender = INPerson(
            personHandle: handle,
            nameComponents: nil,
            displayName: senderName,
            image: inImage,
            contactIdentifier: nil,
            customIdentifier: nil
        )

        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: content.body,
            speakableGroupName: nil,
            conversationIdentifier: content.threadIdentifier.isEmpty ? nil : content.threadIdentifier,
            serviceName: nil,
            sender: sender,
            attachments: nil
        )
        intent.setImage(inImage, forParameterNamed: \.sender)

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming
        try? await interaction.donate()

        if let updated = try? content.updating(from: intent) {
            return updated
        }
        return content
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler, let bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
