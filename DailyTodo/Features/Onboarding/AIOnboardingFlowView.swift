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
    @State private var majorInput = ""
    @FocusState private var uniFieldFocused: Bool

    // Fotoğraftan program + hafta turu
    @State private var scanItems: [PhotosPickerItem] = []
    @State private var tourName = ""
    @State private var tourStart = 9 * 60
    @State private var tourDuration = 60

    private let isPad = UIDevice.current.userInterfaceIdiom == .pad

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar
                conversation
                composer
            }
            // iPad: one centred reading column, like the chat itself.
            .frame(maxWidth: isPad ? 640 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .updoColorScheme()
        .tint(UpdoTheme.cyan)
        .onAppear {
            store.configure(studentStore: studentStore)
            store.startIfNeeded()
        }
        .onChange(of: scanItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await runOnboardingScan(newItems) }
        }
        .onChange(of: store.phase) { _, phase in
            // Saved → let the closing line land, then hand off to the showcase.
            guard phase == .finished, !didComplete else { return }
            didComplete = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.9) { onComplete() }
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

    // MARK: - Top bar (the chat's own chrome: back · Updo AI)

    private var topBar: some View {
        ZStack {
            HStack(spacing: 7) {
                UpdoAIOrb(mode: store.isSpeaking ? .speaking : .idle, size: 18)
                (Text("Updo").font(.system(size: 15, weight: .heavy)).foregroundStyle(UpdoTheme.textPrimary)
                 + Text(" AI").font(.system(size: 15, weight: .regular, design: .serif)).italic()
                    .foregroundStyle(Color(arenaHex: AppArenaPalette.blue)))
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .liquidGlass(in: Capsule())

            HStack {
                if store.canGoBack {
                    Button { store.goBack() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(UpdoTheme.filmy(0.9))
                            .frame(width: 38, height: 38)
                            .liquidGlass(in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("a11y_back"))
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    // MARK: - Conversation (the transcript, as in the real chat)

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // Opens like the chat's own first screen: the orb, then words.
                    UpdoAIOrb(mode: store.isSpeaking ? .speaking : .idle, size: isPad ? 96 : 76)
                        .frame(maxWidth: .infinity)
                        .padding(.top, isPad ? 34 : 22)
                        .padding(.bottom, 10)

                    ForEach(store.transcript) { line in
                        messageRow(line)
                            .id(line.id)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 10)),
                                removal: .opacity
                            ))
                    }

                    if (store.isWorking || store.isScanningPhotos) && store.streamingLineID == nil {
                        // Working (scanning, saving): the chat's typing state.
                        HStack(alignment: .bottom, spacing: 6) {
                            UpdoAIOrb(mode: .speaking, size: 24)
                            TypingIndicatorBubble(status: store.isScanningPhotos ? tr("aio_scan_wait") : nil)
                        }
                        .transition(.opacity)
                    }

                    Color.clear.frame(height: 6).id(Self.bottomID)
                }
                .padding(.horizontal, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Fade under the top bar, like content sliding beneath the chrome.
            .mask(
                LinearGradient(
                    stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.045), .init(color: .black, location: 1)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .onChange(of: store.transcript.count) { _, _ in scrollToBottom(proxy) }
            // The controls below grow in with a spring and shrink this scroll
            // view — follow once at the start and once after it has settled.
            .onChange(of: store.inputVisible) { _, _ in
                scrollToBottom(proxy, delay: 0.12)
                scrollToBottom(proxy, delay: 0.6)
            }
            .onChange(of: store.phase) { _, _ in scrollToBottom(proxy, delay: 0.6) }
            .onChange(of: store.streamingLineID) { _, _ in scrollToBottom(proxy, delay: 0.05) }
            .onChange(of: store.tourDay) { _, _ in scrollToBottom(proxy, delay: 0.12) }
            .onChange(of: store.isWorking) { _, _ in scrollToBottom(proxy) }
        }
    }

    private static let bottomID = "aio-bottom"

    private func scrollToBottom(_ proxy: ScrollViewProxy, delay: Double = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
        }
    }

    @ViewBuilder
    private func messageRow(_ line: AIOnboardingStore.ChatLine) -> some View {
        if line.isUser {
            // The user's answer — the chat's own blue bubble.
            Text(line.text)
                .font(.system(size: isPad ? 18 : 16.5, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(arenaHex: "#0A84FF"))
                )
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 56)
        } else {
            // Updo AI — the chat's own reply: no bubble, written on live.
            OnboardingStreamedText(
                text: line.text,
                isStreaming: store.streamingLineID == line.id,
                showsOrb: line.id == lastAILineID && !store.isWorking && !store.isScanningPhotos,
                onFinished: { store.lineFinished(line.id) }
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 28)
        }
    }

    /// The newest Updo AI line carries the small orb, as in the chat.
    private var lastAILineID: UUID? {
        store.transcript.last(where: { !$0.isUser })?.id
    }

    // MARK: - Composer (phase-driven)

    @ViewBuilder
    private var composer: some View {
        VStack(spacing: 10) {
            // Controls arrive once Updo AI has finished speaking.
            if store.inputVisible && !store.isWorking {
                phaseInput
                    .transition(.opacity.combined(with: .offset(y: 16)))
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

        case .weekReveal:
            weekRevealInput

        case .notify:
            notifyInput

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
                Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(UpdoTheme.filmy(0.5))

                TextField(
                    tr("aio_uni_placeholder"),
                    text: Binding(
                        get: { store.universityQuery },
                        set: { store.universityQueryChanged($0) }
                    )
                )
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(UpdoTheme.textPrimary)
                .autocorrectionDisabled()
                .focused($uniFieldFocused)

                if store.isSearchingUniversities {
                    ProgressView().tint(UpdoTheme.cyan).scaleEffect(0.75)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(UpdoTheme.filmy(0.06))
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
                                        .foregroundStyle(UpdoTheme.textPrimary)
                                        .multilineTextAlignment(.leading)

                                    Spacer(minLength: 6)

                                    Text(university.country_code.uppercased())
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .foregroundStyle(UpdoTheme.filmy(0.35))
                                }
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(UpdoTheme.filmy(0.045)))
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
                .foregroundStyle(UpdoTheme.textPrimary)
                .padding(.horizontal, 14).padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(UpdoTheme.filmy(0.06)))
                .submitLabel(.done)
                .onSubmit { store.confirmMajor(majorInput) }

            HStack(spacing: 10) {
                Button { store.confirmMajor("") } label: {
                    Text(tr("aio_skip"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(UpdoTheme.filmy(0.5))
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
                    .foregroundStyle(UpdoTheme.filmy(0.45))
                    .frame(height: 36)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Course photos (1-4 fotoğraf → tarama)

    @ViewBuilder
    private var coursePhotosInput: some View {
        if store.isScanningPhotos {
            // "Reading your timetable…" shows in the conversation itself.
            EmptyView()
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
                    .foregroundStyle(UpdoTheme.filmy(0.5))
                    .frame(height: 36)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Week reveal (the scanned week, whole — accept or fix)

    private var weekRevealInput: some View {
        VStack(spacing: 12) {
            OnboardingWeekGrid(blocks: store.weekBlocks)
                .frame(height: isPad ? 260 : 214)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(UpdoTheme.filmy(0.045))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(UpdoTheme.cyan.opacity(0.22), lineWidth: 1))
                )

            primaryButton(tr("aio_reveal_ok"), icon: "checkmark") { store.acceptWeek() }

            Button { store.editWeek() } label: {
                Text(tr("aio_reveal_fix"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(UpdoTheme.filmy(0.6))
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Reminders primer (our question first; iOS asks only after a yes)

    private var notifyInput: some View {
        VStack(spacing: 10) {
            primaryButton(tr("aio_notify_yes"), icon: "bell.fill") { store.answerNotifications(allow: true) }

            Button { store.answerNotifications(allow: false) } label: {
                Text(tr("aio_notify_later"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(UpdoTheme.filmy(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
        if !images.isEmpty { store.photosSent(images.count) }

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
                        .foregroundStyle(UpdoTheme.textPrimary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(UpdoTheme.filmy(0.07)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("a11y_back"))

                Text(AIOnboardingStore.weekdayFullNames[day])
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(UpdoTheme.textPrimary)

                Spacer()

                Text("\(day + 1)/7")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(UpdoTheme.cyan)
            }

            // Günün dersleri
            if dayEntries.isEmpty {
                Text(tr("aio_tour_empty"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(UpdoTheme.filmy(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(UpdoTheme.filmy(0.035)))
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
                    .foregroundStyle(UpdoTheme.textPrimary)
                    .padding(.horizontal, 13).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(UpdoTheme.filmy(0.06)))

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
                            .foregroundStyle(canAddTourEntry ? .black : UpdoTheme.filmy(0.4))
                            .padding(.horizontal, 16)
                            .frame(height: 38)
                            .background(
                                Capsule().fill(canAddTourEntry ? AnyShapeStyle(UpdoTheme.cyan) : AnyShapeStyle(UpdoTheme.filmy(0.07)))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAddTourEntry)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(UpdoTheme.filmy(0.035)))

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
                .foregroundStyle(UpdoTheme.textPrimary)
                .lineLimit(1)

            if !entry.room.isEmpty {
                Text(entry.room)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(UpdoTheme.filmy(0.45))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(UpdoTheme.filmy(0.06)))
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
                    .foregroundStyle(UpdoTheme.filmy(0.5))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(UpdoTheme.filmy(0.06)))
            }
            .buttonStyle(.plain)

            Button { store.removeTourEntry(entry.id) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(UpdoTheme.filmy(0.4))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(UpdoTheme.filmy(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(UpdoTheme.filmy(0.045)))
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
            .foregroundStyle(UpdoTheme.filmy(0.85))
            .padding(.horizontal, 11)
            .frame(height: 38)
            .background(Capsule().fill(UpdoTheme.filmy(0.07)))
        }
    }

    // MARK: - Goal picker

    private var goalPicker: some View {
        VStack(spacing: 14) {
            HStack {
                Text(tr("aio_goal_value", Int(store.dailyStudyGoalMinutes)))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(UpdoTheme.textPrimary)
                Spacer()
            }
            Slider(value: $store.dailyStudyGoalMinutes, in: 30...300, step: 15)
                .tint(UpdoTheme.cyan)
            primaryButton(tr("aio_im_ready"), icon: "checkmark") { store.confirmGoal() }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(UpdoTheme.filmy(0.05)))
    }

    // MARK: - Reusable bits

    private func chip(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                Text(title).font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(UpdoTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(UpdoTheme.filmy(0.06))
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
                        .foregroundStyle(UpdoTheme.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(UpdoTheme.filmy(0.06))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(UpdoTheme.filmy(0.1), lineWidth: 1)))
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
            Text(text).font(.system(size: 14, weight: .medium)).foregroundStyle(UpdoTheme.filmy(0.6))
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(UpdoTheme.filmy(0.05)))
    }
}

// MARK: - Conversation pieces

/// A line from Updo AI, arriving exactly as its replies do in the chat: the
/// same stream pacer (`AIStreamPacer`) writes it on and the same renderer
/// (`AIRichTextView`) settles each fresh glyph in. The scripted text is fed
/// to the pacer in word-sized pieces at a model-like pace, so the motion is
/// the real one, not an imitation. Only this view observes the pacer — the
/// conversation around it does not re-render while a line is being written.
struct OnboardingStreamedText: View {
    let text: String
    let isStreaming: Bool
    /// Shows the small orb under the line (the latest Updo AI line only).
    var showsOrb = false
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var stream = AIStreamPacer()
    @State private var didFinish = false

    /// True while the pacer is the source of truth for what is on screen.
    private var isWriting: Bool { isStreaming && !didFinish }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                if isWriting && stream.frame.text.isEmpty {
                    // The same beat as the chat: dots first, then words.
                    TypingIndicatorBubble()
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottomLeading)))
                } else {
                    AIRichTextView(
                        blocks: AIRichParser.parse(isWriting ? stream.frame.text : text, streaming: isWriting),
                        tail: isWriting ? stream.frame.tail : []
                    )
                    .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.22), value: stream.frame.text.isEmpty)

            if showsOrb {
                AIReplyFooter(orb: isWriting ? .speaking : .idle, copyText: nil)
                    .transition(.opacity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .task(id: isStreaming) { await write() }
    }

    private func write() async {
        guard isStreaming, !didFinish else { return }

        if reduceMotion {
            didFinish = true
            onFinished()
            return
        }

        // A short "thinking" beat, then words at roughly the speed the model
        // writes — the pacer smooths them into its usual continuous flow.
        try? await Task.sleep(nanoseconds: 420_000_000)
        for piece in Self.pieces(of: text) {
            if Task.isCancelled { return }
            stream.append(piece)
            try? await Task.sleep(nanoseconds: 38_000_000)
        }
        await stream.drain()
        guard !Task.isCancelled else { return }
        try? await Task.sleep(nanoseconds: 180_000_000)
        didFinish = true
        onFinished()
    }

    /// Word-sized pieces, each keeping its trailing space.
    private static func pieces(of text: String) -> [String] {
        var result: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character == " " || character == "\n" {
                result.append(current)
                current = ""
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }
}

// MARK: - Week grid (the user's own classes, at a glance)

/// One class on one day.
struct OnboardingWeekBlock: Identifiable, Equatable {
    let id: UUID
    var weekday: Int          // 0 = Monday
    var startMinute: Int
    var durationMinute: Int
    var title: String
    var colorHex: String

    /// Same order as `StudentStore.createScheduleEvents`.
    static let palette = ["#22D3EE", "#8B5CF6", "#F59E0B", "#34D399", "#F472B6", "#60A5FA", "#F97316"]
}

/// Monday→Sunday columns with each class as a coloured block at its real
/// time. Used by the onboarding reveal and the personal showcase screen.
/// Blocks rise in day by day the first time it appears.
struct OnboardingWeekGrid: View {
    let blocks: [OnboardingWeekBlock]
    /// Highlights one column (e.g. today).
    var highlightedDay: Int? = nil
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    /// Whole hours around the classes, never tighter than six hours so a
    /// single lecture does not fill the grid.
    private var hourRange: ClosedRange<Int> {
        let starts = blocks.map(\.startMinute)
        let ends = blocks.map { $0.startMinute + $0.durationMinute }
        var first = (starts.min() ?? 9 * 60) / 60
        var last = Int((Double(ends.max() ?? 15 * 60) / 60).rounded(.up))
        while last - first < 6 {
            if first > 7 { first -= 1 }
            if last - first < 6, last < 23 { last += 1 }
            if first <= 7, last >= 23 { break }
        }
        return first...max(last, first + 1)
    }

    private func minutes(in range: ClosedRange<Int>) -> CGFloat {
        CGFloat((range.upperBound - range.lowerBound) * 60)
    }

    private func hourRail(range: ClosedRange<Int>, height: CGFloat) -> some View {
        let step = (range.upperBound - range.lowerBound) > 8 ? 3 : 2
        let hours = Array(stride(from: range.lowerBound, through: range.upperBound, by: step))
        let total = minutes(in: range)

        return ZStack(alignment: .topLeading) {
            ForEach(hours, id: \.self) { hour in
                let y: CGFloat = CGFloat(hour - range.lowerBound) * 60 / total * height - 5
                Text(String(format: "%02d", hour))
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(UpdoTheme.filmy(0.32))
                    .offset(y: y)
            }
        }
        .frame(width: 22, height: height, alignment: .topLeading)
    }

    private func dayColumn(_ day: Int, range: ClosedRange<Int>, height: CGFloat) -> some View {
        let dayBlocks = blocks.filter { $0.weekday == day }
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(UpdoTheme.filmy(day == highlightedDay ? 0.07 : 0.03))
            ForEach(dayBlocks) { block in
                blockView(block, range: range, height: height)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func blockView(_ block: OnboardingWeekBlock, range: ClosedRange<Int>, height: CGFloat) -> some View {
        let total = minutes(in: range)
        let top: CGFloat = CGFloat(block.startMinute - range.lowerBound * 60) / total * height
        let blockHeight: CGFloat = max(CGFloat(block.durationMinute) / total * height - 2, 7)
        let delay: Double = 0.12 + Double(block.weekday) * 0.07 + Double(block.startMinute) / 1440 * 0.25
        let entrance: Animation? = (reduceMotion || !animated)
            ? nil
            : .spring(response: 0.5, dampingFraction: 0.78).delay(delay)

        return RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color(arenaHex: block.colorHex).opacity(0.9))
            .overlay(alignment: .topLeading) {
                if blockHeight >= 20 {
                    Text(block.title)
                        .font(.system(size: 8, weight: .heavy))
                        .foregroundStyle(.black.opacity(0.78))
                        .lineLimit(blockHeight >= 32 ? 2 : 1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 3)
                        .padding(.top, 3)
                }
            }
            .frame(height: blockHeight)
            .padding(.horizontal, 1.5)
            .offset(y: top + 1)
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.6, anchor: .top)
            .animation(entrance, value: shown)
    }

    var body: some View {
        let range = hourRange

        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Color.clear.frame(width: 22, height: 1)
                ForEach(0..<7, id: \.self) { day in
                    Text(AIOnboardingStore.weekdayShortNames[day].uppercased())
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(day == highlightedDay ? UpdoTheme.cyan : UpdoTheme.filmy(0.5))
                        .frame(maxWidth: .infinity)
                }
            }

            GeometryReader { geo in
                HStack(alignment: .top, spacing: 4) {
                    hourRail(range: range, height: geo.size.height)
                    ForEach(0..<7, id: \.self) { day in
                        dayColumn(day, range: range, height: geo.size.height)
                    }
                }
            }
        }
        .onAppear { shown = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("aio_week_grid_a11y", OnboardingCount.lessons(blocks.count)))
    }
}
