//
//  InAppBannerCenter.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.04.2026.
//

import SwiftUI
import UIKit
import Combine

@MainActor
final class InAppBannerCenter: ObservableObject {
    static let shared = InAppBannerCenter()

    @Published var banner: InAppBannerItem?

    private var dismissTask: DispatchWorkItem?

    private init() { }

    func show(
        title: String,
        message: String,
        payload: [AnyHashable: Any],
        duration: TimeInterval = 3.2
    ) {
        dismissTask?.cancel()

        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            banner = InAppBannerItem(
                title: title,
                message: message,
                payload: payload
            )
        }

        let task = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: 0.30, dampingFraction: 0.90)) {
                self.banner = nil
            }
        }

        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    }

    func hide() {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.90)) {
            banner = nil
        }
    }

    func handleTap() {
        guard let payload = banner?.payload else {
            hide()
            return
        }

        hide()

        if let type = payload["type"] as? String {
            switch type {
            case "friend_chat":
                if let friendshipID = payload["friendship_id"] as? String {
                    NotificationCenter.default.post(
                        name: .openFriendChatFromNotification,
                        object: friendshipID
                    )
                }

            case "crew_chat":
                if let crewID = payload["crew_id"] as? String {
                    NotificationCenter.default.post(
                        name: .openCrewChatFromNotification,
                        object: crewID
                    )
                }

            case "focus_room":
                if let crewID = payload["crew_id"] as? String {
                    NotificationCenter.default.post(
                        name: .openCrewFocusFromNotification,
                        object: crewID
                    )
                }

            default:
                break
            }
        }

        if let deepLink = payload["deep_link"] as? String,
           let url = URL(string: deepLink) {
            NotificationCenter.default.post(
                name: .openURLFromNotification,
                object: url
            )
        }
    }
}

struct InAppBannerItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let payload: [AnyHashable: Any]
}

struct InAppBannerOverlay: View {
    @ObservedObject var center = InAppBannerCenter.shared

    var body: some View {
        ZStack(alignment: .top) {
            if let banner = center.banner {
                PremiumInAppBannerCard(
                    title: banner.title,
                    message: banner.message,
                    onTap: {
                        center.handleTap()
                    },
                    onClose: {
                        center.hide()
                    }
                )
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    )
                )
                .zIndex(999)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(center.banner != nil)
        .animation(.spring(response: 0.34, dampingFraction: 0.88), value: center.banner?.id)
    }
}

private struct PremiumInAppBannerCard: View {
    let title: String
    let message: String
    let onTap: () -> Void
    let onClose: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)

                    Image(systemName: "message.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.82))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.34),
                                    Color.blue.opacity(0.10),
                                    Color.purple.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.20), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }
}
