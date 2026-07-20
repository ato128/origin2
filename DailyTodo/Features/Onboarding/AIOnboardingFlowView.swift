//
//  AIOnboardingFlowView.swift
//  DailyTodo
//
//  Mascot-led onboarding stage (Duolingo-style). "Updo" the mascot stands
//  center stage and speaks in a speech bubble; the user answers via the
//  controls below. Scripted (0 tokens) — see AIOnboardingStore.
//

import SwiftUI
import PhotosUI

struct AIOnboardingFlowView: View {
    /// Called (once) after the student profile is saved, so the parent can move
    /// to the app tour. Deterministic — does not depend on observing the store.
    var onComplete: () -> Void = {}

    @EnvironmentObject var studentStore: StudentStore
    @StateObject private var store = AIOnboardingStore()

    @State private var didComplete = false
    @State private var flyTrigger = 0
    @State private var majorInput = ""
    @FocusState private var uniFieldFocused: Bool

    // Fotoğraftan program + hafta turu
    @State private var scanItems: [PhotosPickerItem] = []
    @State private var tourName = ""
    @State private var tourStart = 9 * 60
    @State private var tourDuration = 60

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer(minLength: 16)

                speechBubble
                    .padding(.horizontal, 24)

                UpdoMascotView(isSpeaking: store.isSpeaking, flyTrigger: flyTrigger)
                    .padding(.top, 20)

                Spacer(minLength: 16)

                composer
            }
        }
        .preferredColorScheme(.dark)
        .tint(UpdoTheme.cyan)
        .onAppear {
            store.configure(studentStore: studentStore)
            store.startIfNeeded()
        }
        .onChange(of: store.currentLine) { _, line in
            // Each new line = an advance → the mascot flies to the "next page".
            guard !line.isEmpty else { return }
            flyTrigger += 1
        }
        .onChange(of: scanItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await runOnboardingScan(newItems) }
        }
        .onChange(of: store.phase) { _, phase in
            // Saved → celebrate briefly, then hand off to the app tour.
            guard phase == .finished, !didComplete else { return }
            didComplete = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { onComplete() }
        }
        .alert(tr("aio_save_error_title"), isPresented: Binding(
            get: { store.errorText != nil },
            set: { if !$0 { store.errorText = nil } }
        )) {
            Button(tr("common_retry")) { store.retrySave() }
            Button(tr("common_cancel"), role: .cancel) { store.errorText = nil }
        } message: {
            Text(store.errorText ?? "")
        }
    }

    // MARK: - Background

    private var background: some View {
        // The app's signature multi-color edge-lit field — matches the showcase.
        ArenaBackground(
            primaryGlow: Color(arenaHex: AppArenaPalette.cyan),
            secondaryGlow: Color(arenaHex: AppArenaPalette.purple),
            warmGlow: Color(arenaHex: AppArenaPalette.coral),
            intensity: 0.95
        )
    }

    // MARK: - Speech bubble

    private var speechBubble: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(store.currentLine)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(store.currentLine)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                if store.isWorking {
                    ProgressView().tint(Color(arenaHex: AppArenaPalette.cyan)).scaleEffect(0.8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(arenaHex: AppArenaPalette.cyan).opacity(0.07),
                                Color(arenaHex: AppArenaPalette.purple).opacity(0.06),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.28), radius: 18, y: 10)
            )

            Triangle()
                .fill(
                    LinearGradient(
                        colors: [Color(arenaHex: AppArenaPalette.purple).opacity(0.10), Color.white.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 22, height: 12)
                .offset(y: -1)
        }
        // Single animation driver: the store wraps currentLine changes in
        // withAnimation, which fires the Text's .transition. No extra modifier.
    }

    // MARK: - Composer (phase-driven)

    @ViewBuilder
    private var composer: some View {
        VStack(spacing: 10) {
            if store.isWorking {
                EmptyView()
            } else if !store.inputVisible {
                // User paces the dialogue — tap to reveal the next line.
                primaryButton(tr("common_continue"), icon: "arrow.right") { store.tapContinue() }
                    .transition(.opacity)
            } else {
                phaseInput
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var phaseInput: some View {
        switch store.phase {
        case .greeting, .saving, .finished:
            EmptyView()

        case .education:
            HStack(spacing: 10) {
                chip(tr("aio_a_university"), icon: "graduationcap.fill") { store.chooseEducation("university") }
                chip(tr("aio_a_highschool"), icon: "book.fill") { store.chooseEducation("highschool") }
            }

        case .university:
            universitySearch

        case .grade:
            wrapChips(store.gradeOptions, label: { store.gradeDisplay($0) }) { store.chooseGrade($0) }

        case .track:
            wrapChips(store.trackOptions, label: { store.trackDisplay($0) }) { store.chooseTrack($0) }

        case .major:
            majorInputField

        case .courseMethod:
            courseMethodInput

        case .coursePhotos:
            coursePhotosInput

        case .weekTour:
            weekTourInput

        case .goal:
            goalPicker
        }
    }

    // MARK: - University (single global list, inline autocomplete)

    private var universitySearch: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))

                TextField(
                    tr("aio_uni_placeholder"),
                    text: Binding(
                        get: { store.universityQuery },
                        set: { store.universityQueryChanged($0) }
                    )
                )
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .focused($uniFieldFocused)

                if store.isSearchingUniversities {
                    ProgressView().tint(UpdoTheme.cyan).scaleEffect(0.75)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(UpdoTheme.cyan.opacity(uniFieldFocused ? 0.4 : 0.15), lineWidth: 1)))
            .onAppear { uniFieldFocused = true }

            if !store.universityMatches.isEmpty {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(store.universityMatches) { university in
                            Button { store.selectUniversity(university) } label: {
                                HStack(spacing: 10) {
                                    Text(university.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.leading)

                                    Spacer(minLength: 6)

                                    Text(university.country_code.uppercased())
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.35))
                                }
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.045)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 210)
            }
        }
    }

    // MARK: - Major (free text)

    private var majorInputField: some View {
        VStack(spacing: 10) {
            TextField(tr("aio_major_placeholder"), text: $majorInput)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
                .submitLabel(.done)
                .onSubmit { store.confirmMajor(majorInput) }

            HStack(spacing: 10) {
                Button { store.confirmMajor("") } label: {
                    Text(tr("aio_skip"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(height: 48)
                        .padding(.horizontal, 18)
                }
                .buttonStyle(.plain)

                primaryButton(tr("common_continue"), icon: "arrow.right") { store.confirmMajor(majorInput) }
            }
        }
    }

    // MARK: - Course method (fotoğraf mı, elle mi?)

    private var courseMethodInput: some View {
        VStack(spacing: 10) {
            chip(tr("aio_m_photo"), icon: "camera.fill") { store.chooseCourseMethodPhoto() }
            chip(tr("aio_m_manual"), icon: "square.and.pencil") { store.chooseCourseMethodManual() }

            Button { store.skipCourses() } label: {
                Text(tr("aio_skip"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(height: 36)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Course photos (1-4 fotoğraf → tarama)

    @ViewBuilder
    private var coursePhotosInput: some View {
        if store.isScanningPhotos {
            loadingRow(tr("aio_scan_wait"))
        } else {
            VStack(spacing: 10) {
                PhotosPicker(
                    selection: $scanItems,
                    maxSelectionCount: 4,
                    matching: .images
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 15, weight: .black))
                        Text(tr("css_scan_button"))
                            .font(.system(size: 17, weight: .black))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(UpdoTheme.cyan)
                    )
                }

                Button { store.backToCourseMethod() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .bold))
                        Text(tr("aio_back"))
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(height: 36)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func runOnboardingScan(_ items: [PhotosPickerItem]) async {
        store.isScanningPhotos = true

        var images: [UIImage] = []
        for item in items.prefix(4) {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }

        scanItems = []

        guard !images.isEmpty else {
            store.scanFailed(tr("css_scan_err_generic"))
            return
        }

        do {
            let courses = try await ScheduleScanClient.scan(images)
            store.applyScanResults(courses)
        } catch {
            store.scanFailed(error.localizedDescription)
        }
    }

    // MARK: - Week tour (Pzt → Paz, gün gün kontrol + düzenleme)

    private var weekTourInput: some View {
        let day = store.tourDay
        let dayEntries = store.entries(on: day)

        return VStack(spacing: 10) {
            // Gün başlığı + geri
            HStack(spacing: 10) {
                Button { store.goBackInTour() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.white.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("a11y_back"))

                Text(AIOnboardingStore.weekdayFullNames[day])
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(.white)

                Spacer()

                Text("\(day + 1)/7")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(UpdoTheme.cyan)
            }

            // Günün dersleri
            if dayEntries.isEmpty {
                Text(tr("aio_tour_empty"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.035)))
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(dayEntries) { entry in
                            tourEntryRow(entry)
                        }
                    }
                }
                .frame(maxHeight: 168)
            }

            // Ders ekle formu
            VStack(spacing: 8) {
                TextField(tr("aio_tour_add_ph"), text: $tourName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.white.opacity(0.06)))

                HStack(spacing: 8) {
                    tourPicker(
                        selection: $tourStart,
                        values: Array(stride(from: 7 * 60, through: 22 * 60, by: 30)),
                        label: { AIOnboardingStore.minuteText($0) }
                    )

                    tourPicker(
                        selection: $tourDuration,
                        values: [30, 45, 60, 90, 120, 150, 180],
                        label: { tr("aio_min_fmt", $0) }
                    )

                    Button {
                        store.addTourEntry(name: tourName, startMinute: tourStart, durationMinute: tourDuration)
                        tourName = ""
                    } label: {
                        Text(tr("aio_tour_add"))
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(canAddTourEntry ? .black : .white.opacity(0.4))
                            .padding(.horizontal, 16)
                            .frame(height: 38)
                            .background(
                                Capsule().fill(canAddTourEntry ? AnyShapeStyle(UpdoTheme.cyan) : AnyShapeStyle(Color.white.opacity(0.07)))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAddTourEntry)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.035)))

            primaryButton(
                day < 6 ? tr("common_continue") : tr("aio_tour_finish"),
                icon: day < 6 ? "arrow.right" : "checkmark"
            ) { store.nextTourDay() }
        }
    }

    private var canAddTourEntry: Bool {
        !tourName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func tourEntryRow(_ entry: AIOnboardingStore.TourEntry) -> some View {
        HStack(spacing: 10) {
            Text("\(AIOnboardingStore.minuteText(entry.startMinute))–\(AIOnboardingStore.minuteText(entry.startMinute + entry.durationMinute))")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(UpdoTheme.cyan)

            Text(entry.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            if !entry.room.isEmpty {
                Text(entry.room)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            // Düzelt: satırı forma alır, eskisini kaldırır.
            Button {
                tourName = entry.name
                tourStart = entry.startMinute
                tourDuration = entry.durationMinute
                store.removeTourEntry(entry.id)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)

            Button { store.removeTourEntry(entry.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.white.opacity(0.045)))
    }

    private func tourPicker<T: Hashable>(
        selection: Binding<T>,
        values: [T],
        label: @escaping (T) -> String
    ) -> some View {
        Menu {
            Picker("", selection: selection) {
                ForEach(values, id: \.self) { value in
                    Text(label(value)).tag(value)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(label(selection.wrappedValue))
                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 11)
            .frame(height: 38)
            .background(Capsule().fill(Color.white.opacity(0.07)))
        }
    }

    // MARK: - Goal picker

    private var goalPicker: some View {
        VStack(spacing: 14) {
            HStack {
                Text(tr("aio_goal_value", Int(store.dailyStudyGoalMinutes)))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
            }
            Slider(value: $store.dailyStudyGoalMinutes, in: 30...300, step: 15)
                .tint(UpdoTheme.cyan)
            primaryButton(tr("aio_im_ready"), icon: "checkmark") { store.confirmGoal() }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white.opacity(0.05)))
    }

    // MARK: - Reusable bits

    private func chip(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                Text(title).font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(UpdoTheme.cyan.opacity(0.35), lineWidth: 1)))
        }
        .buttonStyle(.plain)
    }

    private func wrapChips(_ values: [String], label: @escaping (String) -> String, action: @escaping (String) -> Void) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
            ForEach(values, id: \.self) { v in
                Button { action(v) } label: {
                    Text(label(v))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func primaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 17, weight: .black))
                Image(systemName: icon).font(.system(size: 15, weight: .black))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity).frame(height: 56)
            .background(
                Capsule().fill(
                    LinearGradient(
                        colors: [Color(arenaHex: AppArenaPalette.cyan), Color(arenaHex: AppArenaPalette.blue)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .shadow(color: Color(arenaHex: AppArenaPalette.cyan).opacity(0.32), radius: 16, y: 8)
            )
        }
        .buttonStyle(OnboardingScaleButtonStyle())
    }

    private func loadingRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView().tint(UpdoTheme.cyan)
            Text(text).font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.05)))
    }
}

/// Downward speech-bubble tail.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
