//
//  BYOKeyStore.swift
//  DailyTodo
//
//  "Kendi ChatGPT'in": kullanıcının OpenAI API anahtarı. Keychain'de tutulur,
//  YALNIZCA istek anında backend'e header ile taşınır — backend saklamaz.
//  Anahtar varken Updo AI aynı kimlikle konuşur ama fatura kullanıcınındır;
//  bizim kota/kredi sayaçları hiç dokunulmaz.
//

import Foundation
import Security
import Combine
import SwiftUI

@MainActor
final class BYOKeyStore: ObservableObject {
    static let shared = BYOKeyStore()

    @Published private(set) var hasKey: Bool = false

    private let service = "com.atakan.updo.byo-openai"
    private let account = "openai_api_key"

    private init() {
        hasKey = readKey() != nil
    }

    /// Maskelenmiş görünüm ("sk-…AB12") — anahtarın tamamı asla UI'da gösterilmez.
    var maskedKey: String? {
        guard let key = readKey(), key.count > 8 else { return nil }
        return "sk-…\(key.suffix(4))"
    }

    func readKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else { return nil }

        return key
    }

    @discardableResult
    func save(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("sk-"), trimmed.count > 20,
              let data = trimmed.data(using: .utf8)
        else { return false }

        remove()

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        hasKey = status == errSecSuccess
        return hasKey
    }

    func remove() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        hasKey = false
    }
}

// MARK: - Ayar sheet'i ("Kendi ChatGPT'in")

struct BYOKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = BYOKeyStore.shared

    @State private var keyInput = ""
    @State private var checkState: KeyCheckState = .idle

    private enum KeyCheckState: Equatable {
        case idle
        case checking
        case invalidFormat
        case rejected      // OpenAI 401 — anahtar geçersiz
        case noFunds       // anahtar doğru ama hesapta bakiye yok
    }

    private var cyan: Color { Color(arenaHex: "#2DD4FF") }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(arenaHex: "#07090F").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(cyan.opacity(0.14)).frame(width: 46, height: 46)
                                Image(systemName: "key.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(cyan)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(tr("byo_title"))
                                    .font(.system(size: 19, weight: .black))
                                    .foregroundStyle(.white)
                                Text(tr("byo_sub"))
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }

                        Text(tr("byo_explain"))
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineSpacing(3)

                        if store.hasKey {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color(arenaHex: "#34D44A"))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tr("byo_active"))
                                        .font(.system(size: 14, weight: .black))
                                        .foregroundStyle(.white)
                                    if let masked = store.maskedKey {
                                        Text(masked)
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.white.opacity(0.45))
                                    }
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(arenaHex: "#34D44A").opacity(0.09))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(Color(arenaHex: "#34D44A").opacity(0.25), lineWidth: 1)
                                    )
                            )

                            Button {
                                store.remove()
                                HapticManager.shared.navigation()
                            } label: {
                                Text(tr("byo_remove"))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(arenaHex: "#FF5A44"))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 46)
                                    .background(
                                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                                            .fill(Color(arenaHex: "#FF5A44").opacity(0.10))
                                    )
                            }
                            .buttonStyle(.plain)
                        } else {
                            stepGuide

                            HStack(spacing: 8) {
                                SecureField("sk-...", text: $keyInput)
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(.horizontal, 15)
                                    .frame(height: 50)
                                    .background(
                                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                                            .fill(Color.white.opacity(0.05))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                                    .strokeBorder(fieldBorderColor, lineWidth: 1)
                                            )
                                    )

                                // Panoda anahtar varsa tek dokunuşla al (pano
                                // yalnızca butona basınca okunur — iOS izni).
                                Button {
                                    if let pasted = UIPasteboard.general.string?
                                        .trimmingCharacters(in: .whitespacesAndNewlines),
                                       pasted.hasPrefix("sk-") {
                                        keyInput = pasted
                                        checkState = .idle
                                        HapticManager.shared.navigation()
                                    } else {
                                        checkState = .invalidFormat
                                    }
                                } label: {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(cyan)
                                        .frame(width: 50, height: 50)
                                        .background(
                                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                                .fill(cyan.opacity(0.10))
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(tr("byo_paste"))
                            }

                            if let statusText {
                                Text(statusText)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(checkState == .noFunds
                                                     ? Color(arenaHex: "#FBBF24")
                                                     : Color(arenaHex: "#FF5A44"))
                            }

                            if checkState == .noFunds,
                               let billing = URL(string: "https://platform.openai.com/settings/organization/billing/overview") {
                                Link(destination: billing) {
                                    Text(tr("byo_billing_cta"))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color(arenaHex: "#FBBF24"))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 42)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color(arenaHex: "#FBBF24").opacity(0.12))
                                        )
                                }
                            }

                            Button {
                                Task { await validateAndSave() }
                            } label: {
                                Group {
                                    if checkState == .checking {
                                        ProgressView().tint(.black)
                                    } else {
                                        Text(tr("byo_save"))
                                            .font(.system(size: 15, weight: .black))
                                    }
                                }
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .fill(cyan)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(checkState == .checking)

                            Text(tr("byo_privacy"))
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.4))
                                .lineSpacing(2)
                        }

                        Spacer(minLength: 12)
                    }
                    .padding(20)
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("common_done")) { dismiss() }
                        .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Pieces

    private var fieldBorderColor: Color {
        switch checkState {
        case .invalidFormat, .rejected: return Color(arenaHex: "#FF5A44").opacity(0.6)
        case .noFunds: return Color(arenaHex: "#FBBF24").opacity(0.6)
        default: return Color.white.opacity(0.09)
        }
    }

    private var statusText: String? {
        switch checkState {
        case .invalidFormat: return tr("byo_invalid_format")
        case .rejected: return tr("ai_byo_invalid")
        case .noFunds: return tr("byo_no_funds")
        default: return nil
        }
    }

    private var stepGuide: some View {
        VStack(alignment: .leading, spacing: 9) {
            stepRow(1, tr("byo_step_1"))
            stepRow(2, tr("byo_step_2"))
            stepRow(3, tr("byo_step_3"))

            if let url = URL(string: "https://platform.openai.com/api-keys") {
                Link(destination: url) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 12, weight: .bold))
                        Text("platform.openai.com/api-keys")
                            .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(cyan)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }

    private func stepRow(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\(number)")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .frame(width: 18, height: 18)
                .background(Circle().fill(cyan))

            Text(text)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Kaydetmeden önce anahtarı 1 token'lık minik bir çağrıyla dener.
    /// 200 → kaydet-kapat; 401 → geçersiz; insufficient_quota → anahtar doğru
    /// ama bakiye yok (yine de kaydedilir, kullanıcı yükleme linkini görür).
    private func validateAndSave() async {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("sk-"), trimmed.count > 20 else {
            checkState = .invalidFormat
            return
        }

        checkState = .checking

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 20
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": "gpt-4o-mini",
            "max_tokens": 1,
            "messages": [["role": "user", "content": "hi"]]
        ])

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let bodyText = String(data: data, encoding: .utf8) ?? ""

            if status == 401 || status == 403 {
                checkState = .rejected
                return
            }

            if status == 429, bodyText.contains("insufficient_quota") || bodyText.contains("billing") {
                // Anahtar geçerli — bakiye yok. Kaydet ki yükleme sonrası çalışsın.
                BYOKeyStore.shared.save(trimmed)
                checkState = .noFunds
                return
            }

            // 200 (ya da geçici başka bir durum) — anahtar çalışıyor, kaydet.
            BYOKeyStore.shared.save(trimmed)
            keyInput = ""
            checkState = .idle
            HapticManager.shared.success()
            dismiss()
        } catch {
            // Ağ hatasında engelleme: kaydet, gerçek doğrulama ilk mesajda olur.
            BYOKeyStore.shared.save(trimmed)
            keyInput = ""
            checkState = .idle
            dismiss()
        }
    }
}
