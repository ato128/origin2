//
//  CrewChatView+Header.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 16.03.2026.
//

import SwiftUI

extension CrewChatView {

    // Birebir Updo AI chat arka planı.
    var ambientBackground: some View {
        ArenaBackground(
            primaryGlow: Color(arenaHex: "#7C3AED"),
            secondaryGlow: Color(arenaHex: "#2DD4FF"),
            warmGlow: Color(arenaHex: "#FF5A44")
        )
        .ignoresSafeArea()
    }

    var floatingTopControls: some View {
        ZStack(alignment: .top) {
            crewChatHeaderScrim
                .allowsHitTesting(false)

            HStack(alignment: .center, spacing: 10) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left").accessibilityLabel(tr("a11y_back"))
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(crewChatCircleBackground)
                }
                .buttonStyle(.plain)

                Button {
                    showCrewInfo = true
                } label: {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        hexColor(crew.colorHex).opacity(0.92),
                                        Color(arenaHex: "#7C3AED").opacity(0.78),
                                        Color(arenaHex: "#FF5A44").opacity(0.52)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: crew.icon)
                                    .font(.system(size: 17, weight: .black))
                                    .foregroundStyle(.white)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(crew.name)
                                .font(.system(size: 15, weight: .black))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            HStack(spacing: 6) {
                                Circle()
                                    .fill(activeFocusSession != nil ? Color(arenaHex: "#A3E635") : Color(arenaHex: "#2DD4FF"))
                                    .frame(width: 6, height: 6)

                                Text(activeFocusSession != nil ? "Live focus" : "Crew chat")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.58))
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 8)
                    .padding(.trailing, 12)
                    .frame(height: 46)
                    .background(crewChatCapsuleBackground)
                }
                .buttonStyle(.plain)

                Button {
                    showCrewInfo = true
                } label: {
                    Image(systemName: "ellipsis").accessibilityLabel(tr("a11y_more"))
                        .font(.system(size: 19, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(crewChatCircleBackground)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }
    
    var crewChatHeaderScrim: some View {
        // Hafif fade: header elemanları kendi material'ini taşıyor,
        // mesajlar arkalarından akıyor — ağır siyah blok yok (iMessage hissi).
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.42), location: 0.00),
                    .init(color: Color.black.opacity(0.18), location: 0.55),
                    .init(color: Color.clear, location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 110)

            Spacer(minLength: 0)
        }
    }

    func typingBanner(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "ellipsis.message.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color(arenaHex: "#A3E635"))

            Text(text)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(arenaHex: "#A3E635").opacity(0.075),
                            Color(arenaHex: "#1593FF").opacity(0.050),
                            Color.white.opacity(0.045)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 6)
        )
        .padding(.horizontal, 16)
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            hexColor(crew.colorHex).opacity(0.95),
                            Color(arenaHex: "#7C3AED").opacity(0.82),
                            Color(arenaHex: "#FF5A44").opacity(0.58)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 78, height: 78)
                .overlay(
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.white)
                )
                .shadow(color: hexColor(crew.colorHex).opacity(0.18), radius: 18, y: 8)

            VStack(spacing: 7) {
                Text("crew_chat_empty_title")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)

                Text("crew_chat_empty_subtitle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 26)
        .padding(.top, 80)
    }

    // Birebir Updo AI floating cam-daire.
    var crewChatCircleBackground: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(Circle().strokeBorder(UpdoTheme.border, lineWidth: 1))
    }

    // Birebir Updo AI floating cam-pill.
    var crewChatCapsuleBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(Capsule().strokeBorder(UpdoTheme.border, lineWidth: 1))
    }
}

// MARK: - Color Hex
