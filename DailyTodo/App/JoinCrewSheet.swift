//
//  JoinCrewSheet.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import SwiftUI
import UIKit

struct JoinCrewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore

    @State var code: String
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var cleanCode: String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var canJoin: Bool {
        !cleanCode.isEmpty && !isLoading
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        heroCard
                        codeInputSection
                        helpCard

                        if let errorMessage {
                            errorCard(errorMessage)
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Join Crew")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await joinCrew()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Join")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canJoin)
                }
            }
        }
    }
}

private extension JoinCrewSheet {

    var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.green.opacity(0.24),
                                    Color.blue.opacity(0.16)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 74, height: 74)

                    Image(systemName: "person.3.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Join a Crew")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Enter the invite code shared by your team.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                }

                Spacer()
            }

            HStack(spacing: 10) {
                pill(text: "Invite Code", tint: .green)
                if !cleanCode.isEmpty {
                    pill(text: cleanCode, tint: .white.opacity(0.75))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    var codeInputSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Invite Code")
                .font(.title3.bold())
                .foregroundStyle(.white)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter code")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.64))

                    TextField("ABC123", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .onChange(of: code) { _, newValue in
                            let filtered = newValue
                                .uppercased()
                                .filter { $0.isLetter || $0.isNumber }

                            if filtered != newValue {
                                code = filtered
                            }
                        }
                }
                .padding(16)

                Divider()
                    .overlay(Color.white.opacity(0.08))

                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = cleanCode
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.doc")
                            Text("Copy")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.06))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(cleanCode.isEmpty)

                    Button {
                        if let pasted = UIPasteboard.general.string {
                            code = pasted
                                .uppercased()
                                .filter { $0.isLetter || $0.isNumber }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.doc")
                            Text("Paste")
                        }
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.16))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .background(sectionCardBackground)
        }
    }

    var helpCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How it works")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Ask a crew member for their invite code, paste it here, then tap Join.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(sectionCardBackground)
    }

    func errorCard(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.red)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.red.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.red.opacity(0.20), lineWidth: 1)
                    )
            )
    }

    func pill(text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.14))
            )
            .foregroundStyle(tint)
    }

    var sectionCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
    }

    @MainActor
    func joinCrew() async {
        guard !cleanCode.isEmpty else { return }
        guard let user = session.currentUser else {
            errorMessage = "User session not found."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await crewStore.joinCrew(with: cleanCode, userID: user.id)
            await crewStore.loadCrews(force: true)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
