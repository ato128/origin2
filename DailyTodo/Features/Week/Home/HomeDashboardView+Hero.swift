//
//  HomeDashboardView+Hero.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 30.03.2026.
//

import SwiftUI

enum HomeHeroKind: String {
    case sharedFocusActive
    case personalFocusActive
    case overdueTask
    case nextClass
    case todayPriorityTask
    case upcomingExam
    case socialFollowUp
    case crewFollowUp
    case insightsFollowUp
    case noTaskPrompt
    case wrapUp
}

struct HomeHeroCandidate: Identifiable {
    let id = UUID()
    let kind: HomeHeroKind
    let priority: Int
    let state: TodayHeroState
}

struct HeroBadge {
    let icon: String
    let text: String
    let tint: Color
}

struct HeroCTA {
    let title: String
    let icon: String
    let action: () -> Void
}

struct TodayHeroState {
    let eyebrow: String
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color

    let badge1: HeroBadge?
    let badge2: HeroBadge?

    let contextLine: String

    let primaryCTA: String
    let primaryIcon: String
    let primaryAction: () -> Void

    let secondaryCTA: HeroCTA?
}

extension HomeDashboardView {

    enum HeroDayPhase {
        case morning
        case afternoon
        case evening
        case night
    }

    var todayHeroCard: some View {
        let state = resolveHeroState()
        let heroKind = resolvedHeroKind

        return VStack(alignment: .leading, spacing: 14) {
            topHeroHeader(state: state)
                .id("hero-header-\(heroKind.rawValue)")

            heroBadgesRow(state: state)
                .id("hero-badges-\(heroKind.rawValue)")

            if !state.contextLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                heroContextRow(text: state.contextLine, accent: state.accent)
                    .id("hero-context-\(heroKind.rawValue)")
            }

            heroActionsRow(state: state)
                .id("hero-actions-\(heroKind.rawValue)")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground(accent: state.accent))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(state.accent.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: state.accent.opacity(0.10), radius: 14, y: 6)
        .contentTransition(.identity)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: heroKind)
        .animation(.easeInOut(duration: 0.28), value: state.title)
        .animation(.easeInOut(duration: 0.28), value: state.subtitle)
        .animation(.easeInOut(duration: 0.28), value: state.contextLine)
        .animation(.easeInOut(duration: 0.30), value: state.accent)
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.985).combined(with: .opacity),
                removal: .opacity
            )
        )
        .id("hero-card-\(heroKind.rawValue)")
    }

    var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    var heroDayPhase: HeroDayPhase {
        switch currentHour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        case 17..<22:
            return .evening
        default:
            return .night
        }
    }

    var hasRecentFriendConversation: Bool {
        recentChatFriend != nil
    }

    var socialFollowUpTitle: String {
        if let friend = recentChatFriend {
            return "\(friend.name) ile devam et"
        }
        return "Sosyal akışa göz at"
    }

    var isNextClassLiveNow: Bool {
        guard let nextEvent else { return false }
        let now = currentMinuteOfDay()
        let start = nextEvent.startMinute
        let end = nextEvent.startMinute + nextEvent.durationMinute
        return now >= start && now < end
    }

    var isNextClassStartingSoon: Bool {
        guard let nextEvent else { return false }
        let now = currentMinuteOfDay()
        let diff = nextEvent.startMinute - now
        return diff > 0 && diff <= 20
    }

    var nextClassStartsInMinutes: Int? {
        guard let nextEvent else { return nil }
        let now = currentMinuteOfDay()
        let diff = nextEvent.startMinute - now
        return diff > 0 ? diff : nil
    }

    var nextEventTimeText: String {
        guard let event = nextEvent else { return "Bugün" }
        return "\(hm(event.startMinute)) • \(event.durationMinute) dk"
    }

    var hasNoTaskAtAllToday: Bool {
        todayBoardTasks.isEmpty
    }

    var shouldShowNoTaskPromptHero: Bool {
        hasNoTaskAtAllToday &&
        !isFocusActive &&
        !hasAnyActiveFocusSession &&
        activeBackendCrewFocusSession == nil &&
        !hasRecentFriendConversation &&
        !hasCrewWorkToDo
    }

    var wrapUpHeroTitle: String {
        switch heroDayPhase {
        case .morning:
            return "Bugün temiz başladı"
        case .afternoon:
            return "Her şey kontrol altında"
        case .evening:
            return "Gün sakin ilerliyor"
        case .night:
            return "Bugünü kapatabilirsin"
        }
    }

    var wrapUpHeroSubtitle: String {
        switch heroDayPhase {
        case .morning:
            return "Şimdilik kritik bir görev görünmüyor."
        case .afternoon:
            return "Bugün için kritik bir görev görünmüyor."
        case .evening:
            return "İstersen yarını planlayarak akışı hafifletebilirsin."
        case .night:
            return "Bugünün yükü büyük ölçüde bitti. İstersen yarını hazırlayabilirsin."
        }
    }

    var wrapUpHeroContextLine: String {
        switch heroDayPhase {
        case .morning:
            return "İstersen haftaya hızlıca göz atabilir ya da küçük bir başlangıç yapabilirsin."
        case .afternoon:
            return "İstersen haftaya hızlıca göz atabilir ya da yeni görev ekleyebilirsin."
        case .evening:
            return "Kısa bir plan, yarına daha rahat başlamanı sağlar."
        case .night:
            return "Günü kapatmadan önce yarın için küçük bir düzen kurmak iyi gelir."
        }
    }

    var wrapUpPrimaryCTA: String {
        switch heroDayPhase {
        case .morning, .afternoon:
            return "Haftayı Aç"
        case .evening, .night:
            return "Yarını Planla"
        }
    }

    var wrapUpPrimaryIcon: String {
        switch heroDayPhase {
        case .morning, .afternoon:
            return "calendar"
        case .evening, .night:
            return "calendar.badge.plus"
        }
    }

    var noTaskPromptHeroState: TodayHeroState {
        switch heroDayPhase {
        case .morning:
            return TodayHeroState(
                eyebrow: "Temiz başlangıç",
                title: "Bugünü netleştir",
                subtitle: "Henüz görev görünmüyor. Küçük bir başlangıç günü daha anlamlı hale getirir.",
                icon: "sparkles",
                accent: .blue,
                badge1: HeroBadge(
                    icon: "sun.max.fill",
                    text: "Sabah",
                    tint: .orange
                ),
                badge2: HeroBadge(
                    icon: "checklist",
                    text: "Plan açık",
                    tint: .blue
                ),
                contextLine: "İlk görevini belirlemek gün içinde neye odaklanacağını netleştirir.",
                primaryCTA: "Görev Ekle",
                primaryIcon: "plus",
                primaryAction: {
                    onAddTask()
                },
                secondaryCTA: HeroCTA(
                    title: "Haftaya Bak",
                    icon: "calendar",
                    action: {
                        onOpenWeek()
                    }
                )
            )

        case .afternoon:
            return TodayHeroState(
                eyebrow: "Henüz plan oluşmadı",
                title: "Günü hareket ettir",
                subtitle: "Bugün için görev görünmüyor. Tek bir küçük görev bile ritmi başlatabilir.",
                icon: "bolt.fill",
                accent: .green,
                badge1: HeroBadge(
                    icon: "clock.fill",
                    text: "Öğle",
                    tint: .orange
                ),
                badge2: HeroBadge(
                    icon: "checklist",
                    text: "Boş akış",
                    tint: .green
                ),
                contextLine: "Kısa ve yönetilebilir bir görev eklemek günün boşa gitmiş hissini azaltır.",
                primaryCTA: "Görev Ekle",
                primaryIcon: "plus",
                primaryAction: {
                    onAddTask()
                },
                secondaryCTA: HeroCTA(
                    title: "Hafta",
                    icon: "calendar",
                    action: {
                        onOpenWeek()
                    }
                )
            )

        case .evening, .night:
            return TodayHeroState(
                eyebrow: "Akşam kapanışı",
                title: "Yarını boş bırakma",
                subtitle: "Bugün için görev görünmüyor. Yarın için 1–2 küçük adım belirlemek iyi olabilir.",
                icon: "calendar.badge.plus",
                accent: .purple,
                badge1: HeroBadge(
                    icon: "moon.stars.fill",
                    text: "Akşam",
                    tint: .purple
                ),
                badge2: HeroBadge(
                    icon: "calendar",
                    text: "Yarın",
                    tint: .blue
                ),
                contextLine: "Şimdi yapılan küçük bir plan, yarın sabah karar yorgunluğunu azaltır.",
                primaryCTA: "Yarını Planla",
                primaryIcon: "calendar.badge.plus",
                primaryAction: {
                    onOpenWeek()
                },
                secondaryCTA: HeroCTA(
                    title: "Görev Ekle",
                    icon: "plus",
                    action: {
                        onAddTask()
                    }
                )
            )
        }
    }

    func sharedFocusHeroState(_ activeSession: CrewFocusSessionDTO) -> TodayHeroState {
        TodayHeroState(
            eyebrow: "Ortak odak aktif",
            title: activeSession.title,
            subtitle: "\(activeSession.host_name) ile oturum devam ediyor.",
            icon: activeSession.is_paused ? "pause.fill" : "person.2.fill",
            accent: activeSession.is_paused ? .orange : .blue,
            badge1: HeroBadge(
                icon: "timer",
                text: backendCrewFocusTimeText(for: activeSession, now: Date()),
                tint: activeSession.is_paused ? .orange : .blue
            ),
            badge2: HeroBadge(
                icon: "person.2.fill",
                text: "Crew",
                tint: .pink
            ),
            contextLine: activeSession.is_paused
                ? "Ortak oturum duraklatılmış. Devam ettirip akışı geri kazan."
                : "Şu an ekip odağı aktif. Odaya girip birlikte devam edebilirsin.",
            primaryCTA: "Odayı Aç",
            primaryIcon: "arrow.right.circle.fill",
            primaryAction: {
                focusRoomSession = activeSession
            },
            secondaryCTA: HeroCTA(
                title: "Crew",
                icon: "person.3.fill",
                action: {
                    onOpenWeek()
                }
            )
        )
    }

    var personalFocusFollowUpHeroState: TodayHeroState {
        let title = activeFocusTaskTitle.isEmpty ? "Odak devam ediyor" : activeFocusTaskTitle

        return TodayHeroState(
            eyebrow: "Akış sürüyor",
            title: title,
            subtitle: "Şimdilik sadece ritmi koru. Sonraki adımı sonra seçersin.",
            icon: focusWorkoutMode ? "figure.strengthtraining.traditional" : "sparkles",
            accent: .blue,
            badge1: HeroBadge(
                icon: "scope",
                text: "Odak açık",
                tint: .blue
            ),
            badge2: HeroBadge(
                icon: "calendar",
                text: "Bugün",
                tint: .blue
            ),
            contextLine: "İstersen görevlerini ya da haftayı hızlıca gözden geçirebilirsin.",
            primaryCTA: "Devam Et",
            primaryIcon: "play.fill",
            primaryAction: {
                showTasksShortcut = true
            },
            secondaryCTA: HeroCTA(
                title: "Hafta",
                icon: "calendar",
                action: {
                    onOpenWeek()
                }
            )
        )
    }

    func nextClassHeroState(_ event: EventItem) -> TodayHeroState {
        let accent = hexColor(event.colorHex)

        let subtitle: String
        let context: String
        let primaryCTA: String

        if isNextClassLiveNow {
            subtitle = "Şu an \(event.title) dersindesin."
            context = "Ders bitince öncelikli görevine dönmek için ritmini koru."
            primaryCTA = "Haftayı Aç"
        } else {
            let minutes = nextClassStartsInMinutes ?? 0
            subtitle = "\(minutes) dk sonra \(event.title) başlıyor."
            context = "Ders başlamadan önce zihnini toparlamak iyi olabilir."
            primaryCTA = "Programa Git"
        }

        return TodayHeroState(
            eyebrow: isNextClassLiveNow ? "Şu an aktif" : "Sıradaki ders",
            title: event.title,
            subtitle: subtitle,
            icon: "book.closed.fill",
            accent: accent,
            badge1: HeroBadge(
                icon: isNextClassLiveNow ? "dot.radiowaves.left.and.right" : "clock.fill",
                text: nextEventTimeText,
                tint: accent
            ),
            badge2: HeroBadge(
                icon: "calendar",
                text: "Bugün",
                tint: .blue
            ),
            contextLine: context,
            primaryCTA: primaryCTA,
            primaryIcon: "calendar",
            primaryAction: {
                onOpenWeek()
            },
            secondaryCTA: HeroCTA(
                title: "Görevler",
                icon: "list.bullet",
                action: {
                    showTasksShortcut = true
                }
            )
        )
    }

    var socialFollowUpHeroState: TodayHeroState {
        let title = socialFollowUpTitle
        let subtitle: String

        if recentChatFriend != nil {
            subtitle = "Son konuşma hâlâ sıcak. İstersen kaldığın yerden devam et."
        } else {
            subtitle = "Arkadaşlarınla bağlantıda kalmak motivasyonu koruyabilir."
        }

        return TodayHeroState(
            eyebrow: "Sosyal akış",
            title: title,
            subtitle: subtitle,
            icon: "bubble.left.and.bubble.right.fill",
            accent: .blue,
            badge1: HeroBadge(
                icon: "message.fill",
                text: "Sohbet",
                tint: .blue
            ),
            badge2: HeroBadge(
                icon: "person.2.fill",
                text: "Arkadaşlar",
                tint: .pink
            ),
            contextLine: "Kısa bir mesaj bile seni tekrar uygulamanın akışına bağlayabilir.",
            primaryCTA: "Sohbeti Aç",
            primaryIcon: "bubble.left.and.bubble.right.fill",
            primaryAction: {
                if recentChatFriend != nil {
                    showRecentFriendChat = true
                } else {
                    showFriendsShortcut = true
                }
            },
            secondaryCTA: HeroCTA(
                title: "Crew",
                icon: "person.3.fill",
                action: {
                    onOpenWeek()
                }
            )
        )
    }

    var hasAnyCompletedTaskToday: Bool {
        completedTodayCount > 0
    }

    var hasNoCompletedTaskToday: Bool {
        completedTodayCount == 0
    }

    var shouldShowNightPlanningHero: Bool {
        currentHour >= 20 && todayPendingBoardCount == 0 && !hasNoTaskAtAllToday
    }

    var shouldShowLowMomentumHero: Bool {
        currentHour >= 14 && hasNoCompletedTaskToday && todayPendingBoardCount > 0
    }

    var latestCompletedTodayTaskTitle: String? {
        todayCompletedTasks
            .sorted {
                ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
            }
            .first?
            .title
    }

    var completionFollowUpHeroStateV2: TodayHeroState {
        let completedTitle = latestCompletedTodayTaskTitle ?? "Görev"

        return TodayHeroState(
            eyebrow: "Güzel ilerliyorsun",
            title: "\(completedTitle) tamamlandı",
            subtitle: "Bugün bir adım attın. İstersen akışı devam ettirelim.",
            icon: "checkmark.circle.fill",
            accent: .green,
            badge1: HeroBadge(
                icon: "checkmark.circle.fill",
                text: "Tamamlandı",
                tint: .green
            ),
            badge2: HeroBadge(
                icon: "flame.fill",
                text: "Seri \(streakCount)",
                tint: .orange
            ),
            contextLine: "Şimdi istersen kalan işlere bakabilir, crew’e geçebilir ya da içgörülerini açabilirsin.",
            primaryCTA: todayPendingBoardCount > 0 ? "Kalanlara Bak" : "İçgörülere Git",
            primaryIcon: todayPendingBoardCount > 0 ? "list.bullet" : "chart.bar.fill",
            primaryAction: {
                if todayPendingBoardCount > 0 {
                    showTasksShortcut = true
                } else {
                    onOpenInsights()
                }
            },
            secondaryCTA: HeroCTA(
                title: hasCrewWorkToDo ? "Crew" : "Hafta",
                icon: hasCrewWorkToDo ? "person.3.fill" : "calendar",
                action: {
                    onOpenWeek()
                }
            )
        )
    }

    var nightPlanningHeroStateV2: TodayHeroState {
        TodayHeroState(
            eyebrow: "Günü kapat",
            title: "Yarını hafiflet",
            subtitle: "Bugün büyük ölçüde tamam. Küçük bir plan yarına çok şey katar.",
            icon: "moon.stars.fill",
            accent: .purple,
            badge1: HeroBadge(
                icon: "calendar.badge.plus",
                text: "Yarın",
                tint: .purple
            ),
            badge2: HeroBadge(
                icon: "checkmark.circle.fill",
                text: "Bugün temiz",
                tint: .green
            ),
            contextLine: "Yarın için 1–2 net adım belirlemek sabah karar yorgunluğunu azaltır.",
            primaryCTA: "Yarını Planla",
            primaryIcon: "calendar.badge.plus",
            primaryAction: {
                onOpenWeek()
            },
            secondaryCTA: HeroCTA(
                title: "İçgörüler",
                icon: "chart.bar.fill",
                action: {
                    onOpenInsights()
                }
            )
        )
    }

    var lowMomentumHeroStateV2: TodayHeroState {
        TodayHeroState(
            eyebrow: "Küçük bir başlangıç",
            title: "Bugünü hareket ettir",
            subtitle: "Henüz tamamlanan bir iş yok. Tek bir küçük görev bile akışı başlatabilir.",
            icon: "bolt.fill",
            accent: .orange,
            badge1: HeroBadge(
                icon: "exclamationmark.circle.fill",
                text: "Başlangıç lazım",
                tint: .orange
            ),
            badge2: HeroBadge(
                icon: "list.bullet",
                text: "\(todayPendingBoardCount) açık",
                tint: .blue
            ),
            contextLine: "Mükemmel olmak zorunda değil. Kısa bir başlangıç momentum üretir.",
            primaryCTA: "Görevleri Aç",
            primaryIcon: "list.bullet",
            primaryAction: {
                showTasksShortcut = true
            },
            secondaryCTA: HeroCTA(
                title: "Odak Başlat",
                icon: "play.fill",
                action: {
                    startInlineFocus()
                }
            )
        )
    }

    func overdueTaskHeroState(_ task: DTTaskItem) -> TodayHeroState {
        let accent = Color.red
        let course = task.courseName.trimmingCharacters(in: .whitespacesAndNewlines)

        return TodayHeroState(
            eyebrow: "Önce bunu temizle",
            title: task.title,
            subtitle: "Bu görev gecikmiş. Önce bunu temizlemek iyi olur.",
            icon: focusSymbol(for: task),
            accent: accent,
            badge1: HeroBadge(
                icon: "exclamationmark.triangle.fill",
                text: "Gecikmiş",
                tint: accent
            ),
            badge2: course.isEmpty ? nil : HeroBadge(
                icon: "book.closed.fill",
                text: course,
                tint: accent
            ),
            contextLine: priorityTaskContextLine(for: task),
            primaryCTA: "Başla",
            primaryIcon: "play.fill",
            primaryAction: {
                startInlineFocus()
            },
            secondaryCTA: HeroCTA(
                title: "Tüm Görevler",
                icon: "list.bullet",
                action: {
                    showTasksShortcut = true
                }
            )
        )
    }

    func priorityTaskHeroState(_ task: DTTaskItem) -> TodayHeroState {
        let accent = focusAccentColor(for: task)
        let course = task.courseName.trimmingCharacters(in: .whitespacesAndNewlines)

        return TodayHeroState(
            eyebrow: "Bugünün önceliği",
            title: task.title,
            subtitle: focusCardStatusTextStudent,
            icon: focusSymbol(for: task),
            accent: accent,
            badge1: HeroBadge(
                icon: "scope",
                text: dueBadgeText(for: task),
                tint: accent
            ),
            badge2: course.isEmpty ? nil : HeroBadge(
                icon: "book.closed.fill",
                text: course,
                tint: accent
            ),
            contextLine: priorityTaskContextLine(for: task),
            primaryCTA: "Başla",
            primaryIcon: "play.fill",
            primaryAction: {
                startInlineFocus()
            },
            secondaryCTA: HeroCTA(
                title: "Tüm Görevler",
                icon: "list.bullet",
                action: {
                    showTasksShortcut = true
                }
            )
        )
    }

    func priorityTaskContextLine(for task: DTTaskItem) -> String {
        if store.isOverdue(task) {
            switch heroDayPhase {
            case .morning:
                return "Güne bunu temizleyerek başlamak geri kalanını rahatlatır."
            case .afternoon:
                return "Bunu bitirmen günün geri kalanını rahatlatır."
            case .evening:
                return "Akşam kapanmadan bunu temizlemek iyi olur."
            case .night:
                return "Bunu kapatıp günü daha hafif bitirebilirsin."
            }
        }

        switch heroDayPhase {
        case .morning:
            return "Erken başlarsan gün dağılmadan momentum kazanırsın."
        case .afternoon:
            return "Şimdi başlarsan gün dağılmadan momentum kazanırsın."
        case .evening:
            return "Bugün bitirmen akşamı daha rahatlatır."
        case .night:
            return "Kısa bir başlangıç bile yarını kolaylaştırır."
        }
    }

    func buildHeroCandidates() -> [HomeHeroCandidate] {
        var candidates: [HomeHeroCandidate] = []

        if let activeSession = activeBackendCrewFocusSession {
            candidates.append(
                HomeHeroCandidate(
                    kind: .sharedFocusActive,
                    priority: 100,
                    state: sharedFocusHeroState(activeSession)
                )
            )
        }

        if isFocusActive || hasAnyActiveFocusSession {
            candidates.append(
                HomeHeroCandidate(
                    kind: .personalFocusActive,
                    priority: 95,
                    state: personalFocusFollowUpHeroState
                )
            )
        }

        if let overdue = todayPendingTasks.first(where: { store.isOverdue($0) }) {
            candidates.append(
                HomeHeroCandidate(
                    kind: .overdueTask,
                    priority: 90,
                    state: overdueTaskHeroState(overdue)
                )
            )
        }

        if let event = nextEvent, isNextClassLiveNow || isNextClassStartingSoon {
            candidates.append(
                HomeHeroCandidate(
                    kind: .nextClass,
                    priority: isNextClassLiveNow ? 82 : 70,
                    state: nextClassHeroState(event)
                )
            )
        }

        if let task = focusTask {
            candidates.append(
                HomeHeroCandidate(
                    kind: .todayPriorityTask,
                    priority: 75,
                    state: priorityTaskHeroState(task)
                )
            )
        }

        if shouldShowLowMomentumHero {
            candidates.append(
                HomeHeroCandidate(
                    kind: .todayPriorityTask,
                    priority: 65,
                    state: lowMomentumHeroStateV2
                )
            )
        }

        if hasAnyCompletedTaskToday && todayPendingBoardCount == 0 {
            candidates.append(
                HomeHeroCandidate(
                    kind: .insightsFollowUp,
                    priority: 52,
                    state: completionFollowUpHeroStateV2
                )
            )
        }

        if hasCompletedAllPersonalTodayTasks && hasCrewWorkToDo {
            candidates.append(
                HomeHeroCandidate(
                    kind: .crewFollowUp,
                    priority: 60,
                    state: crewFollowUpHeroState
                )
            )
        }

        if hasCompletedAllPersonalTodayTasks && hasRecentFriendConversation {
            candidates.append(
                HomeHeroCandidate(
                    kind: .socialFollowUp,
                    priority: 50,
                    state: socialFollowUpHeroState
                )
            )
        }

        if hasCompletedAllPersonalTodayTasks && hasInsightsWorthShowing {
            candidates.append(
                HomeHeroCandidate(
                    kind: .insightsFollowUp,
                    priority: 45,
                    state: insightsFollowUpHeroState
                )
            )
        }

        if shouldShowNoTaskPromptHero {
            candidates.append(
                HomeHeroCandidate(
                    kind: .noTaskPrompt,
                    priority: 46,
                    state: noTaskPromptHeroState
                )
            )
        }

        if shouldShowNightPlanningHero {
            candidates.append(
                HomeHeroCandidate(
                    kind: .wrapUp,
                    priority: 48,
                    state: nightPlanningHeroStateV2
                )
            )
        }

        candidates.append(
            HomeHeroCandidate(
                kind: .wrapUp,
                priority: 10,
                state: wrapUpHeroState
            )
        )

        return candidates
    }

    func resolveHeroState() -> TodayHeroState {
        let candidates = buildHeroCandidates()
        let best = candidates.max { $0.priority < $1.priority }
        return best?.state ?? wrapUpHeroState
    }
    
    func upcomingExamHeroState(_ exam: ExamItem) -> TodayHeroState {
        let accent = examAccentColor(exam)
        let minutes = suggestedStudyMinutes(for: exam)
        let label = suggestedStudyLabel(for: exam)

        return TodayHeroState(
            eyebrow: "Yaklaşan sınav",
            title: "\(exam.courseName.isEmpty ? exam.title : exam.courseName) \(exam.examType)",
            subtitle: "\(examCountdownText(exam)) • Bugün \(minutes) dk \(label.lowercased()) iyi olabilir.",
            icon: "graduationcap.fill",
            accent: accent,
            badge1: HeroBadge(
                icon: "calendar",
                text: examDateText(exam),
                tint: accent
            ),
            badge2: HeroBadge(
                icon: "timer",
                text: "\(minutes) dk",
                tint: .orange
            ),
            contextLine: "Sınava yaklaşırken küçük ama net bir çalışma bloğu stresi azaltır.",
            primaryCTA: "Başlat",
            primaryIcon: "play.fill",
            primaryAction: {
                startSuggestedExamFocus(for: exam)
            },
            secondaryCTA: HeroCTA(
                title: "Planla",
                icon: "calendar.badge.plus",
                action: {
                    onOpenWeek()
                }
            )
        )
    }

    @ViewBuilder
    func topHeroHeader(state: TodayHeroState) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(state.eyebrow)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.secondaryText)
                    .contentTransition(.opacity)

                Text(state.title)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)

                Text(state.subtitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.secondaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Circle()
                    .fill(state.accent.opacity(0.12))
                    .frame(width: 44, height: 44)

                Circle()
                    .stroke(state.accent.opacity(0.16), lineWidth: 1)
                    .frame(width: 44, height: 44)

                Image(systemName: state.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(state.accent)
            }
            .padding(.top, 2)
            .scaleEffect(1.0)
            .animation(.spring(response: 0.36, dampingFraction: 0.82), value: state.icon)
            .animation(.easeInOut(duration: 0.30), value: state.accent)
        }
    }

    @ViewBuilder
    func heroBadgesRow(state: TodayHeroState) -> some View {
        HStack(spacing: 8) {
            if let badge1 = state.badge1 {
                miniBadge(icon: badge1.icon, text: badge1.text, tint: badge1.tint)
            }

            if let badge2 = state.badge2 {
                miniBadge(icon: badge2.icon, text: badge2.text, tint: badge2.tint)
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    func heroContextRow(text: String, accent: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(accent)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(palette.secondaryText)
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(accent.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.10), lineWidth: 1)
        )
    }

    @ViewBuilder
    func heroActionsRow(state: TodayHeroState) -> some View {
        HStack(spacing: 10) {
            Button {
                state.primaryAction()
            } label: {
                Label(state.primaryCTA, systemImage: state.primaryIcon)
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        state.accent,
                                        state.accent.opacity(0.88)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .foregroundStyle(.white)
                    .shadow(color: state.accent.opacity(0.20), radius: 10, y: 4)
                    .contentTransition(.opacity)
            }
            .buttonStyle(.plain)

            if let secondaryCTA = state.secondaryCTA {
                Button {
                    secondaryCTA.action()
                } label: {
                    Label(secondaryCTA.title, systemImage: secondaryCTA.icon)
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            Capsule()
                                .fill(state.accent.opacity(0.12))
                        )
                        .overlay(
                            Capsule()
                                .stroke(state.accent.opacity(0.14), lineWidth: 1)
                        )
                        .foregroundStyle(state.accent)
                        .contentTransition(.opacity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    func heroBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(palette.cardFill)
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                accent.opacity(0.12),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 10,
                            endRadius: 240
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(appTheme == AppTheme.light.rawValue ? 0.06 : 0.04),
                                Color.clear,
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }
}
