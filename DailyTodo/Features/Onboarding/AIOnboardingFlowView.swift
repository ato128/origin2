//
//  AIOnboardingFlowView.swift
//  DailyTodo
//
//  Mascot-led onboarding stage (Duolingo-style). "Updo" the mascot stands
//  center stage and speaks in a speech bubble; the user answers via the
//  controls below. Scripted (0 tokens) — see AIOnboardingStore.
//

import SwiftUI

struct AIOnboardingFlowView: View {
    /// Called (once) after the student profile is saved, so the parent can move
    /// to the app tour. Deterministic — does not depend on observing the store.
    var onComplete: () -> Void = {}

    @EnvironmentObject var studentStore: StudentStore
    @StateObject private var store = AIOnboardingStore()

    @State private var showUniversityPicker = false
    @State private var didComplete = false
    @State private var flyTrigger = 0

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
        .sheet(isPresented: $showUniversityPicker) {
            UniversityPickerSheet(
                selectedUniversityID: $store.selectedUniversityID,
                selectedUniversityName: $store.institutionName,
                selectedCountryCode: $store.institutionCountry
            )
        }
        .onChange(of: store.institutionName) { _, name in
            if !name.isEmpty, store.phase == .university {
                showUniversityPicker = false
                store.universitySelected()
            }
        }
        .onChange(of: store.currentLine) { _, line in
            // Each new line = an advance → the mascot flies to the "next page".
            guard !line.isEmpty else { return }
            flyTrigger += 1
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
            primaryButton(tr("aio_find_university"), icon: "magnifyingglass") { showUniversityPicker = true }

        case .grade:
            wrapChips(store.gradeOptions, label: { store.gradeDisplay($0) }) { store.chooseGrade($0) }

        case .track:
            wrapChips(store.trackOptions, label: { store.trackDisplay($0) }) { store.chooseTrack($0) }

        case .major:
            majorPicker

        case .courses:
            coursePicker

        case .goal:
            goalPicker
        }
    }

    // MARK: - Major picker

    private var majorPicker: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                TextField(tr("aio_search_major"), text: $store.majorSearchText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(store.filteredMajors.prefix(40)) { major in
                        Button { store.selectMajor(major) } label: {
                            HStack {
                                Text(major.name).font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white).multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.045)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
    }

    // MARK: - Course picker

    private var coursePicker: some View {
        VStack(spacing: 10) {
            if !store.suggestedCourses.isEmpty {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(store.suggestedCourses) { course in
                            let on = store.selectedCourseIDs.contains(course.id)
                            Button { store.toggleCourse(course.id) } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(on ? UpdoTheme.cyan : .white.opacity(0.3))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(course.course_name).font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white).multilineTextAlignment(.leading)
                                        if !course.course_code.isEmpty {
                                            Text(course.course_code).font(.system(size: 11, weight: .medium))
                                                .foregroundStyle(.white.opacity(0.4))
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 14).padding(.vertical, 11)
                                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(on ? UpdoTheme.cyan.opacity(0.10) : Color.white.opacity(0.045)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 230)

                primaryButton(tr("common_continue"), icon: "arrow.right") { store.confirmCourses() }
            } else {
                primaryButton(tr("common_continue"), icon: "arrow.right") { store.confirmCourses() }
            }
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
