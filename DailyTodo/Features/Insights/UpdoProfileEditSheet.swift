//
//  UpdoProfileEditSheet.swift
//  DailyTodo
//
//  The profile editor, moved out of Settings and rebuilt in the Updo idiom:
//  photo + name + username + school in one calm dark sheet. The photo is
//  device-local (ProfileAvatarStore); name/username persist to the profiles
//  table; school opens the existing academic settings flow.
//

import SwiftUI
import PhotosUI

struct UpdoProfileEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var studentStore: StudentStore

    @ObservedObject private var avatarStore = ProfileAvatarStore.shared

    @State private var fullName: String = ""
    @State private var username: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    @State private var photoSelection: PhotosPickerItem?
    @State private var showAcademicSettings = false

    private var accent: Color { Color(arenaHex: AppArenaPalette.cyan) }

    private var canSave: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSaving
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(arenaHex: "#07090F").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 26) {
                        avatarSection
                            .padding(.top, 18)

                        VStack(spacing: 12) {
                            fieldRow(
                                label: tr("pe_name_caps"),
                                text: $fullName,
                                capitalization: .words
                            )

                            fieldRow(
                                label: tr("pe_username_caps"),
                                text: $username,
                                capitalization: .never,
                                prefix: "@"
                            )
                        }

                        schoolRow

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(Color(arenaHex: "#FF5A44"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Spacer(minLength: 12)
                    }
                    .padding(.horizontal, 20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(tr("pe_title"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("common_cancel")) { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveProfile() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(accent)
                        } else {
                            Text(tr("pe_save"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(canSave ? accent : .white.opacity(0.3))
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showAcademicSettings) {
                StudentAcademicSettingsView()
                    .environmentObject(studentStore)
            }
            .onAppear {
                fullName = session.currentUser?.fullName ?? ""
                username = session.currentUser?.username ?? ""
                avatarStore.load(for: session.currentUser?.id.uuidString)
            }
            .onChange(of: photoSelection) { _, newItem in
                guard let newItem else { return }
                Task { await applyPickedPhoto(newItem) }
            }
        }
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $photoSelection, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    ProfileAvatarCircle(
                        image: avatarStore.image,
                        name: fullName.isEmpty ? (session.currentUser?.fullName ?? "") : fullName,
                        accent: accent,
                        size: 108
                    )

                    // Camera affordance — the whole circle is the tap target.
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(accent))
                        .overlay(Circle().stroke(Color(arenaHex: "#07090F"), lineWidth: 3))
                }
            }
            .buttonStyle(.plain)

            if avatarStore.image != nil {
                Button {
                    HapticManager.shared.navigation()
                    avatarStore.remove(for: session.currentUser?.id.uuidString)
                    photoSelection = nil
                } label: {
                    Text(tr("pe_photo_remove"))
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            } else {
                Text(tr("pe_photo_hint"))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    // MARK: - Fields

    private func fieldRow(
        label: String,
        text: Binding<String>,
        capitalization: TextInputAutocapitalization,
        prefix: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.38))

            HStack(spacing: 6) {
                if let prefix {
                    Text(prefix)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                }

                TextField("", text: text)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled()
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .tint(accent)
            }
            .padding(.horizontal, 15)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - School

    private var schoolRow: some View {
        Button {
            HapticManager.shared.navigation()
            showAcademicSettings = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(accent.opacity(0.12)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("pe_school_caps"))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.38))

                    Text(ProfileSchoolLine.text(for: studentStore.profile) ?? tr("pe_school_empty"))
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 15)
            .frame(height: 62)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func applyPickedPhoto(_ item: PhotosPickerItem) async {
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let uiImage = UIImage(data: data)
        else { return }

        avatarStore.save(uiImage, for: session.currentUser?.id.uuidString)
        HapticManager.shared.success()
    }

    @MainActor
    private func saveProfile() async {
        isSaving = true
        errorMessage = nil

        do {
            try await session.updateProfile(fullName: fullName, username: username)
            HapticManager.shared.success()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}

// MARK: - Shared avatar circle (photo or serif monogram)

struct ProfileAvatarCircle: View {
    let image: UIImage?
    let name: String
    let accent: Color
    let size: CGFloat

    private var initials: String {
        let parts = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
        let joined = parts.joined()
        return joined.isEmpty ? "U" : joined.uppercased()
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.white.opacity(0.055))
                    .frame(width: size, height: size)

                Text(initials)
                    .font(.system(size: size * 0.34, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.55)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
    }
}

// MARK: - School line (shared by hero, editor and share card)

enum ProfileSchoolLine {
    /// "Doğu Akdeniz Üniversitesi · Bilgisayar Müh." for university,
    /// "Lise · 11. Sınıf" for high school; nil when nothing is set up.
    static func text(for profile: StudentProfile?) -> String? {
        guard let profile else { return nil }

        if profile.educationLevel == "university" {
            let institution = (profile.institutionName ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let major = (profile.majorName ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if institution.isEmpty && major.isEmpty { return tr("pe_school_university") }
            if major.isEmpty { return institution }
            if institution.isEmpty { return major }
            return "\(institution) · \(major)"
        }

        var line = tr("pe_school_high")
        if let grade = Int(profile.gradeLevel) {
            line += " · " + tr("pe_grade_fmt", grade)
        }
        return line
    }
}
