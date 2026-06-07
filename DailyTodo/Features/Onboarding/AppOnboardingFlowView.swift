//
//  AppOnboardingFlowView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 28.04.2026.
//

import SwiftUI
import SwiftData
import UIKit

enum AppOnboardingStage: String, CaseIterable {
    case features
    case student
    case focus
    case widgets
    case community
    case done
}

private enum OnboardingRequestState: Equatable {
    case idle, loading, success(String), failed(String)

    var message: String? {
        switch self {
        case .idle, .loading: nil
        case .success(let text), .failed(let text): text
        }
    }

    var isLoading: Bool { self == .loading }

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

private enum ScheduleSetupMode {
    case addNow
    case manualLater
}

private enum OnboardingArenaPalette {
    static let backgroundTop = "#05060D"
    static let backgroundMid = "#070713"
    static let backgroundBottom = "#07040C"

    static let appBlue = "#1593FF"
    static let appBlueSoft = "#1E6BFF"
    static let appCyan = "#2DD4FF"
    static let appPurple = "#7C3AED"
    static let appViolet = "#8B5CF6"
    static let coral = "#FF5A44"
    static let gold = "#FBBF24"
    static let green = "#A3E635"

    static let surface = "#101118"
    static let surface2 = "#171821"

    static var appGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(onboardingHex: appBlueSoft),
                Color(onboardingHex: appPurple)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var hotGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(onboardingHex: appBlue),
                Color(onboardingHex: appPurple),
                Color(onboardingHex: coral)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var softCardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(onboardingHex: appBlue).opacity(0.050),
                Color(onboardingHex: appPurple).opacity(0.065),
                Color.white.opacity(0.045)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct AppOnboardingFlowView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var studentStore: StudentStore
    @EnvironmentObject var friendStore: FriendStore
    @EnvironmentObject var crewStore: CrewStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("appOnboardingStageV2") private var stageRawValue = AppOnboardingStage.features.rawValue
    @AppStorage("didFinishFullOnboardingV2") private var didFinishFullOnboarding = false

    @State private var friendUsername = ""
    @State private var friendState: OnboardingRequestState = .idle
    @State private var foundFriendProfile: FriendProfileDTO?

    @State private var crewName = ""
    @State private var crewMemberUsername = ""
    @State private var crewState: OnboardingRequestState = .idle
    @State private var crewMemberState: OnboardingRequestState = .idle
    @State private var createdCrew: CrewDTO?
    @State private var addedCrewMemberProfile: FriendProfileDTO?
    @State private var selectedCrewIcon = "person.3.fill"
    @State private var selectedCrewColorHex = "#4F8CFF"

    @State private var selectedScheduleMode: ScheduleSetupMode = .manualLater
    @State private var selectedCourseID: UUID?
    @State private var selectedWeekday = 0
    @State private var selectedStartHour = 9
    @State private var selectedStartMinute = 0
    @State private var selectedDuration = 60
    @State private var scheduleState: OnboardingRequestState = .idle
    @State private var finalState: OnboardingRequestState = .idle

    @FocusState private var focusedField: OnboardingFocusField?

    private enum OnboardingFocusField {
        case friendUsername, crewName, crewMemberUsername
    }

    private let weekdays = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"]
    private let durations = [45, 60, 75, 90, 120]

    private var stage: AppOnboardingStage {
        AppOnboardingStage(rawValue: stageRawValue) ?? .features
    }

    private var selectedCourse: Course? {
        studentStore.courses.first { $0.id == selectedCourseID } ?? studentStore.courses.first
    }

    var body: some View {
        Group {
            switch stage {
            case .features:
                featureOverviewScreen

            case .student:
                StudentOnboardingFlowView()
                    .onChange(of: studentStore.hasCompletedStudentProfile) { _, completed in
                        if completed { goNext() }
                    }

            case .focus:
                focusExperienceScreen

            case .widgets:
                widgetsExperienceScreen

            case .community:
                communityExperienceScreen

            case .done:
                finishingScreen
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            normalizeStage()
            crewStore.setCurrentUser(session.currentUser?.id)

            if selectedCourseID == nil {
                selectedCourseID = studentStore.courses.first?.id
            }
        }
        .onChange(of: studentStore.hasCompletedStudentProfile) { _, _ in
            normalizeStage()
        }
        .onChange(of: studentStore.courses.count) { _, _ in
            if selectedCourseID == nil {
                selectedCourseID = studentStore.courses.first?.id
            }
        }
    }

    private func normalizeStage() {
        if didFinishFullOnboarding {
            stageRawValue = AppOnboardingStage.done.rawValue
            return
        }

        if AppOnboardingStage(rawValue: stageRawValue) == nil {
            stageRawValue = studentStore.hasCompletedStudentProfile
                ? AppOnboardingStage.focus.rawValue
                : AppOnboardingStage.features.rawValue
            return
        }

        if stage == .student, studentStore.hasCompletedStudentProfile {
            stageRawValue = AppOnboardingStage.focus.rawValue
        }
    }

    private func goNext() {
        focusedField = nil

        if stage == .community {
            Task {
                await completeFullOnboarding()
            }
            return
        }

        OnboardingHaptics.softTap()

        let update = {
            switch stage {
            case .features:
                stageRawValue = studentStore.hasCompletedStudentProfile
                    ? AppOnboardingStage.focus.rawValue
                    : AppOnboardingStage.student.rawValue

            case .student:
                stageRawValue = AppOnboardingStage.focus.rawValue

            case .focus:
                stageRawValue = AppOnboardingStage.widgets.rawValue

            case .widgets:
                stageRawValue = AppOnboardingStage.community.rawValue

            case .community:
                break

            case .done:
                break
            }
        }

        if reduceMotion {
            update()
        } else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                update()
            }
        }
    }
    
    private func completeFullOnboarding() async {
        guard !finalState.isLoading else { return }

        finalState = .loading
        focusedField = nil

        guard studentStore.hasCompletedStudentProfile else {
            finalState = .failed("Student setup tamamlanmadan uygulamaya geçilemez.")
            OnboardingHaptics.warning()

            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                stageRawValue = AppOnboardingStage.student.rawValue
            }

            return
        }

        await studentStore.loadFromRemote()

        guard studentStore.hasCompletedStudentProfile else {
            finalState = .failed("Profilin doğrulanamadı. Tekrar dene.")
            OnboardingHaptics.warning()
            return
        }

        await crewStore.loadCrews(force: true)
        await crewStore.loadCrewHomeSnapshot()

        finalState = .success("Updo hazır.")
        OnboardingHaptics.success()

        try? await Task.sleep(nanoseconds: 450_000_000)

        withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
            didFinishFullOnboarding = true
            stageRawValue = AppOnboardingStage.done.rawValue
        }
    }
}

// MARK: - Screens

private extension AppOnboardingFlowView {
    var featureOverviewScreen: some View {
        OnboardingShell(
            eyebrow: "STUDENT OS",
            titleFirst: "Updo’ya",
            titleAccent: "hoş geldin",
            subtitle: "Görevler, ders programı, focus, arkadaşlar ve gelişim takibi tek öğrenci sisteminde birleşir.",
            progressText: "1 / 5",
            canSkip: false,
            primaryTitle: "Hadi başlayalım",
            primaryIcon: "arrow.right",
            isKeyboardActive: focusedField != nil,
            primaryAction: goNext,
            skipAction: nil
        ) {
            VStack(spacing: 10) {
                FeatureOverviewGridItem(icon: "checkmark.circle.fill", title: "Tasks", subtitle: "Günlük görevlerini toparla", tint: Color(onboardingHex: OnboardingArenaPalette.green))
                FeatureOverviewGridItem(icon: "calendar", title: "Week", subtitle: "Ders ve çalışma akışını planla", tint: Color(onboardingHex: OnboardingArenaPalette.appBlue))
                FeatureOverviewGridItem(icon: "timer", title: "Focus", subtitle: "Odak oturumlarıyla ilerle", tint: Color(onboardingHex: OnboardingArenaPalette.coral))
                FeatureOverviewGridItem(icon: "person.3.fill", title: "Crew", subtitle: "Arkadaşlarınla beraber çalış", tint: Color(onboardingHex: OnboardingArenaPalette.appPurple))
                FeatureOverviewGridItem(icon: "chart.bar.xaxis", title: "Insights", subtitle: "Ritim, seri ve gelişimini gör", tint: Color(onboardingHex: OnboardingArenaPalette.gold))
            }
        }
    }
    
    var focusExperienceScreen: some View {
        OnboardingShell(
            eyebrow: "FOCUS FLOW",
            titleFirst: "Focus",
            titleAccent: "anywhere",
            subtitle: "Tek başına veya arkadaşlarınla focus başlat. Süreyi Kilit Ekranı ve Dynamic Island’dan takip et.",
            progressText: "3 / 5",
            canSkip: false,
            primaryTitle: "Devam et",
            primaryIcon: "arrow.right",
            isKeyboardActive: focusedField != nil,
            primaryAction: goNext,
            skipAction: nil
        ) {
            VStack(alignment: .leading, spacing: 14) {
                LiveActivityOnboardingPreview()

                AnimatedOnboardingFeatureCard(
                    icon: "timer",
                    title: "Focus timer",
                    subtitle: "Ders, sınav veya proje için net bir odak oturumu başlat.",
                    tint: Color(onboardingHex: OnboardingArenaPalette.coral),
                    delay: 0.05
                )

                AnimatedOnboardingFeatureCard(
                    icon: "platter.filled.top.iphone",
                    title: "Live Activity",
                    subtitle: "Focus süreni Kilit Ekranı ve Dynamic Island üzerinden canlı takip et.",
                    tint: Color(onboardingHex: OnboardingArenaPalette.appCyan),
                    delay: 0.13
                )

                AnimatedOnboardingFeatureCard(
                    icon: "person.2.fill",
                    title: "Focus with friends",
                    subtitle: "Arkadaşlarınla beraber focus yap, birbirinizi motive edin.",
                    tint: Color(onboardingHex: OnboardingArenaPalette.green),
                    delay: 0.21
                )

                VStack(alignment: .leading, spacing: 12) {
                    OnboardingInfoCard(
                        icon: "person.badge.plus",
                        title: "İstersen bir arkadaşını şimdi ekle",
                        subtitle: "Kullanıcı adıyla arkadaş isteği gönder. Bu adımı sonra da yapabilirsin.",
                        tint: Color(onboardingHex: OnboardingArenaPalette.appBlue)
                    )

                    InlineAddInput(
                        title: "Arkadaş kullanıcı adı",
                        placeholder: "örn. hasan",
                        text: $friendUsername,
                        icon: "at",
                        tint: Color(onboardingHex: OnboardingArenaPalette.appBlue),
                        isLoading: friendState.isLoading
                    ) {
                        Task { await addFriendByUsername() }
                    }
                    .focused($focusedField, equals: .friendUsername)

                    if let foundFriendProfile {
                        OnboardingProfilePreviewCard(
                            title: foundFriendProfile.full_name ?? foundFriendProfile.username ?? "Kullanıcı",
                            subtitle: "@\(foundFriendProfile.username ?? "user")",
                            icon: "person.fill.checkmark",
                            tint: Color(onboardingHex: OnboardingArenaPalette.green),
                            trailingText: "Gönderildi"
                        )
                    }

                    if let message = friendState.message {
                        StatusCard(text: message, isSuccess: friendState.isSuccess)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    var widgetsExperienceScreen: some View {
        OnboardingShell(
            eyebrow: "WEEK + WIDGETS",
            titleFirst: "Your week",
            titleAccent: "visible",
            subtitle: "Derslerini, görevlerini ve focus ilerlemeni ana ekrandan hızlıca takip et.",
            progressText: "4 / 5",
            canSkip: false,
            primaryTitle: "Devam et",
            primaryIcon: "arrow.right",
            isKeyboardActive: focusedField != nil,
            primaryAction: goNext,
            skipAction: nil
        ) {
            VStack(alignment: .leading, spacing: 14) {
                WidgetOnboardingPreview()

                AnimatedOnboardingFeatureCard(
                    icon: "square.grid.2x2.fill",
                    title: "Home Screen widgets",
                    subtitle: "Bugünkü görevlerini ve focus durumunu widget üzerinden gör.",
                    tint: Color(onboardingHex: OnboardingArenaPalette.appBlue),
                    delay: 0.05
                )

                AnimatedOnboardingFeatureCard(
                    icon: "calendar",
                    title: "Week planning",
                    subtitle: "Ders ve çalışma akışını Week ekranında düzenle.",
                    tint: Color(onboardingHex: OnboardingArenaPalette.appPurple),
                    delay: 0.13
                )

                AnimatedOnboardingFeatureCard(
                    icon: "chart.bar.xaxis",
                    title: "Insights-ready",
                    subtitle: "Derslerin ve focusların ilerledikçe ritmini analiz eder.",
                    tint: Color(onboardingHex: OnboardingArenaPalette.gold),
                    delay: 0.21
                )

                OnboardingInfoCard(
                    icon: "hand.tap.fill",
                    title: "Widget ekleme uygulama dışında yapılır",
                    subtitle: "Ana ekrana basılı tutup Updo widget’ını seçebilirsin.",
                    tint: Color(onboardingHex: OnboardingArenaPalette.appCyan)
                )
            }
        }
    }

    var communityExperienceScreen: some View {
        OnboardingShell(
            eyebrow: "COMMUNITY",
            titleFirst: "Study with",
            titleAccent: "people",
            subtitle: "Crew kur, arkadaşlarınla beraber focus yap, görev paylaş ve akademik çevreni canlı tut.",
            progressText: "5 / 5",
            canSkip: false,
            primaryTitle: finalState.isLoading ? "Hazırlanıyor..." : "Updo’ya geç",
            primaryIcon: finalState.isLoading ? "clock" : "checkmark.circle.fill",
            isKeyboardActive: focusedField != nil,
            primaryAction: goNext,
            skipAction: nil
        ) {
            VStack(alignment: .leading, spacing: 14) {
                CrewCommunityOnboardingPreview()

                AnimatedOnboardingFeatureCard(
                    icon: "person.3.fill",
                    title: "Crew focus",
                    subtitle: "Crew üyeleriyle aynı anda focus başlat ve birlikte ilerle.",
                    tint: Color(onboardingHex: OnboardingArenaPalette.appPurple),
                    delay: 0.05
                )

                AnimatedOnboardingFeatureCard(
                    icon: "checklist",
                    title: "Shared tasks",
                    subtitle: "Ortak görevleri ve proje işlerini crew içinde takip et.",
                    tint: Color(onboardingHex: OnboardingArenaPalette.green),
                    delay: 0.13
                )

                AnimatedOnboardingFeatureCard(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "Chat + progress",
                    subtitle: "Mesajlaş, ilerlemeyi paylaş ve çalışma grubunu aktif tut.",
                    tint: Color(onboardingHex: OnboardingArenaPalette.appCyan),
                    delay: 0.21
                )

                VStack(alignment: .leading, spacing: 12) {
                    OnboardingInfoCard(
                        icon: "plus.circle.fill",
                        title: "İstersen ilk crew’ünü şimdi oluştur",
                        subtitle: "Crew oluşturmazsan da uygulama içinde istediğin zaman başlatabilirsin.",
                        tint: Color.updoHex(selectedCrewColorHex)
                    )

                    PremiumInputField(
                        title: "Crew adı",
                        placeholder: "örn. CMPE Study Crew",
                        text: $crewName,
                        icon: selectedCrewIcon,
                        tint: Color.updoHex(selectedCrewColorHex)
                    )
                    .focused($focusedField, equals: .crewName)

                    CrewStylePicker(
                        selectedIcon: $selectedCrewIcon,
                        selectedColorHex: $selectedCrewColorHex
                    )

                    Button {
                        Task { await createCrewFromOnboarding() }
                    } label: {
                        PremiumPrimaryMiniButton(
                            title: crewState.isLoading ? "Oluşturuluyor..." : (createdCrew == nil ? "Crew oluştur" : "Crew hazır"),
                            subtitle: createdCrew == nil ? "İlk çalışma grubunu başlat" : "MainTab’de Crew sayfanda görünecek",
                            icon: createdCrew == nil ? "plus" : "checkmark",
                            tint: Color.updoHex(selectedCrewColorHex),
                            isLoading: crewState.isLoading
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(crewState.isLoading || createdCrew != nil)

                    if let message = crewState.message {
                        StatusCard(text: message, isSuccess: crewState.isSuccess)
                    }

                    if let message = finalState.message {
                        StatusCard(text: message, isSuccess: finalState.isSuccess)
                    }
                }
            }
        }
    }

    var friendsScreen: some View {
        OnboardingShell(
            eyebrow: "SOCIAL SETUP",
            titleFirst: "Arkadaşlarını",
            titleAccent: "ekle",
            subtitle: "Kullanıcı adıyla arkadaş isteği gönder. İstersen bu adımı sonra tamamlayabilirsin.",
            progressText: "3 / 5",
            canSkip: true,
            primaryTitle: friendState.isSuccess ? "Devam et" : "Sonra yapacağım",
            primaryIcon: friendState.isSuccess ? "arrow.right" : "forward.fill",
            isKeyboardActive: focusedField != nil,
            primaryAction: goNext,
            skipAction: goNext
        ) {
            VStack(alignment: .leading, spacing: 14) {
                InlineAddInput(
                    title: "Kullanıcı adı",
                    placeholder: "örn. hasan",
                    text: $friendUsername,
                    icon: "at",
                    tint: Color(onboardingHex: OnboardingArenaPalette.appBlue),
                    isLoading: friendState.isLoading
                ) {
                    Task { await addFriendByUsername() }
                }
                .focused($focusedField, equals: .friendUsername)

                if let foundFriendProfile {
                    OnboardingProfilePreviewCard(
                        title: foundFriendProfile.full_name ?? foundFriendProfile.username ?? "Kullanıcı",
                        subtitle: "@\(foundFriendProfile.username ?? "user")",
                        icon: "person.fill.checkmark",
                        tint: Color(onboardingHex: OnboardingArenaPalette.green),
                        trailingText: "Gönderildi"
                    )
                } else {
                    OnboardingInfoCard(
                        icon: "sparkles",
                        title: "Daha sonra da ekleyebilirsin",
                        subtitle: "Arkadaş, chat ve beraber focus özellikleri uygulama içinde açık kalır.",
                        tint: Color(onboardingHex: OnboardingArenaPalette.appBlue)
                    )
                }

                if let message = friendState.message {
                    StatusCard(text: message, isSuccess: friendState.isSuccess)
                }
            }
        }
    }

    var crewScreen: some View {
        OnboardingShell(
            eyebrow: "CREW SETUP",
            titleFirst: "Crew",
            titleAccent: "oluştur",
            subtitle: "Ders grubu, proje ekibi veya arkadaş çalışma grubu için küçük bir crew başlat.",
            progressText: "4 / 5",
            canSkip: true,
            primaryTitle: createdCrew == nil ? "Sonra oluşturacağım" : "Devam et",
            primaryIcon: createdCrew == nil ? "forward.fill" : "arrow.right",
            isKeyboardActive: focusedField != nil,
            primaryAction: goNext,
            skipAction: goNext
        ) {
            VStack(alignment: .leading, spacing: 14) {
                PremiumInputField(
                    title: "Crew adı",
                    placeholder: "örn. CMPE Study Crew",
                    text: $crewName,
                    icon: selectedCrewIcon,
                    tint: Color.updoHex(selectedCrewColorHex)
                )
                .focused($focusedField, equals: .crewName)

                CrewStylePicker(
                    selectedIcon: $selectedCrewIcon,
                    selectedColorHex: $selectedCrewColorHex
                )

                Button {
                    Task { await createCrewFromOnboarding() }
                } label: {
                    PremiumPrimaryMiniButton(
                        title: crewState.isLoading ? "Oluşturuluyor..." : "Crew oluştur",
                        subtitle: "Crew uygulama içinde de görünecek",
                        icon: "plus",
                        tint: Color.updoHex(selectedCrewColorHex),
                        isLoading: crewState.isLoading
                    )
                }
                .buttonStyle(.plain)
                .disabled(crewState.isLoading)

                if let message = crewState.message {
                    StatusCard(text: message, isSuccess: crewState.isSuccess)
                }

                if createdCrew != nil {
                    InlineAddInput(
                        title: "Crew’e arkadaş ekle",
                        placeholder: "Arkadaşının kullanıcı adı",
                        text: $crewMemberUsername,
                        icon: "at",
                        tint: Color(onboardingHex: OnboardingArenaPalette.green),
                        isLoading: crewMemberState.isLoading
                    ) {
                        Task { await addMemberToCreatedCrew() }
                    }
                    .focused($focusedField, equals: .crewMemberUsername)

                    if let addedCrewMemberProfile {
                        OnboardingProfilePreviewCard(
                            title: addedCrewMemberProfile.full_name ?? addedCrewMemberProfile.username ?? "Kullanıcı",
                            subtitle: "@\(addedCrewMemberProfile.username ?? "user")",
                            icon: "person.2.fill",
                            tint: Color(onboardingHex: OnboardingArenaPalette.green),
                            trailingText: "Eklendi"
                        )
                    }

                    if let message = crewMemberState.message {
                        StatusCard(text: message, isSuccess: crewMemberState.isSuccess)
                    }
                } else {
                    OnboardingInfoCard(
                        icon: "person.badge.plus",
                        title: "Arkadaş ekleme hazır",
                        subtitle: "Crew oluşturduktan sonra istersen hemen arkadaşını ekleyebilirsin.",
                        tint: Color(onboardingHex: OnboardingArenaPalette.appPurple)
                    )
                }
            }
        }
    }

    var scheduleScreen: some View {
        OnboardingShell(
            eyebrow: "WEEK SETUP",
            titleFirst: "Ders programını",
            titleAccent: "hazırla",
            subtitle: "Seçtiğin dersleri haftaya yerleştir. Kaydedince Week ekranında görünür.",
            progressText: "5 / 5",
            canSkip: true,
            primaryTitle: finalState.isLoading ? "Hazırlanıyor..." : "Uygulamaya geç",
            primaryIcon: "checkmark.circle.fill",
            isKeyboardActive: focusedField != nil,
            primaryAction: goNext,
            skipAction: goNext
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    ScheduleModeCompactCard(
                        title: "Şimdi ekle",
                        icon: "calendar.badge.plus",
                        isSelected: selectedScheduleMode == .addNow,
                        tint: Color(onboardingHex: OnboardingArenaPalette.appBlue)
                    ) {
                        selectedScheduleMode = .addNow
                    }

                    ScheduleModeCompactCard(
                        title: "Sonra",
                        icon: "clock.arrow.circlepath",
                        isSelected: selectedScheduleMode == .manualLater,
                        tint: Color(onboardingHex: OnboardingArenaPalette.appPurple)
                    ) {
                        selectedScheduleMode = .manualLater
                    }
                }

                if selectedScheduleMode == .addNow {
                    scheduleBuilder
                }

                if let message = scheduleState.message {
                    StatusCard(text: message, isSuccess: scheduleState.isSuccess)
                }
                
                if let message = finalState.message {
                    StatusCard(text: message, isSuccess: finalState.isSuccess)
                }

                OnboardingInfoCard(
                    icon: "graduationcap.fill",
                    title: "\(studentStore.courses.count) ders hazır",
                    subtitle: "Student setup’ta seçtiğin dersler Week programına eklenebilir.",
                    tint: Color(onboardingHex: OnboardingArenaPalette.green)
                )
            }
        }
    }

    var scheduleBuilder: some View {
        VStack(alignment: .leading, spacing: 12) {
            if studentStore.courses.isEmpty {
                StatusCard(
                    text: "Henüz ders bulunamadı. Uygulamaya geçtikten sonra ders ekleyebilirsin.",
                    isSuccess: false
                )
            } else {
                Text("Ders")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.58))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(studentStore.courses) { course in
                            Button {
                                selectedCourseID = course.id
                            } label: {
                                Text(course.code.isEmpty ? course.name : "\(course.code) • \(course.name)")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundStyle(selectedCourseID == course.id ? .black : .white)
                                    .lineLimit(1)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(
                                        Capsule()
                                            .fill(selectedCourseID == course.id ? Color(onboardingHex: OnboardingArenaPalette.appBlue) : .white.opacity(0.08))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 7), spacing: 7) {
                    ForEach(0..<7, id: \.self) { index in
                        Button {
                            selectedWeekday = index
                        } label: {
                            Text(weekdays[index])
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(selectedWeekday == index ? .black : .white)
                                .frame(height: 36)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(selectedWeekday == index ? Color(onboardingHex: OnboardingArenaPalette.appBlue) : .white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    StepperPill(title: "Saat", value: String(format: "%02d", selectedStartHour)) {
                        selectedStartHour = max(6, selectedStartHour - 1)
                    } plus: {
                        selectedStartHour = min(23, selectedStartHour + 1)
                    }

                    StepperPill(title: "Dakika", value: String(format: "%02d", selectedStartMinute)) {
                        selectedStartMinute = previousMinute(selectedStartMinute)
                    } plus: {
                        selectedStartMinute = nextMinute(selectedStartMinute)
                    }
                }

                HStack(spacing: 7) {
                    ForEach(durations, id: \.self) { duration in
                        Button {
                            selectedDuration = duration
                        } label: {
                            Text("\(duration)")
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(selectedDuration == duration ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(
                                    Capsule()
                                        .fill(selectedDuration == duration ? Color(onboardingHex: OnboardingArenaPalette.appBlue) : .white.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    saveSelectedCourseSchedule()
                } label: {
                    OnboardingActionRow(
                        title: "Programa ekle",
                        subtitle: selectedCourse?.name ?? "Ders seç",
                        icon: "calendar.badge.plus",
                        tint: Color(onboardingHex: OnboardingArenaPalette.appBlue),
                        isLoading: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(CardSurface(radius: 26))
    }

    var finishingScreen: some View {
        ZStack {
            OnboardingArenaBackground()
                .ignoresSafeArea()

            ProgressView()
                .tint(.white)
        }
    }

    func previousMinute(_ minute: Int) -> Int {
        switch minute {
        case 45: return 30
        case 30: return 15
        case 15: return 0
        default: return 45
        }
    }

    func nextMinute(_ minute: Int) -> Int {
        switch minute {
        case 0: return 15
        case 15: return 30
        case 30: return 45
        default: return 0
        }
    }
}

// MARK: - Actions

private extension AppOnboardingFlowView {
    func addFriendByUsername() async {
        guard let currentUserID = session.currentUser?.id else {
            friendState = .failed("Oturum bulunamadı.")
            OnboardingHaptics.warning()
            return
        }

        let clean = friendUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !clean.isEmpty else {
            friendState = .failed("Kullanıcı adı boş olamaz.")
            OnboardingHaptics.warning()
            return
        }

        if clean == session.currentUser?.username.lowercased() {
            friendState = .failed("Kendini arkadaş olarak ekleyemezsin.")
            OnboardingHaptics.warning()
            return
        }

        friendState = .loading

        do {
            let profile = try await friendStore.findUserByUsername(clean)

            try await friendStore.sendFriendRequest(
                to: profile.id,
                currentUserID: currentUserID
            )

            await friendStore.loadAllFriendships(currentUserID: currentUserID)

            OnboardingHaptics.success()
            foundFriendProfile = profile
            friendState = .success("@\(clean) için arkadaş isteği gönderildi.")
            friendUsername = ""
            focusedField = nil
        } catch {
            OnboardingHaptics.warning()
            friendState = .failed("Kullanıcı bulunamadı.")
        }
    }

    func createCrewFromOnboarding() async {
        guard let ownerID = session.currentUser?.id else {
            crewState = .failed("Oturum bulunamadı.")
            OnboardingHaptics.warning()
            return
        }

        let clean = crewName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard clean.count >= 2 else {
            crewState = .failed("Crew adı en az 2 karakter olmalı.")
            OnboardingHaptics.warning()
            return
        }

        crewState = .loading

        do {
            crewStore.setCurrentUser(ownerID)

            let crew = try await crewStore.createCrew(
                name: clean,
                icon: selectedCrewIcon,
                colorHex: selectedCrewColorHex,
                ownerID: ownerID
            )

            OnboardingHaptics.success()
            createdCrew = crew
            crewState = .success("\(clean) oluşturuldu.")
            crewName = ""
            focusedField = nil
        } catch {
            OnboardingHaptics.warning()
            crewState = .failed("Crew oluşturulamadı. Tekrar dene.")
        }
    }

    func addMemberToCreatedCrew() async {
        guard let createdCrew else {
            crewMemberState = .failed("Önce crew oluştur.")
            OnboardingHaptics.warning()
            return
        }

        let clean = crewMemberUsername.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !clean.isEmpty else {
            crewMemberState = .failed("Kullanıcı adı boş olamaz.")
            OnboardingHaptics.warning()
            return
        }

        crewMemberState = .loading

        do {
            let profile = try await friendStore.findUserByUsername(clean)
            try await crewStore.addMember(by: clean, to: createdCrew.id)

            OnboardingHaptics.success()
            addedCrewMemberProfile = profile
            crewMemberState = .success("@\(clean) crew’e eklendi.")
            crewMemberUsername = ""
            focusedField = nil
        } catch {
            OnboardingHaptics.warning()
            crewMemberState = .failed("Kullanıcı bulunamadı veya zaten crew içinde.")
        }
    }

    func saveSelectedCourseSchedule() {
        guard let currentUserID = session.currentUser?.id.uuidString else {
            scheduleState = .failed("Oturum bulunamadı.")
            OnboardingHaptics.warning()
            return
        }

        guard let course = selectedCourse else {
            scheduleState = .failed("Önce bir ders seç.")
            OnboardingHaptics.warning()
            return
        }

        let startMinute = selectedStartHour * 60 + selectedStartMinute
        let title = course.code.isEmpty ? course.name : "\(course.code) • \(course.name)"

        let event = EventItem(
            ownerUserID: currentUserID,
            title: title,
            weekday: selectedWeekday,
            startMinute: startMinute,
            durationMinute: selectedDuration,
            location: nil,
            notes: "Onboarding sırasında eklendi",
            colorHex: course.colorHex
        )

        modelContext.insert(event)

        do {
            try modelContext.save()
            scheduleState = .success("\(title), \(weekdays[selectedWeekday]) \(String(format: "%02d:%02d", selectedStartHour, selectedStartMinute)) saatine eklendi.")
            OnboardingHaptics.success()
        } catch {
            scheduleState = .failed("Ders programa eklenemedi.")
            OnboardingHaptics.warning()
        }
    }
}

// MARK: - Shell

private struct OnboardingShell<Content: View>: View {
    let eyebrow: String
    let titleFirst: String
    let titleAccent: String
    let subtitle: String
    let progressText: String
    let canSkip: Bool
    let primaryTitle: String
    let primaryIcon: String
    let isKeyboardActive: Bool
    let primaryAction: () -> Void
    let skipAction: (() -> Void)?
    let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        eyebrow: String,
        titleFirst: String,
        titleAccent: String,
        subtitle: String,
        progressText: String,
        canSkip: Bool,
        primaryTitle: String,
        primaryIcon: String,
        isKeyboardActive: Bool,
        primaryAction: @escaping () -> Void,
        skipAction: (() -> Void)?,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.titleFirst = titleFirst
        self.titleAccent = titleAccent
        self.subtitle = subtitle
        self.progressText = progressText
        self.canSkip = canSkip
        self.primaryTitle = primaryTitle
        self.primaryIcon = primaryIcon
        self.isKeyboardActive = isKeyboardActive
        self.primaryAction = primaryAction
        self.skipAction = skipAction
        self.content = content()
    }

    var body: some View {
        ZStack {
            OnboardingArenaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                floatingTopBar

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        hero
                        content
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .padding(.bottom, isKeyboardActive ? 26 : 112)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .transition(
                        reduceMotion
                        ? .identity
                        : .opacity.combined(with: .scale(scale: 0.985))
                    )
                }
                .scrollDismissesKeyboard(.interactively)
            }

            if !isKeyboardActive {
                VStack {
                    Spacer()
                    floatingBottomBar
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
    }

    private var floatingTopBar: some View {
        HStack {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color(onboardingHex: OnboardingArenaPalette.appBlue))
                    .frame(width: 18, height: 1)

                Text(progressText)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(Color(onboardingHex: OnboardingArenaPalette.appCyan))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.075))
                    .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
            )

            Spacer()

            if canSkip {
                Button {
                    skipAction?()
                } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.075))
                                .overlay(Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 54)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("— \(eyebrow) —")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(2.3)
                    .foregroundStyle(Color(onboardingHex: OnboardingArenaPalette.appCyan))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(titleFirst)
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(.white)

                Text(titleAccent)
                    .font(.system(size: 34, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(onboardingHex: OnboardingArenaPalette.appCyan),
                                Color(onboardingHex: OnboardingArenaPalette.appPurple)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .lineLimit(2)
            .minimumScaleFactor(0.68)

            Text(subtitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.58))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 1)
        }
    }

    private var floatingBottomBar: some View {
        Button(action: primaryAction) {
            HStack(spacing: 10) {
                Text(primaryTitle)
                    .font(.system(size: 18, weight: .black, design: .rounded))

                Image(systemName: primaryIcon)
                    .font(.system(size: 18, weight: .black))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                Capsule()
                    .fill(OnboardingArenaPalette.hotGradient)
            )
            .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
            .shadow(color: Color(onboardingHex: OnboardingArenaPalette.appPurple).opacity(0.26), radius: 18, y: 9)
        }
        .buttonStyle(OnboardingPressButtonStyle())
        .padding(.horizontal, 24)
        .padding(.bottom, 22)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.80),
                    Color.black.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .frame(height: 132)
            .allowsHitTesting(false),
            alignment: .bottom
        )
    }
}

// MARK: - Components
private struct AnimatedOnboardingFeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let delay: Double

    @State private var appeared = false
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(tint.opacity(pulse ? 0.22 : 0.14))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(tint)
                    .scaleEffect(pulse ? 1.05 : 0.98)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.54))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white.opacity(0.22))
        }
        .padding(13)
        .background(CardSurface(radius: 24))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86).delay(delay)) {
                appeared = true
            }

            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true).delay(delay)) {
                pulse = true
            }
        }
    }
}

private struct LiveActivityOnboardingPreview: View {
    @State private var active = false
    @State private var progress: CGFloat = 0.32

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("LIVE ACTIVITY")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Color(onboardingHex: OnboardingArenaPalette.appCyan))

                Spacer()

                Text("Focus active")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(Color(onboardingHex: OnboardingArenaPalette.green))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color(onboardingHex: OnboardingArenaPalette.green).opacity(0.12), in: Capsule())
            }

            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.090),
                                Color.white.opacity(0.045),
                                Color(onboardingHex: OnboardingArenaPalette.appPurple).opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 96)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 1)
                    )

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.10), lineWidth: 7)
                            .frame(width: 58, height: 58)

                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                OnboardingArenaPalette.hotGradient,
                                style: StrokeStyle(lineWidth: 7, lineCap: .round)
                            )
                            .frame(width: 58, height: 58)
                            .rotationEffect(.degrees(-90))

                        Image(systemName: "timer")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Study Focus")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("24:18 remaining")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.58))
                    }

                    Spacer()

                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Color(onboardingHex: OnboardingArenaPalette.gold))
                        .scaleEffect(active ? 1.12 : 0.92)
                }
                .padding(.horizontal, 18)
            }
        }
        .padding(16)
        .background(CardSurface(radius: 28))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                active = true
                progress = 0.74
            }
        }
    }
}

private struct WidgetOnboardingPreview: View {
    @State private var lifted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("WIDGETS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(Color(onboardingHex: OnboardingArenaPalette.appCyan))

                Spacer()

                Image(systemName: "plus.app.fill")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(Color(onboardingHex: OnboardingArenaPalette.appBlue))
            }

            HStack(spacing: 10) {
                widgetCard(
                    title: "Today",
                    value: "4 tasks",
                    icon: "checkmark.circle.fill",
                    tint: Color(onboardingHex: OnboardingArenaPalette.green),
                    delay: 0.0
                )

                widgetCard(
                    title: "Focus",
                    value: "72 min",
                    icon: "timer",
                    tint: Color(onboardingHex: OnboardingArenaPalette.coral),
                    delay: 0.08
                )

                widgetCard(
                    title: "Week",
                    value: "Ready",
                    icon: "calendar",
                    tint: Color(onboardingHex: OnboardingArenaPalette.appPurple),
                    delay: 0.16
                )
            }
        }
        .padding(16)
        .background(CardSurface(radius: 28))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                lifted = true
            }
        }
    }

    private func widgetCard(
        title: String,
        value: String,
        icon: String,
        tint: Color,
        delay: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(tint)

            Spacer(minLength: 2)

            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.54))

            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 112)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.16),
                            Color.white.opacity(0.055)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.09), lineWidth: 1)
                )
        )
        .offset(y: lifted ? -4 : 4)
        .animation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true).delay(delay), value: lifted)
    }
}

private struct CrewCommunityOnboardingPreview: View {
    @State private var orbit = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(onboardingHex: OnboardingArenaPalette.appPurple).opacity(0.16),
                            Color(onboardingHex: OnboardingArenaPalette.appBlue).opacity(0.10),
                            Color.white.opacity(0.040)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                )

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                        .frame(width: 142, height: 142)

                    Circle()
                        .trim(from: 0, to: 0.28)
                        .stroke(
                            OnboardingArenaPalette.hotGradient,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 142, height: 142)
                        .rotationEffect(.degrees(orbit ? 360 : 0))

                    crewAvatar(offset: CGSize(width: 0, height: -58), icon: "person.fill", tint: Color(onboardingHex: OnboardingArenaPalette.appCyan))
                    crewAvatar(offset: CGSize(width: 54, height: 32), icon: "person.fill", tint: Color(onboardingHex: OnboardingArenaPalette.green))
                    crewAvatar(offset: CGSize(width: -54, height: 32), icon: "person.fill", tint: Color(onboardingHex: OnboardingArenaPalette.gold))

                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.32))
                            .frame(width: 70, height: 70)
                            .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 1))

                        Image(systemName: "person.3.fill")
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(.white)
                    }
                }

                VStack(spacing: 5) {
                    Text("Crew study room")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Focus, tasks and progress in one shared space.")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.52))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 22)
        }
        .frame(height: 236)
        .onAppear {
            withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
                orbit = true
            }
        }
    }

    private func crewAvatar(offset: CGSize, icon: String, tint: Color) -> some View {
        Circle()
            .fill(tint.opacity(0.18))
            .frame(width: 42, height: 42)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(tint)
            )
            .overlay(Circle().stroke(tint.opacity(0.32), lineWidth: 1))
            .offset(offset)
    }
}

private struct FeatureOverviewGridItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white.opacity(0.22))
        }
        .padding(12)
        .background(CardSurface(radius: 24))
    }
}

private struct PremiumInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    var tint: Color = Color(onboardingHex: OnboardingArenaPalette.appBlue)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.68))

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 24)

                TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.30)))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .submitLabel(.done)
            }
            .padding(.horizontal, 15)
            .frame(height: 56)
            .background(CardSurface(radius: 21))
        }
    }
}

private struct InlineAddInput: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    let tint: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(tint)
                    .frame(width: 24)

                TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.white.opacity(0.30)))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .submitLabel(.done)

                Button(action: action) {
                    ZStack {
                        Circle()
                            .fill(tint)
                            .frame(width: 42, height: 42)

                        if isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.78)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(.black.opacity(0.72))
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
            .padding(.horizontal, 15)
            .frame(height: 64)
            .background(CardSurface(radius: 23))
        }
    }
}

private struct CrewStylePicker: View {
    @Binding var selectedIcon: String
    @Binding var selectedColorHex: String

    private let icons = [
        "person.3.fill", "person.2.fill", "bolt.fill", "book.fill",
        "graduationcap.fill", "briefcase.fill", "laptopcomputer", "target",
        "checklist", "calendar", "flame.fill", "star.fill"
    ]

    private let colors = [
        "#4F8CFF", "#7C3AED", "#EC4899", "#22C55E",
        "#F97316", "#06B6D4", "#A855F7", "#EF4444"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Crew görünümü")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(icons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(selectedIcon == icon ? .white : .white.opacity(0.52))
                                .frame(width: 50, height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .fill(
                                            selectedIcon == icon
                                            ? Color.updoHex(selectedColorHex).opacity(0.34)
                                            : Color.white.opacity(0.075)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .stroke(
                                            selectedIcon == icon
                                            ? Color.updoHex(selectedColorHex)
                                            : Color.white.opacity(0.07),
                                            lineWidth: 1.2
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                ForEach(colors, id: \.self) { hex in
                    Button {
                        selectedColorHex = hex
                    } label: {
                        Circle()
                            .fill(Color.updoHex(hex))
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(
                                        Color.white.opacity(selectedColorHex == hex ? 0.9 : 0.12),
                                        lineWidth: selectedColorHex == hex ? 3 : 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(CardSurface(radius: 26))
    }
}

private struct PremiumPrimaryMiniButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(tint.opacity(0.18))
                    .frame(width: 54, height: 54)

                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(tint)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white.opacity(0.32))
        }
        .padding(14)
        .background(CardSurface(radius: 25))
    }
}

private struct OnboardingInfoCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.54))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(CardSurface(radius: 24))
    }
}

private struct OnboardingProfilePreviewCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let trailingText: String

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(tint.opacity(0.18))
                    .frame(width: 58, height: 58)

                Image(systemName: icon)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.52))
            }

            Spacer()

            Text(trailingText)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(tint.opacity(0.13), in: Capsule())
        }
        .padding(14)
        .background(CardSurface(radius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }
}

private struct ScheduleModeCompactCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(tint)

                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(isSelected ? tint : .white.opacity(0.26))
            }
            .padding(13)
            .background(CardSurface(radius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.55) : .white.opacity(0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct StepperPill: View {
    let title: String
    let value: String
    let minus: () -> Void
    let plus: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: minus) {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.08), in: Circle())
            }

            VStack(spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))

                Text(value)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)

            Button(action: plus) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.08), in: Circle())
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(CardSurface(radius: 20))
    }
}

private struct OnboardingActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 52, height: 52)

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.82)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(tint)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.54))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(.white.opacity(0.32))
        }
        .padding(13)
        .background(CardSurface(radius: 24))
    }
}

private struct StatusCard: View {
    let text: String
    let isSuccess: Bool

    var tint: Color {
        isSuccess
        ? Color(onboardingHex: OnboardingArenaPalette.green)
        : Color(onboardingHex: OnboardingArenaPalette.gold)
    }

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(tint)

            Text(text)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(tint.opacity(0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
    }
}

private struct CardSurface: View {
    var radius: CGFloat = 26

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(OnboardingArenaPalette.softCardGradient)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(.white.opacity(0.075), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.20), radius: 14, y: 8)
    }
}

private struct OnboardingArenaBackground: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(onboardingHex: OnboardingArenaPalette.backgroundTop),
                    Color(onboardingHex: OnboardingArenaPalette.backgroundMid),
                    Color(onboardingHex: OnboardingArenaPalette.backgroundBottom)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(onboardingHex: OnboardingArenaPalette.appBlue).opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 100)
                .offset(x: 170, y: -250)

            Circle()
                .fill(Color(onboardingHex: OnboardingArenaPalette.appPurple).opacity(0.16))
                .frame(width: 330, height: 330)
                .blur(radius: 115)
                .offset(x: -180, y: 500)

            Circle()
                .fill(Color(onboardingHex: OnboardingArenaPalette.coral).opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 105)
                .offset(x: 170, y: 300)

            Circle()
                .fill(Color(onboardingHex: OnboardingArenaPalette.gold).opacity(0.050))
                .frame(width: 240, height: 240)
                .blur(radius: 95)
                .offset(x: -170, y: -180)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.44)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

private struct OnboardingPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

// MARK: - Haptics

private enum OnboardingHaptics {
    static func softTap() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.72)
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
}

// MARK: - Color Helper

private extension Color {
    static func updoHex(_ hex: String) -> Color {
        Color(onboardingHex: hex)
    }

    init(onboardingHex hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")

        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch cleaned.count {
        case 3:
            a = 255
            r = (int >> 8) * 17
            g = ((int >> 4) & 0xF) * 17
            b = (int & 0xF) * 17

        case 6:
            a = 255
            r = int >> 16
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        case 8:
            a = int >> 24
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        default:
            a = 255
            r = 21
            g = 147
            b = 255
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
