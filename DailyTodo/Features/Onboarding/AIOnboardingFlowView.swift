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

    @State private var didComplete = false
    @State private var flyTrigger = 0
    @State private var majorInput = ""
    @FocusState private var uniFieldFocused: Bool

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

        case .courses:
            courseEntry

        case .schedule:
            scheduleFiller

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

    // MARK: - Courses (type or paste → parsed list)

    @ViewBuilder
    private var courseEntry: some View {
        if store.coursesParsed {
            parsedCourseList
        } else {
            VStack(spacing: 10) {
                TextEditor(text: $store.courseInputText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(height: 140)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
                    .overlay(alignment: .topLeading) {
                        if store.courseInputText.isEmpty {
                            Text(tr("aio_courses_placeholder"))
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(.white.opacity(0.32))
                                .padding(.horizontal, 16).padding(.top, 18)
                                .allowsHitTesting(false)
                        }
                    }

                HStack(spacing: 10) {
                    Button { store.skipCourses() } label: {
                        Text(tr("aio_skip"))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(height: 48)
                            .padding(.horizontal, 18)
                    }
                    .buttonStyle(.plain)

                    primaryButton(tr("aio_parse_courses"), icon: "wand.and.stars") { store.parseCourseInput() }
                        .disabled(store.courseInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(store.courseInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
            }
        }
    }

    private var parsedCourseList: some View {
        VStack(spacing: 10) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 6) {
                    ForEach(store.parsedCourses) { course in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(course.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.leading)

                                if course.hasSchedule || !course.code.isEmpty {
                                    HStack(spacing: 6) {
                                        if !course.code.isEmpty {
                                            Text(course.code)
                                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                                .foregroundStyle(.white.opacity(0.4))
                                        }
                                        ForEach(course.slots, id: \.self) { slot in
                                            Text("\(AIOnboardingStore.weekdayShortNames[slot.weekday]) \(AIOnboardingStore.minuteText(slot.startMinute))")
                                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                                .foregroundStyle(UpdoTheme.cyan.opacity(0.9))
                                        }
                                    }
                                }
                            }

                            Spacer(minLength: 6)

                            Button { store.removeParsedCourse(course.id) } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .frame(width: 26, height: 26)
                                    .background(Circle().fill(Color.white.opacity(0.06)))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.045)))
                    }
                }
            }
            .frame(maxHeight: 210)

            HStack(spacing: 10) {
                Button { store.editCoursesAgain() } label: {
                    Text(tr("aio_edit_again"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(height: 48)
                        .padding(.horizontal, 14)
                }
                .buttonStyle(.plain)

                primaryButton(tr("common_continue"), icon: "arrow.right") { store.confirmParsedCourses() }
            }
        }
    }

    // MARK: - Schedule fill (day + time for courses the parser couldn't place)

    private var scheduleFiller: some View {
        VStack(spacing: 10) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(store.unscheduledCourses) { course in
                        scheduleRow(course)
                    }
                }
            }
            .frame(maxHeight: 300)

            primaryButton(tr("common_continue"), icon: "arrow.right") { store.confirmSchedule() }
        }
    }

    private func scheduleRow(_ course: ParsedCourse) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(course.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)

            // Day chips
            HStack(spacing: 5) {
                ForEach(0..<7, id: \.self) { day in
                    let on = store.scheduleDayByCourse[course.id] == day
                    Button { store.setScheduleDay(course.id, weekday: day) } label: {
                        Text(AIOnboardingStore.weekdayShortNames[day])
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(on ? .black : .white.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background(
                                Capsule().fill(on ? AnyShapeStyle(UpdoTheme.cyan) : AnyShapeStyle(Color.white.opacity(0.06)))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Time chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(Array(stride(from: 8 * 60, through: 20 * 60, by: 30)), id: \.self) { minute in
                        let on = store.scheduleMinuteByCourse[course.id] == minute
                        Button { store.setScheduleMinute(course.id, minute: minute) } label: {
                            Text(AIOnboardingStore.minuteText(minute))
                                .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(on ? .black : .white.opacity(0.6))
                                .padding(.horizontal, 11)
                                .frame(height: 30)
                                .background(
                                    Capsule().fill(on ? AnyShapeStyle(UpdoTheme.cyan) : AnyShapeStyle(Color.white.opacity(0.06)))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.045)))
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
