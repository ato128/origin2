//
//  ChatMessageActionsPopover.swift
//  DailyTodo
//
//  iMessage tarzı uzun-basma menüsü: yüzen emoji tapback çubuğu + Yanıtla/Kopyala.
//  Friend ve crew sohbeti ortak kullanır (.popover ile baloncuğa çıpalanır).
//

import SwiftUI

enum ChatTapback {
    /// iMessage tapback seti.
    static let emojis = ["❤️", "👍", "👎", "😂", "‼️", "❓"]
}

/// Kaydır-yanıtla: kendi mesajını (isFromMe) SOLA, karşı mesajı SAĞA sürükleyince
/// eşik geçilince yanıt tetiklenir. ScrollView dikey kaydırmasıyla çakışmaması için
/// yalnız yatay-ağırlıklı ve doğru yöndeki sürüklemede devreye girer.
struct SwipeToReplyModifier: ViewModifier {
    let isFromMe: Bool
    let onReply: () -> Void

    @State private var offsetX: CGFloat = 0
    @State private var didHaptic = false

    func body(content: Content) -> some View {
        content
            .offset(x: offsetX)
            .overlay(alignment: isFromMe ? .trailing : .leading) {
                Image(systemName: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .opacity(Double(min(abs(offsetX) / 50, 1)))
                    .offset(x: isFromMe ? 34 : -34)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        guard abs(dx) > abs(dy) else { return }

                        if isFromMe {
                            guard dx < 0 else { return }
                            offsetX = max(dx, -70)
                        } else {
                            guard dx > 0 else { return }
                            offsetX = min(dx, 70)
                        }

                        if abs(offsetX) > 50 && !didHaptic {
                            didHaptic = true
                            Haptics.impact(.light)
                        }
                    }
                    .onEnded { _ in
                        if abs(offsetX) > 50 { onReply() }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            offsetX = 0
                        }
                        didHaptic = false
                    }
            )
    }
}

extension View {
    /// Kendi mesajı sola, karşı mesaj sağa kaydırılınca `onReply` tetikler.
    func swipeToReply(isFromMe: Bool, _ onReply: @escaping () -> Void) -> some View {
        modifier(SwipeToReplyModifier(isFromMe: isFromMe, onReply: onReply))
    }
}

/// İyimser (optimistic) reaksiyon güncellemesi: kullanıcının mevcut tapback'ini
/// kaldırıp yenisini (varsa) ekler; backend cevabı gelene kadar anında gösterir.
func chatOptimisticReactions(
    _ current: [ChatReactionSummary],
    newEmoji: String?
) -> [ChatReactionSummary] {
    var counts: [String: (count: Int, mine: Bool)] = [:]
    for r in current { counts[r.emoji] = (r.count, r.mine) }

    if let mineEmoji = current.first(where: { $0.mine })?.emoji,
       var entry = counts[mineEmoji] {
        entry.count -= 1
        entry.mine = false
        if entry.count <= 0 { counts[mineEmoji] = nil } else { counts[mineEmoji] = entry }
    }

    if let newEmoji {
        var entry = counts[newEmoji] ?? (count: 0, mine: false)
        entry.count += 1
        entry.mine = true
        counts[newEmoji] = entry
    }

    return counts
        .map { ChatReactionSummary(emoji: $0.key, count: $0.value.count, mine: $0.value.mine) }
        .sorted { $0.count > $1.count }
}

/// Uzun-basma sonrası baloncuğa çıpalanan yüzen menü.
struct ChatMessageActionsPopover: View {
    /// Kullanıcının mevcut reaksiyonu (varsa) — seçili emojiyi vurgular.
    let myReaction: String?
    let canCopy: Bool
    let onPick: (String) -> Void
    let onReply: () -> Void
    let onCopy: () -> Void
    /// Opsiyonel ek aksiyon (ör. friend'de "Fotoğrafı kaydet").
    var extraActionTitle: String? = nil
    var extraActionIcon: String? = nil
    var onExtra: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Emoji tapback çubuğu (WhatsApp gibi: eşit yayılır, yandan kesilmez)
            HStack(spacing: 0) {
                ForEach(ChatTapback.emojis, id: \.self) { emoji in
                    Button {
                        onPick(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 26))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(alignment: .center) {
                                Circle()
                                    .fill(myReaction == emoji ? UpdoTheme.cyan.opacity(0.35) : Color.clear)
                                    .frame(width: 40, height: 40)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            Divider().overlay(Color.white.opacity(0.12))

            // Aksiyonlar
            actionRow(tr("chat_action_reply"), icon: "arrowshape.turn.up.left", action: onReply)

            if canCopy {
                Divider().overlay(Color.white.opacity(0.08))
                actionRow(tr("common_copy"), icon: "doc.on.doc", action: onCopy)
            }

            if let extraActionTitle, let extraActionIcon, let onExtra {
                Divider().overlay(Color.white.opacity(0.08))
                actionRow(extraActionTitle, icon: extraActionIcon, action: onExtra)
            }
        }
        .frame(width: 288)
        .background(Color(arenaHex: "#1C1C1E"))
        .presentationCompactAdaptation(.popover)
    }

    private func actionRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Baloncuğun köşesinde toplu reaksiyon rozetleri (❤️3). Boşsa hiçbir şey çizmez.
struct ChatReactionBadges: View {
    let reactions: [ChatReactionSummary]

    var body: some View {
        if !reactions.isEmpty {
            HStack(spacing: 4) {
                ForEach(reactions) { reaction in
                    HStack(spacing: 2) {
                        Text(reaction.emoji)
                            .font(.system(size: 12))

                        if reaction.count > 1 {
                            Text("\(reaction.count)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(reaction.mine ? UpdoTheme.bubbleSentTop : UpdoTheme.bubbleReceived)
                            .overlay(
                                Capsule().stroke(Color.black.opacity(0.35), lineWidth: 1.5)
                            )
                    )
                }
            }
        }
    }
}
