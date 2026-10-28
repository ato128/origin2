//
//  BackendCrewDetailView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 19.03.2026.
//

import SwiftUI
import UIKit
import SwiftData
import PhotosUI

/// Cross-tab hand-offs into a crew: "Birlikte odaklan" preselects the crew on
/// the Focus tab, a nudge push opens the crew's page. Tabs are rebuilt on
/// switch, so the target is parked here and taken when the screen appears.
enum CrewDeepLink {
    static var pendingFocusCrewID: UUID?
    static var pendingDetailCrewID: UUID?

    static func takeFocusCrew() -> UUID? {
        defer { pendingFocusCrewID = nil }
        return pendingFocusCrewID
    }

    static func takeDetailCrew() -> UUID? {
        defer { pendingDetailCrewID = nil }
        return pendingDetailCrewID
    }
}

extension Notification.Name {
    /// object: crew id (String) — Social tab opens that crew.
    static let openCrewDetail = Notification.Name("openCrewDetail")
}

/// One crewmate, with everything the page shows about them precomputed.
private struct CrewMateStat: Identifiable {
    let member: CrewMemberDTO
    let name: String
    let firstName: String
    let weekMinutes: Int
    let todayMinutes: Int
    let isMe: Bool
    let isOwner: Bool
    let isFocusing: Bool
    let focusingSince: Date?
    let isOnline: Bool
    let color: Color

    var id: UUID { member.user_id }
}

struct BackendCrewDetailView: View {
    let crew: CrewDTO

    @Environment(\.dismiss) private var dismiss
    /// iPad Social split: this screen is the detail column — no back
    /// button, and "leaving" clears the selection instead of popping.
    @Environment(\.socialSplitClose) private var socialSplitClose

    private func leave() {
        if let socialSplitClose { socialSplitClose() } else { dismiss() }
    }
    @EnvironmentObject var crewStore: CrewStore
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var friendStore: FriendStore

    @State private var showAddMember = false
    @State private var showCreateTask = false
    @State private var showInviteSheet = false
    @State private var selectedTask: CrewTaskDTO?

    @State private var inviteCode = ""
    @State private var invitedFriendIDs: Set<UUID> = []
    @State private var sendingInviteFriendID: UUID?

    @Query(sort: \Friend.createdAt, order: .reverse)
    private var allLocalFriends: [Friend]
    @State private var errorMessage: String?

    @State private var showShareSheet = false
    @State private var didInitialLoad = false
    @State private var memberToRemove: CrewMemberDTO?
    @State private var showRemoveMemberConfirm = false
    @State private var inviteCopied = false
    @State private var showDeleteCrewConfirm = false
    @State private var isDeletingCrew = false
    @State private var crewPhotoItem: PhotosPickerItem?
    @State private var showDoneTasks = false
    @State private var weeklyGoalMinutes = 0

    @State private var ringProgress: Double = 0
    @State private var appeared = false
    @State private var titleVisible = false
    @State private var nudgedUntil: [UUID: Date] = [:]
    @State private var nudgingID: UUID?
    @State private var toast: String?
    @State private var celebrate = false
    /// iPad: the detail column's width decides stage + two columns vs. the phone stack.
    @State private var pageWidth: CGFloat = 0

    /// iPad only (never iPhone, even a wide Pro Max in landscape).
    private var usesPadLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && pageWidth >= 700
    }
    private var pageGutter: CGFloat { usesPadLayout ? 28 : 16 }

    var body: some View {
        attachDialogs(to: attachSheets(to: page))
    }

    private var page: some View {
        ZStack(alignment: .top) {
            AppBackground()
            ambientGlow

            content(crewMates)
        }
        .safeAreaInset(edge: .top, spacing: 0) { topBar }
        .overlay(alignment: .top) { toastView }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pageWidth = $0 }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            guard !didInitialLoad else { return }
            didInitialLoad = true
            nudgedUntil = loadNudges()
            await loadCrewDetail()
            withAnimation(.spring(response: 0.9, dampingFraction: 0.9)) {
                ringProgress = 1
            }
            celebrateGoalIfNeeded()
        }
        .onAppear {
            weeklyGoalMinutes = crewStore.weeklyGoalMinutes(for: crew.id)
            withAnimation(.easeOut(duration: 0.45)) { appeared = true }
            if didInitialLoad {
                Task { await loadCrewDetail() }
            }
        }
        .onChange(of: crewPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task { await uploadCrewPhoto(newItem) }
        }
        .onReceive(crewStore.$weeklyGoalMinutesByCrew) { byCrew in
            if let shared = byCrew[crew.id], shared != weeklyGoalMinutes {
                weeklyGoalMinutes = shared
            }
        }
        .sensoryFeedback(.success, trigger: celebrate) { _, new in new }
    }

    private func content(_ mates: [CrewMateStat]) -> some View {
        ScrollViewReader { proxy in
        ScrollView(showsIndicators: false) {
            Group {
                if usesPadLayout {
                    padSections(mates)
                } else {
                    phoneSections(mates)
                }
            }
            .padding(.horizontal, pageGutter)
        }
        .onScrollGeometryChange(for: Bool.self) { geo in
            // iPad's stage sits higher on screen — chrome turns solid sooner.
            geo.contentOffset.y + geo.contentInsets.top > (usesPadLayout ? 110 : 190)
        } action: { _, past in
            withAnimation(.easeInOut(duration: 0.2)) { titleVisible = past }
        }
        .refreshable {
            await loadCrewDetail()
        }
        #if DEBUG
        // QA/screenshot hook: `-debugCrewScroll standings` scrolls there.
        .task {
            if let target = UserDefaults.standard.string(forKey: "debugCrewScroll") {
                try? await Task.sleep(for: .seconds(2.5))
                proxy.scrollTo(target, anchor: .top)
            }
        }
        #endif
        }
    }

    private func phoneSections(_ mates: [CrewMateStat]) -> some View {
        VStack(spacing: 18) {
            stage(mates)
                .padding(.top, 4)

            weekCard(mates)
                .crewReveal(appeared, delay: 0.05)
                .id("week")

            if mates.count < 3 {
                completeCrewCard(mates)
                    .crewReveal(appeared, delay: 0.1)
            }

            if mates.count > 1 {
                standingsCard(mates)
                    .crewReveal(appeared, delay: 0.12)
                    .id("standings")
            }

            tasksCard(mates)
                .crewReveal(appeared, delay: 0.16)
                .id("tasks")

            if !recentActivities.isEmpty {
                activityCard
                    .crewReveal(appeared, delay: 0.2)
            }

            Color.clear.frame(height: 90)
        }
    }

    /// iPad: the live stage across the top, then two columns — the crew's
    /// rhythm (week ring, standings) left, shared work (tasks, activity) right.
    private func padSections(_ mates: [CrewMateStat]) -> some View {
        VStack(spacing: 20) {
            padStage(mates)
                .padding(.top, 6)

            HStack(alignment: .top, spacing: 20) {
                VStack(spacing: 20) {
                    weekCard(mates)
                        .crewReveal(appeared, delay: 0.05)
                        .id("week")

                    if mates.count > 1 {
                        standingsCard(mates)
                            .crewReveal(appeared, delay: 0.12)
                            .id("standings")
                    } else {
                        completeCrewCard(mates)
                            .crewReveal(appeared, delay: 0.1)
                    }
                }
                // Ideal height: the timeline's flexible rail must not stretch
                // a column to match the other one.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .top)

                VStack(spacing: 20) {
                    tasksCard(mates)
                        .crewReveal(appeared, delay: 0.08)
                        .id("tasks")

                    if mates.count == 2 {
                        completeCrewCard(mates)
                            .crewReveal(appeared, delay: 0.14)
                    }

                    if !recentActivities.isEmpty {
                        activityCard
                            .crewReveal(appeared, delay: 0.18)
                    }
                }
                // Ideal height: the timeline's flexible rail must not stretch
                // a column to match the other one.
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .top)
            }

            Color.clear.frame(height: 60)
        }
        .frame(maxWidth: 1180)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Loading

    private func loadCrewDetail() async {
        await crewStore.loadMembers(for: crew.id)
        await crewStore.loadMemberProfiles(for: crewStore.crewMembers)

        let memberIDs = crewMembers.map(\.user_id)
        // Crewmates who aren't friends join the presence poll (live "Odakta").
        Task { await friendStore.loadPresence(including: memberIDs) }

        await crewStore.loadActiveFocusSession(for: crew.id)
        if let live = crewStore.activeFocusSessionByCrew[crew.id] {
            await crewStore.loadFocusParticipants(sessionID: live.id)
        }

        await crewStore.loadTasks(for: crew.id)
        await crewStore.loadActivities(for: crew.id)
        await crewStore.loadFocusRecords(for: crew.id)

        #if DEBUG
        // QA/screenshot hook: `-debugCrewMock YES` adds in-memory crewmates,
        // focus minutes and tasks (nothing is written to the backend).
        if UserDefaults.standard.bool(forKey: "debugCrewMock") { injectDebugCrew() }
        #endif
    }

    #if DEBUG
    private func injectDebugCrew() {
        let iso = ISO8601DateFormatter()
        let cal = Calendar.current
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let mates: [(String, String, [Int])] = [
            ("İpek Yılmaz", "ipek", [50, 0, 75, 40, 0, 25, 0]),
            ("Arda Kaya", "arda", [25, 45, 0, 30, 50, 0, 0]),
            ("Deniz Aydın", "deniz", [0, 0, 25, 0, 0, 0, 0])
        ]
        var ids: [UUID] = []
        for (index, mate) in mates.enumerated() {
            let id = UUID()
            ids.append(id)
            crewStore.crewMembers.append(
                CrewMemberDTO(id: UUID(), crew_id: crew.id, user_id: id, role: "member", created_at: "2026-10-2\(index + 1)T10:00:00Z")
            )
            crewStore.memberProfiles.append(ProfileDTO(id: id, email: nil, username: mate.1, full_name: mate.0))
            for (day, minutes) in mate.2.enumerated() where minutes > 0 {
                guard let date = cal.date(byAdding: .hour, value: day * 24 + 15, to: start), date < Date() else { continue }
                crewStore.crewFocusRecords.append(
                    CrewFocusRecordDTO(id: UUID(), crew_id: crew.id, user_id: id, member_name: mate.0, minutes: minutes, created_at: iso.string(from: date))
                )
            }
        }
        if let me = myUserID, let date = cal.date(byAdding: .hour, value: 2 * 24 + 18, to: start) {
            crewStore.crewFocusRecords.append(
                CrewFocusRecordDTO(id: UUID(), crew_id: crew.id, user_id: me, member_name: "Me", minutes: 95, created_at: iso.string(from: date))
            )
        }
        let now = iso.string(from: Date())
        friendStore.presenceByUserID[ids[0]] = FriendPresenceDTO(
            user_id: ids[0], is_online: true, last_seen_at: now, updated_at: now,
            is_focusing: true, focusing_since: iso.string(from: Date().addingTimeInterval(-18 * 60))
        )
        friendStore.presenceByUserID[ids[1]] = FriendPresenceDTO(user_id: ids[1], is_online: true, last_seen_at: now, updated_at: now)
        crewStore.crewTasks.append(contentsOf: [
            CrewTaskDTO(id: UUID(), crew_id: crew.id, created_by: ids[0], title: "Fizik 2. ünite soru bankası", is_done: false, assigned_to: ids[0], created_at: now, details: nil, priority: "high", status: "inProgress", show_on_week: true, scheduled_weekday: 3, scheduled_start_minute: 19 * 60, scheduled_duration_minute: 60),
            CrewTaskDTO(id: UUID(), crew_id: crew.id, created_by: ids[1], title: "Deneme sınavı analizi", is_done: false, assigned_to: myUserID, created_at: now, details: nil, priority: "medium", status: "todo", show_on_week: false, scheduled_weekday: nil, scheduled_start_minute: nil, scheduled_duration_minute: nil),
            CrewTaskDTO(id: UUID(), crew_id: crew.id, created_by: ids[1], title: "Kimya formül kartları", is_done: true, assigned_to: ids[1], created_at: now, details: nil, priority: "low", status: "done", show_on_week: false, scheduled_weekday: nil, scheduled_start_minute: nil, scheduled_duration_minute: nil)
        ])
    }
    #endif

    @MainActor
    private func uploadCrewPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }

        let resized = crewDownscaledImage(image, maxDimension: 512)
        guard let jpeg = resized.jpegData(compressionQuality: 0.82) else { return }

        // Anında yerel gösterim; backend'e yazımı beklemeden.
        RemoteAvatarStore.shared.overrideLocal(resized, for: crew.id)
        crewPhotoItem = nil

        await AvatarBackendClient.shared.uploadCrewAvatar(
            crewID: crew.id.uuidString,
            jpegData: jpeg
        )
    }

    private func crewDownscaledImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let largest = max(image.size.width, image.size.height)
        guard largest > maxDimension else { return image }

        let scale = maxDimension / largest
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

// MARK: - Derived data

private extension BackendCrewDetailView {
    var accent: Color { hexColor(crew.color_hex) }

    var myUserID: UUID? { session.currentUser?.id }

    var isOwner: Bool { myUserID == crew.owner_id }

    var crewMembers: [CrewMemberDTO] {
        crewStore.crewMembers
            .filter { $0.crew_id == crew.id }
            .sorted { ($0.created_at ?? "") < ($1.created_at ?? "") }
    }

    var memberProfilesByID: [UUID: ProfileDTO] {
        Dictionary(crewStore.memberProfiles.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    var crewRecords: [CrewFocusRecordDTO] {
        crewStore.crewFocusRecords.filter { $0.crew_id == crew.id }
    }

    var weekStart: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start
            ?? Calendar.current.startOfDay(for: Date())
    }

    var liveSession: CrewFocusSessionDTO? {
        guard let s = crewStore.activeFocusSessionByCrew[crew.id], s.is_active else { return nil }
        return s
    }

    var liveParticipants: [CrewFocusParticipantDTO] {
        guard let liveSession else { return [] }
        return (crewStore.focusParticipantsBySession[liveSession.id] ?? []).filter(\.is_active)
    }

    /// Fixed per-member colors (join order), so a person keeps their color in
    /// the ring and the standings week after week.
    static let mateColors: [Color] = [
        Color(arenaHex: "#2DD4FF"), Color(arenaHex: "#FF5A44"), Color(arenaHex: "#FBBF24"),
        Color(arenaHex: "#A78BFA"), Color(arenaHex: "#A3E635"), Color(arenaHex: "#1593FF"),
        Color(arenaHex: "#FF7A59"), Color(arenaHex: "#8B5CF6")
    ]

    var crewMates: [CrewMateStat] {
        let cal = Calendar.current
        let start = weekStart
        let todayStart = cal.startOfDay(for: Date())
        let profiles = memberProfilesByID
        let participantIDs = Set(liveParticipants.compactMap(\.user_id))

        var week: [String: Int] = [:]
        var today: [String: Int] = [:]
        for record in crewRecords {
            guard let date = record.created_at.flatMap({ CrewDateParser.parse($0) }), date >= start else { continue }
            let key = record.user_id?.uuidString ?? "name:" + record.member_name
            week[key, default: 0] += record.minutes
            if date >= todayStart { today[key, default: 0] += record.minutes }
        }

        return crewMembers.enumerated().map { index, member in
            let profile = profiles[member.user_id]
            let name = memberName(from: profile)
            let byName = "name:" + name
            let presence = friendStore.presenceByUserID[member.user_id]
            let isMe = member.user_id == myUserID
            let presenceFocusing = presence?.is_focusing ?? false
            // My own state comes from this device; the backend flag can lag.
            let focusing = isMe
                ? FocusSessionManager.shared.isSessionActive
                : participantIDs.contains(member.user_id) || presenceFocusing

            return CrewMateStat(
                member: member,
                name: name,
                firstName: name.split(separator: " ").first.map(String.init) ?? name,
                weekMinutes: (week[member.user_id.uuidString] ?? 0) + (week[byName] ?? 0),
                todayMinutes: (today[member.user_id.uuidString] ?? 0) + (today[byName] ?? 0),
                isMe: isMe,
                isOwner: member.role.lowercased() == "owner",
                isFocusing: focusing,
                focusingSince: isMe
                    ? FocusSessionManager.shared.currentSession?.startDate
                    : presence?.focusing_since.flatMap { CrewDateParser.parse($0) },
                isOnline: isMe || FriendPresenceEngine.isOnline(presence),
                color: Self.mateColors[index % Self.mateColors.count]
            )
        }
    }

    var weekTotalMinutes: Int {
        CrewHomeFormatters.weeklyFocusMinutes(records: crewStore.crewFocusRecords, crewID: crew.id)
    }

    var streakDays: Int {
        CrewHomeFormatters.crewStreakDays(records: crewStore.crewFocusRecords, crewID: crew.id)
    }

    /// The 7 days of this week and whether the crew focused on each.
    var weekDays: [(date: Date, active: Bool)] {
        let cal = Calendar.current
        let days = Set(
            crewRecords
                .compactMap { $0.created_at.flatMap { CrewDateParser.parse($0) } }
                .map { cal.startOfDay(for: $0) }
        )
        return (0..<7).compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return (day, days.contains(day))
        }
    }

    var allTimeMinutes: Int {
        max(crewStore.totalFocusMinutesByCrew[crew.id] ?? 0, crewRecords.reduce(0) { $0 + $1.minutes })
    }

    static let levelTargets = [15, 30, 60, 120, 180, 300, 480, 720, 1080, 1500, 2400, 3600, 6000]

    var crewLevel: Int {
        Self.levelTargets.filter { allTimeMinutes >= $0 }.count + 1
    }

    var sortedCrewTasks: [CrewTaskDTO] {
        crewStore.crewTasks
            .filter { $0.crew_id == crew.id }
            .sorted {
                if $0.is_done != $1.is_done { return !$0.is_done }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    var recentActivities: [CrewActivityDTO] {
        Array(crewStore.crewActivities.filter { $0.crew_id == crew.id }.prefix(5))
    }

    /// Friends not yet in this crew — one tap sends the invite into your 1:1
    /// chat as a join card. No code copying needed on either side.
    var invitableFriends: [Friend] {
        guard let currentUserID = myUserID else { return [] }
        let memberUserIDs = Set(crewMembers.map(\.user_id))

        return allLocalFriends.filter { friend in
            friend.ownerUserID == currentUserID.uuidString
            && friend.backendFriendshipID != nil
            && friend.backendUserID.map { !memberUserIDs.contains($0) } ?? false
        }
    }

    func memberName(from profile: ProfileDTO?) -> String {
        guard let profile else { return String(localized: "backend_crew_unknown_user") }

        if let fullName = profile.full_name,
           !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fullName
        }
        if let username = profile.username,
           !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return username
        }
        return profile.email ?? String(localized: "backend_crew_unknown_user")
    }

    func focusTimeText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if appLanguageIsEnglish() {
            return hours > 0 ? (mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h") : "\(mins)m"
        }
        return hours > 0 ? (mins > 0 ? "\(hours) sa \(mins) dk" : "\(hours) sa") : "\(mins) dk"
    }
}

// MARK: - Updo ink

/// Updo's arena palette for this page. Fills use the vivid arena hexes; text
/// that sits on the page uses the adaptive UpdoTheme tones (readable in light).
private enum CrewInk {
    static let cyan = Color(arenaHex: "#2DD4FF")
    static let blue = Color(arenaHex: "#1593FF")
    static let purple = Color(arenaHex: "#7C3AED")
    static let violet = Color(arenaHex: "#8B5CF6")
    static let coral = Color(arenaHex: "#FF5A44")
    static let gold = Color(arenaHex: "#FBBF24")
    static let lime = Color(arenaHex: "#A3E635")

    static var brand: LinearGradient {
        LinearGradient(colors: [cyan, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private extension BackendCrewDetailView {
    func caps(_ text: String) -> String {
        text.uppercased(with: Locale(identifier: appLanguageIsEnglish() ? "en" : "tr"))
    }

    /// "—— AKTİF EKİP" — the mono eyebrow every Updo section opens with.
    func eyebrow(_ text: String, tint: Color = UpdoTheme.cyan) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(CrewInk.blue)
                .frame(width: 18, height: 1)
            Text(caps(text))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2.2)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    /// Heavy word + serif italic accent ("Ekip *ritmi*").
    func accentTitle(_ title: String, _ accent: String, size: CGFloat = 24) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(title)
                .font(.system(size: size, weight: .black))
                .foregroundStyle(UpdoTheme.textPrimary)
            Text(accent)
                .font(.system(size: size - 1, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(CrewInk.brand)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    func sectionHeader<Trailing: View>(
        eyebrow text: String,
        title: String,
        accent: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                eyebrow(text)
                accentTitle(title, accent)
            }
            Spacer(minLength: 8)
            trailing()
        }
    }

    func mono(_ text: String, size: CGFloat = 11, weight: Font.Weight = .bold) -> Text {
        Text(text).font(.system(size: size, weight: weight, design: .monospaced))
    }

    func arenaCard(tint: Color, radius: CGFloat = 26) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(UpdoTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.09), CrewInk.purple.opacity(0.04), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(tint.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: UpdoTheme.cardShadow(0.2), radius: 16, y: 9)
    }

    func chromeButton(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .black))
            .foregroundStyle(UpdoTheme.textPrimary)
            .frame(width: 44, height: 44)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Top bar

private extension BackendCrewDetailView {
    var topBar: some View {
        HStack(spacing: 10) {
            if socialSplitClose == nil {
                Button(action: leave) {
                    chromeButton(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("a11y_back"))
            }

            Spacer(minLength: 0)

            Text(crew.name)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(UpdoTheme.textPrimary)
                .lineLimit(1)
                .opacity(titleVisible ? 1 : 0)
                .offset(y: titleVisible ? 0 : 6)

            Spacer(minLength: 0)

            Button(action: openChat) {
                chromeButton(systemName: "bubble.left.and.bubble.right.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("cdx_chat"))

            moreMenu
        }
        .padding(.horizontal, pageGutter)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(UpdoTheme.border).frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .top)
                .opacity(titleVisible ? 1 : 0)
        }
    }

    var moreMenu: some View {
        Menu {
            Button {
                Task { await openInviteSheet() }
            } label: {
                Label(tr("cdx_invite_code"), systemImage: "qrcode")
            }

            Button {
                showAddMember = true
            } label: {
                Label(tr("cdx_add_by_username"), systemImage: "at")
            }

            goalMenu

            if isOwner {
                Divider()
                Button(role: .destructive) {
                    showDeleteCrewConfirm = true
                } label: {
                    Label(String(localized: "backend_crew_delete_action"), systemImage: "trash")
                }
            }
        } label: {
            if isDeletingCrew {
                ProgressView()
                    .frame(width: 44, height: 44)
                    .liquidGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                chromeButton(systemName: "ellipsis")
            }
        }
        .disabled(isDeletingCrew)
        .accessibilityLabel(tr("a11y_more"))
    }

    var goalMenu: some View {
        Menu {
            goalMenuItems
        } label: {
            Label(tr("crew_goal_title"), systemImage: "target")
        }
    }

    @ViewBuilder
    var goalMenuItems: some View {
        ForEach(CrewWeeklyGoalStore.presetsMinutes, id: \.self) { minutes in
            Button {
                applyWeeklyGoal(minutes)
            } label: {
                if weeklyGoalMinutes == minutes {
                    Label(tr("crew_goal_hours_n", minutes / 60), systemImage: "checkmark")
                } else {
                    Text(tr("crew_goal_hours_n", minutes / 60))
                }
            }
        }
        if weeklyGoalMinutes > 0 {
            Divider()
            Button(role: .destructive) {
                applyWeeklyGoal(0)
            } label: {
                Text(tr("crew_goal_off"))
            }
        }
    }
}

// MARK: - Stage (hero)

private extension BackendCrewDetailView {
    func stage(_ mates: [CrewMateStat]) -> some View {
        let focusing = mates.filter(\.isFocusing).count

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                crewPhoto()

                VStack(alignment: .leading, spacing: 6) {
                    stageEyebrow(focusing: focusing)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(crew.name)
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(UpdoTheme.textPrimary)
                        Text("crew")
                            .font(.system(size: 26, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(CrewInk.brand)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                    mono(caps("\(membersText(mates.count)) · \(tr("cdx_level_short", crewLevel))"))
                        .tracking(0.6)
                        .foregroundStyle(UpdoTheme.filmy(0.5))
                }

                Spacer(minLength: 0)
            }

            matesStrip(mates)

            primaryAction(focusingCount: focusing)

            HStack(spacing: 10) {
                secondaryButton(title: tr("cdx_chat"), icon: "bubble.left.fill", tint: CrewInk.cyan, action: openChat)
                secondaryButton(title: tr("cdx_invite_btn"), icon: "person.badge.plus", tint: CrewInk.lime) {
                    Task { await openInviteSheet() }
                }
            }
        }
        .padding(18)
        .background(stageBackground)
    }

    /// iPad stage: identity + crewmates on the left, today's numbers and the
    /// call to action docked on the right.
    func padStage(_ mates: [CrewMateStat]) -> some View {
        let focusing = mates.filter(\.isFocusing).count
        let todayTotal = mates.reduce(0) { $0 + $1.todayMinutes }

        return HStack(alignment: .center, spacing: 28) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 18) {
                    crewPhoto(size: 92, corner: 28)

                    VStack(alignment: .leading, spacing: 7) {
                        stageEyebrow(focusing: focusing)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(crew.name)
                                .font(.system(size: 40, weight: .black))
                                .foregroundStyle(UpdoTheme.textPrimary)
                            Text("crew")
                                .font(.system(size: 35, weight: .regular, design: .serif))
                                .italic()
                                .foregroundStyle(CrewInk.brand)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                        mono(caps("\(membersText(mates.count)) · \(tr("cdx_level_short", crewLevel))"), size: 12)
                            .tracking(0.6)
                            .foregroundStyle(UpdoTheme.filmy(0.5))
                    }

                    Spacer(minLength: 0)
                }

                matesStrip(mates, inset: 26)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    padStageStat(label: tr("cdp_today"), value: focusTimeText(todayTotal), tint: CrewInk.cyan)
                    padStageStat(label: tr("cdp_week"), value: focusTimeText(weekTotalMinutes), tint: CrewInk.violet)
                    padStageStat(label: tr("cdp_streak"), value: "\(streakDays)", tint: CrewInk.gold)
                }

                primaryAction(focusingCount: focusing)

                HStack(spacing: 10) {
                    secondaryButton(title: tr("cdx_chat"), icon: "bubble.left.fill", tint: CrewInk.cyan, action: openChat)
                    secondaryButton(title: tr("cdx_invite_btn"), icon: "person.badge.plus", tint: CrewInk.lime) {
                        Task { await openInviteSheet() }
                    }
                }
            }
            .frame(width: 320)
        }
        .padding(26)
        .background(stageBackground)
    }

    func padStageStat(label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            mono(caps(label), size: 9, weight: .black)
                .tracking(1.2)
                .foregroundStyle(tint)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 19, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(UpdoTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        )
    }

    func stageEyebrow(focusing: Int) -> some View {
        HStack(spacing: 8) {
            eyebrow(tr("bcd_active_crew_caps"))
            if focusing > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .symbolEffect(.pulse, options: .repeating)
                    Text(caps(tr("cdx_live_n", focusing)))
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.4)
                }
                .foregroundStyle(UpdoTheme.lime)
            }
        }
    }

    var stageBackground: some View {
        let accent = hexColor(crew.color_hex)

        return RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(UpdoTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.16), CrewInk.purple.opacity(0.13), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [CrewInk.cyan.opacity(0.14), .clear],
                            center: .bottomTrailing,
                            startRadius: 10,
                            endRadius: 220
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(accent.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: UpdoTheme.cardShadow(0.26), radius: 20, y: 12)
    }

    func crewPhoto(size: CGFloat = 72, corner: CGFloat = 22) -> some View {
        PhotosPicker(selection: $crewPhotoItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                CrewAvatarView(
                    crewID: crew.id,
                    name: crew.name,
                    colorHex: crew.color_hex,
                    size: size,
                    corner: corner
                )
                .shadow(color: hexColor(crew.color_hex).opacity(0.4), radius: 16, y: 8)

                Image(systemName: "camera.fill")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(CrewInk.cyan))
                    .overlay(Circle().stroke(UpdoTheme.surface, lineWidth: 2.5))
                    .offset(x: 5, y: 5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr("cdx_change_photo"))
    }

    func membersText(_ count: Int) -> String {
        tr(count == 1 ? "cdx_members_one" : "cdx_members_n", count)
    }

    /// `inset` is the stage card's padding — the strip runs edge to edge in it.
    func matesStrip(_ mates: [CrewMateStat], inset: CGFloat = 18) -> some View {
        // Scrolls edge to edge inside the card.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(mates) { mate in
                    mateBubble(mate)
                }

                Button {
                    Task { await openInviteSheet() }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(UpdoTheme.lime)
                            .frame(width: 54, height: 54)
                            .background(
                                Circle()
                                    .strokeBorder(CrewInk.lime.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            )
                        mono(caps(tr("cdx_invite_btn")), size: 9, weight: .black)
                            .foregroundStyle(UpdoTheme.lime)
                    }
                    .frame(width: 64)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)
        }
        .contentMargins(.horizontal, inset - 4, for: .scrollContent)
        .padding(.horizontal, -inset)
    }

    func mateBubble(_ mate: CrewMateStat) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                UserAvatarView(userID: mate.member.user_id, name: mate.name, tint: mate.color, size: 54)
                    .padding(3)
                    .overlay(
                        Circle().stroke(mate.isFocusing ? CrewInk.lime : mate.color.opacity(0.35), lineWidth: mate.isFocusing ? 2.5 : 1)
                    )

                if mate.isFocusing {
                    Image(systemName: "timer")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(CrewInk.lime))
                        .overlay(Circle().stroke(UpdoTheme.surface, lineWidth: 2))
                } else if mate.isOnline {
                    Circle()
                        .fill(CrewInk.lime)
                        .frame(width: 13, height: 13)
                        .overlay(Circle().stroke(UpdoTheme.surface, lineWidth: 2.5))
                        .offset(x: -2, y: -2)
                }
            }

            Text(mate.isMe ? tr("cdx_you") : mate.firstName)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(UpdoTheme.textPrimary)
                .lineLimit(1)

            mono(caps(mateCaption(mate)), size: 9, weight: .bold)
                .foregroundStyle(mate.isFocusing ? UpdoTheme.lime : UpdoTheme.filmy(0.42))
                .lineLimit(1)
        }
        .frame(width: 64)
        .contentShape(Rectangle())
        .contextMenu { mateMenu(mate) }
        .accessibilityElement(children: .combine)
    }

    func mateCaption(_ mate: CrewMateStat) -> String {
        if mate.isFocusing {
            if let since = mate.focusingSince {
                let minutes = max(1, Int(Date().timeIntervalSince(since) / 60))
                return tr("cdx_focusing_min", minutes)
            }
            return tr("cdx_focusing")
        }
        if mate.todayMinutes > 0 { return focusTimeText(mate.todayMinutes) }
        return mate.isOnline ? tr("cdx_online") : " "
    }

    @ViewBuilder
    func mateMenu(_ mate: CrewMateStat) -> some View {
        if !mate.isMe {
            Button {
                Task { await nudge(mate) }
            } label: {
                Label(tr("cdx_nudge_named", mate.firstName), systemImage: "hand.wave.fill")
            }
            .disabled(isNudgeCoolingDown(mate.id))
        }

        if isOwner && !mate.isOwner && !mate.isMe {
            Button(role: .destructive) {
                memberToRemove = mate.member
                showRemoveMemberConfirm = true
            } label: {
                Label(String(localized: "backend_crew_remove_member_action"), systemImage: "person.crop.circle.badge.minus")
            }
        }
    }

    // MARK: Primary action

    @ViewBuilder
    func primaryAction(focusingCount: Int) -> some View {
        if let live = liveSession {
            let amIn = FocusSessionManager.shared.currentCrewID == crew.id
                && FocusSessionManager.shared.isSessionActive

            Button {
                if amIn { returnToRoom() } else { joinLive(live) }
            } label: {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    primaryLabel(
                        icon: amIn ? "arrow.up.forward.circle.fill" : "person.2.wave.2.fill",
                        title: amIn ? tr("cdx_back_to_room") : tr("cdx_join_n", max(liveParticipants.count, 1)),
                        trailing: remainingText(live),
                        fill: CrewInk.lime
                    )
                }
            }
            .buttonStyle(PressableButtonStyle())
        } else {
            Button(action: startTogether) {
                primaryLabel(icon: "bolt.fill", title: tr("cdx_focus_together"), trailing: nil, fill: CrewInk.blue)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    func primaryLabel(icon: String, title: String, trailing: String?, fill: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
            Text(title)
                .font(.system(size: 16, weight: .black))
            if let trailing {
                mono(trailing, size: 13, weight: .black)
                    .monospacedDigit()
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.14)))
            }
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(
            Capsule()
                .fill(fill)
                .shadow(color: fill.opacity(0.42), radius: 14, y: 6)
        )
        .contentShape(Capsule())
    }

    func secondaryButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(UpdoTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    Capsule()
                        .fill(tint.opacity(0.12))
                        .overlay(Capsule().stroke(tint.opacity(0.24), lineWidth: 1))
                )
        }
        .buttonStyle(PressableButtonStyle())
    }

    func remainingText(_ live: CrewFocusSessionDTO) -> String {
        let remaining: Int
        if live.is_paused, let paused = live.paused_remaining_seconds {
            remaining = paused
        } else if let started = CrewDateParser.parse(live.started_at) {
            remaining = max(0, Int(started.addingTimeInterval(TimeInterval(live.duration_minutes * 60)).timeIntervalSinceNow))
        } else {
            remaining = live.duration_minutes * 60
        }
        return String(format: "%02d:%02d", remaining / 60, remaining % 60)
    }
}

// MARK: - This week

private extension BackendCrewDetailView {
    func weekCard(_ mates: [CrewMateStat]) -> some View {
        let total = weekTotalMinutes
        let goal = weeklyGoalMinutes
        let reached = goal > 0 && total >= goal

        return VStack(alignment: .leading, spacing: 18) {
            sectionHeader(eyebrow: tr("cdx_this_week"), title: tr("cdx_week_title"), accent: tr("cdx_week_word")) {
                Menu {
                    goalMenuItems
                } label: {
                    HStack(spacing: 5) {
                        mono(goal > 0 ? caps(focusTimeText(goal)) : caps(tr("crew_goal_set")), size: 12, weight: .black)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .black))
                    }
                    .foregroundStyle(CrewInk.gold)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(CrewInk.gold.opacity(0.12))
                            .overlay(Capsule().stroke(CrewInk.gold.opacity(0.3), lineWidth: 1))
                    )
                }
            }

            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    CrewWeekRing(
                        segments: ringSegments(mates: mates, total: total, goal: goal),
                        track: UpdoTheme.filmy(0.07),
                        lineWidth: 15,
                        progress: ringProgress
                    )
                    .frame(width: 126, height: 126)

                    VStack(spacing: 2) {
                        if reached {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(UpdoTheme.lime)
                                .symbolEffect(.bounce, value: celebrate)
                        }
                        Text(focusTimeText(total))
                            .font(.system(size: 19, weight: .black))
                            .foregroundStyle(UpdoTheme.textPrimary)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .contentTransition(.numericText())
                        mono(goal > 0 ? "%\(min(100, total * 100 / max(goal, 1)))" : caps(tr("cdx_no_goal")), size: 10, weight: .black)
                            .tracking(1)
                            .foregroundStyle(UpdoTheme.filmy(0.45))
                    }
                    .frame(width: 76)
                }

                VStack(alignment: .leading, spacing: 14) {
                    streakBlock
                    weekDots
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Rectangle()
                .fill(UpdoTheme.filmy(0.07))
                .frame(height: 1)

            levelRow
        }
        .padding(18)
        .background(arenaCard(tint: CrewInk.gold))
    }

    var streakBlock: some View {
        let days = streakDays

        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(
                    days > 0
                    ? AnyShapeStyle(LinearGradient(colors: [CrewInk.gold, CrewInk.coral], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(UpdoTheme.filmy(0.25))
                )
                .symbolEffect(.bounce, value: days)
            Text("\(days)")
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(UpdoTheme.textPrimary)
                .contentTransition(.numericText())
            Text(tr("cdx_day_streak"))
                .font(.system(size: 18, weight: .regular, design: .serif))
                .italic()
                .foregroundStyle(UpdoTheme.filmy(0.6))
        }
    }

    var weekDots: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        return HStack(spacing: 0) {
            ForEach(weekDays, id: \.date) { day in
                let index = (cal.component(.weekday, from: day.date) + 5) % 7
                let isToday = day.date == today
                let future = day.date > today

                VStack(spacing: 5) {
                    mono(String(localizedWeekdayShort(index).prefix(1)).uppercased(), size: 9, weight: .black)
                        .foregroundStyle(isToday ? UpdoTheme.cyan : UpdoTheme.filmy(0.38))

                    ZStack {
                        Circle()
                            .fill(day.active ? CrewInk.lime : UpdoTheme.filmy(future ? 0.04 : 0.08))
                        if day.active {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8, weight: .black))
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle().stroke(isToday && !day.active ? CrewInk.cyan : .clear, lineWidth: 1.5)
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    var levelRow: some View {
        let minutes = allTimeMinutes
        let next = CrewBadgeHelper.nextTarget(for: minutes)
        let progress = CrewBadgeHelper.progress(for: minutes)

        return HStack(spacing: 12) {
            ZStack {
                Image(systemName: "hexagon.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(CrewInk.brand)
                Text("\(crewLevel)")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(tr("cdx_level_n", crewLevel))
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(UpdoTheme.textPrimary)
                    Spacer()
                    mono(caps(next.map { tr("cdx_next_level_in", focusTimeText($0 - minutes)) } ?? tr("cdx_max_level")), size: 10)
                        .foregroundStyle(UpdoTheme.filmy(0.45))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(UpdoTheme.filmy(0.08))
                        Capsule()
                            .fill(CrewInk.brand)
                            .frame(width: max(6, geo.size.width * progress * ringProgress))
                    }
                }
                .frame(height: 6)
            }
        }
        .accessibilityElement(children: .combine)
    }

    func ringSegments(mates: [CrewMateStat], total: Int, goal: Int) -> [CrewWeekRing.Segment] {
        let scale = Double(max(goal > 0 ? goal : 300, total, 1))
        var segments: [CrewWeekRing.Segment] = []
        var cursor = 0.0
        for mate in mates.sorted(by: { $0.weekMinutes > $1.weekMinutes }) where mate.weekMinutes > 0 {
            let fraction = Double(mate.weekMinutes) / scale
            segments.append(.init(id: mate.id, color: mate.color, start: cursor, end: cursor + fraction))
            cursor += fraction
        }
        // Minutes we can't tie to a current member (e.g. someone who left).
        let attributed = mates.reduce(0) { $0 + $1.weekMinutes }
        if total > attributed {
            let fraction = Double(total - attributed) / scale
            segments.append(.init(id: UUID(), color: UpdoTheme.filmy(0.3), start: cursor, end: cursor + fraction))
        }
        return segments
    }
}

// MARK: - Standings + nudge

private extension BackendCrewDetailView {
    func standingsCard(_ mates: [CrewMateStat]) -> some View {
        let ranked = mates.sorted {
            if $0.weekMinutes != $1.weekMinutes { return $0.weekMinutes > $1.weekMinutes }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }

        return VStack(alignment: .leading, spacing: 14) {
            sectionHeader(eyebrow: tr("cdx_standings_caps"), title: tr("cdx_standings_title"), accent: tr("cdx_standings_word")) {
                EmptyView()
            }

            if let callout = rivalryCallout(ranked) {
                HStack(spacing: 9) {
                    Image(systemName: callout.icon)
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(UpdoTheme.cyan)
                    Text(callout.text)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(UpdoTheme.textPrimary)
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(CrewInk.cyan.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(CrewInk.cyan.opacity(0.2), lineWidth: 1)
                        )
                )
            }

            VStack(spacing: 0) {
                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, mate in
                    standingRow(rank: index + 1, mate: mate, leaderMinutes: ranked.first?.weekMinutes ?? 0)
                    if index < ranked.count - 1 {
                        Rectangle()
                            .fill(UpdoTheme.filmy(0.06))
                            .frame(height: 1)
                            .padding(.leading, 82)
                    }
                }
            }
        }
        .padding(18)
        .background(arenaCard(tint: CrewInk.cyan))
    }

    func rivalryCallout(_ ranked: [CrewMateStat]) -> (icon: String, text: String)? {
        guard ranked.count > 1, let myIndex = ranked.firstIndex(where: \.isMe) else { return nil }
        let me = ranked[myIndex]

        if ranked.allSatisfy({ $0.weekMinutes == 0 }) {
            return ("sparkles", tr("cdx_rival_first"))
        }
        if myIndex == 0 {
            let gap = me.weekMinutes - ranked[1].weekMinutes
            return gap > 0
                ? ("crown.fill", tr("cdx_rival_lead", focusTimeText(gap)))
                : ("equal.circle.fill", tr("cdx_rival_tied", ranked[1].firstName))
        }
        let above = ranked[myIndex - 1]
        let gap = above.weekMinutes - me.weekMinutes + 1
        return ("arrow.up.right.circle.fill", tr("cdx_rival_pass", above.firstName, focusTimeText(gap)))
    }

    func standingRow(rank: Int, mate: CrewMateStat, leaderMinutes: Int) -> some View {
        HStack(spacing: 12) {
            Group {
                if rank == 1 && mate.weekMinutes > 0 {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(CrewInk.gold)
                } else {
                    mono("#\(rank)", size: 12, weight: .black)
                        .foregroundStyle(UpdoTheme.filmy(0.4))
                }
            }
            .frame(width: 26)

            UserAvatarView(userID: mate.member.user_id, name: mate.name, tint: mate.color, size: 40)
                .overlay(Circle().stroke(mate.color, lineWidth: 2).padding(-3))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(mate.name)
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(UpdoTheme.textPrimary)
                        .lineLimit(1)
                    if mate.isMe {
                        mono(caps(tr("cdx_you")), size: 9, weight: .black)
                            .tracking(1)
                            .foregroundStyle(UpdoTheme.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(CrewInk.cyan.opacity(0.14)))
                    }
                }

                GeometryReader { geo in
                    Capsule()
                        .fill(mate.color)
                        .frame(
                            width: leaderMinutes > 0
                                ? max(4, geo.size.width * CGFloat(mate.weekMinutes) / CGFloat(leaderMinutes) * ringProgress)
                                : 4,
                            height: 4
                        )
                        .opacity(mate.weekMinutes > 0 ? 1 : 0.3)
                }
                .frame(height: 4)
            }

            mono(focusTimeText(mate.weekMinutes), size: 13, weight: .black)
                .foregroundStyle(mate.weekMinutes > 0 ? UpdoTheme.textPrimary : UpdoTheme.filmy(0.35))
                .monospacedDigit()
                .fixedSize()

            if mate.isMe {
                Color.clear.frame(width: 36, height: 36)
            } else {
                nudgeButton(mate)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu { mateMenu(mate) }
    }

    @ViewBuilder
    func nudgeButton(_ mate: CrewMateStat) -> some View {
        let cooling = isNudgeCoolingDown(mate.id)

        if mate.isFocusing {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(UpdoTheme.lime)
                .frame(width: 36, height: 36)
                .accessibilityLabel(tr("cdx_focusing"))
        } else {
            Button {
                Task { await nudge(mate) }
            } label: {
                ZStack {
                    if nudgingID == mate.id {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: cooling ? "checkmark" : "hand.wave.fill")
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(cooling ? UpdoTheme.filmy(0.4) : CrewInk.coral)
                            .symbolEffect(.bounce, value: cooling)
                    }
                }
                .frame(width: 36, height: 36)
                .background(Circle().fill(cooling ? UpdoTheme.filmy(0.06) : CrewInk.coral.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .disabled(cooling || nudgingID != nil)
            .accessibilityLabel(cooling ? tr("cdx_nudged") : tr("cdx_nudge_named", mate.firstName))
        }
    }
}

// MARK: - Complete your crew

private extension BackendCrewDetailView {
    func completeCrewCard(_ mates: [CrewMateStat]) -> some View {
        let friends = Array(invitableFriends.prefix(4))

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    eyebrow(tr("cdx_complete_caps"), tint: UpdoTheme.lime)
                    accentTitle(tr("cdx_complete_t1"), tr("cdx_complete_word"))
                    Text(tr("cdx_complete_sub"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(UpdoTheme.filmy(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                slotsView(filled: mates)
            }

            if !friends.isEmpty {
                VStack(spacing: 8) {
                    ForEach(friends, id: \.id) { friend in
                        inviteFriendRow(friend)
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    Task {
                        if await ensureInviteCode() != nil { showShareSheet = true }
                    }
                } label: {
                    Label(tr("cdx_share_link"), systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Capsule().fill(CrewInk.blue))
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    showAddMember = true
                } label: {
                    Label(tr("cdx_username"), systemImage: "at")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(UpdoTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            Capsule()
                                .fill(UpdoTheme.filmy(0.07))
                                .overlay(Capsule().stroke(UpdoTheme.filmy(0.1), lineWidth: 1))
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(18)
        .background(arenaCard(tint: CrewInk.lime))
    }

    func slotsView(filled: [CrewMateStat]) -> some View {
        HStack(spacing: -10) {
            ForEach(0..<3, id: \.self) { slot in
                if slot < filled.count {
                    UserAvatarView(userID: filled[slot].member.user_id, name: filled[slot].name, tint: filled[slot].color, size: 34)
                        .overlay(Circle().stroke(UpdoTheme.surface, lineWidth: 2))
                } else {
                    Circle()
                        .strokeBorder(CrewInk.lime.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .background(Circle().fill(UpdoTheme.surface))
                        .frame(width: 34, height: 34)
                }
            }
        }
        .accessibilityLabel(tr("cdx_slots", filled.count))
    }

    func inviteFriendRow(_ friend: Friend) -> some View {
        let sent = invitedFriendIDs.contains(friend.id)
        let sending = sendingInviteFriendID == friend.id

        return HStack(spacing: 12) {
            UserAvatarView(userID: friend.backendUserID, name: friend.name, tint: CrewInk.lime, size: 40)

            Text(friend.name)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(UpdoTheme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button {
                sendChatInvite(to: friend)
            } label: {
                Group {
                    if sending {
                        ProgressView().controlSize(.small).tint(.black)
                    } else if sent {
                        Label(caps(tr("cdx_invite_sent")), systemImage: "checkmark")
                    } else {
                        Text(caps(tr("cdx_invite_btn")))
                    }
                }
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(sent ? UpdoTheme.lime : .black)
                .padding(.horizontal, 13)
                .frame(height: 32)
                .background(Capsule().fill(sent ? CrewInk.lime.opacity(0.14) : CrewInk.lime))
            }
            .buttonStyle(.plain)
            .disabled(sent || sending)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(UpdoTheme.filmy(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(UpdoTheme.filmy(0.07), lineWidth: 1)
                )
        )
    }
}

// MARK: - Tasks

private extension BackendCrewDetailView {
    func tasksCard(_ mates: [CrewMateStat]) -> some View {
        let tasks = sortedCrewTasks
        let open = tasks.filter { !$0.is_done }
        let done = tasks.filter(\.is_done)

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(eyebrow: tr("bcd_shared_tasks_caps"), title: tr("bcd_shared"), accent: tr("tasks_lc")) {
                if !tasks.isEmpty {
                    HStack(spacing: 8) {
                        mono("\(open.count)", size: 12, weight: .black)
                            .foregroundStyle(UpdoTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(Capsule().fill(UpdoTheme.filmy(0.075)))

                        Button {
                            showCreateTask = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(.black)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(CrewInk.blue))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tr("common_add"))
                    }
                }
            }

            if tasks.isEmpty {
                emptyTasks
            } else {
                VStack(spacing: 8) {
                    ForEach(open) { task in
                        taskRow(task, mates: mates)
                    }
                }

                if !done.isEmpty {
                    Button {
                        withAnimation(.snappy) { showDoneTasks.toggle() }
                    } label: {
                        HStack {
                            mono(caps(tr("cdx_completed_n", done.count)), size: 10, weight: .black)
                                .tracking(1.2)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .black))
                                .rotationEffect(.degrees(showDoneTasks ? 90 : 0))
                        }
                        .foregroundStyle(UpdoTheme.filmy(0.45))
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if showDoneTasks {
                        VStack(spacing: 8) {
                            ForEach(done) { task in
                                taskRow(task, mates: mates)
                            }
                        }
                        .transition(.opacity)
                    }
                }
            }
        }
        .padding(18)
        .background(arenaCard(tint: CrewInk.blue))
    }

    var emptyTasks: some View {
        Button {
            showCreateTask = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(CrewInk.blue)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(CrewInk.blue.opacity(0.13)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("cdx_tasks_empty_title"))
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(UpdoTheme.textPrimary)
                    Text(tr("cdx_tasks_empty_sub"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(UpdoTheme.filmy(0.48))
                }
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(CrewInk.blue))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(CrewInk.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    func taskRow(_ task: CrewTaskDTO, mates: [CrewMateStat]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                Task { await crewStore.toggleTask(task) }
            } label: {
                Image(systemName: task.is_done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(task.is_done ? UpdoTheme.lime : UpdoTheme.filmy(0.28))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: task.is_done)
            .accessibilityLabel(task.is_done ? String(localized: "backend_crew_reopen_task") : String(localized: "backend_crew_mark_done"))

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(task.is_done ? UpdoTheme.filmy(0.45) : UpdoTheme.textPrimary)
                    .strikethrough(task.is_done, color: UpdoTheme.filmy(0.45))
                    .lineLimit(2)

                taskMeta(task, mates: mates)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(UpdoTheme.filmy(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(UpdoTheme.filmy(0.07), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture { selectedTask = task }
        .contextMenu { taskMenu(task) }
    }

    @ViewBuilder
    func taskMeta(_ task: CrewTaskDTO, mates: [CrewMateStat]) -> some View {
        let assignee = task.assigned_to.flatMap { id in mates.first { $0.id == id } }
        let urgent = task.priority == "high" || task.priority == "urgent"
        let scheduled: String? = {
            guard task.show_on_week, let weekday = task.scheduled_weekday, let start = task.scheduled_start_minute else { return nil }
            return "\(localizedWeekdayShort(max(0, min(6, weekday)))) \(String(format: "%02d:%02d", start / 60, start % 60))"
        }()

        if assignee != nil || urgent || scheduled != nil {
            HStack(spacing: 6) {
                if let assignee {
                    metaPill(assignee.isMe ? tr("cdx_you") : assignee.firstName, icon: "person.fill", tint: assignee.color)
                }
                if urgent {
                    metaPill(priorityLabel(task.priority), icon: "flame.fill", tint: CrewInk.coral)
                }
                if let scheduled {
                    metaPill(scheduled, icon: "calendar", tint: CrewInk.cyan)
                }
            }
        }
    }

    func metaPill(_ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .black))
            Text(caps(text))
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.13)))
    }

    @ViewBuilder
    func taskMenu(_ task: CrewTaskDTO) -> some View {
        Button {
            Task { await crewStore.toggleTask(task) }
        } label: {
            Label(
                task.is_done ? String(localized: "backend_crew_reopen_task") : String(localized: "backend_crew_mark_done"),
                systemImage: task.is_done ? "arrow.uturn.backward.circle" : "checkmark.circle"
            )
        }

        Button(role: .destructive) {
            Task {
                do {
                    try await crewStore.deleteTask(taskID: task.id, crewID: task.crew_id, title: task.title)
                } catch {
                    Log.debug("DELETE TASK ERROR:", error.localizedDescription)
                }
            }
        } label: {
            Label(String(localized: "backend_crew_delete_task"), systemImage: "trash")
        }
    }

    func priorityLabel(_ raw: String) -> String {
        switch raw {
        case "urgent": return appLanguageIsEnglish() ? "Urgent" : "Acil"
        case "high": return appLanguageIsEnglish() ? "High" : tr("prio_high")
        default: return raw.capitalized
        }
    }
}

// MARK: - Activity

private extension BackendCrewDetailView {
    var activityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(eyebrow: tr("bcd_live_activity_caps"), title: tr("bcd_activity"), accent: tr("tv_flow_word")) {
                EmptyView()
            }

            VStack(spacing: 0) {
                ForEach(Array(recentActivities.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            UserAvatarView(userID: nil, name: item.member_name, tint: CrewInk.violet, size: 32)
                            if index < recentActivities.count - 1 {
                                Rectangle()
                                    .fill(UpdoTheme.filmy(0.08))
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                            }
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(Text(item.member_name).font(.system(size: 14, weight: .black))) \(item.action_text)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(UpdoTheme.filmy(0.72))
                                .lineLimit(2)
                            mono(caps(relativeTime(item.created_at)), size: 9, weight: .bold)
                                .foregroundStyle(UpdoTheme.filmy(0.35))
                        }
                        .padding(.bottom, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .padding(18)
        .background(arenaCard(tint: CrewInk.purple))
    }

    func relativeTime(_ raw: String?) -> String {
        guard let date = raw.flatMap({ CrewDateParser.parse($0) }) else { return String(localized: "common_now") }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: appLanguageIsEnglish() ? "en" : "tr")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Shared pieces

private extension BackendCrewDetailView {
    /// Updo's arena glows behind the page (soft, so light mode stays clean).
    var ambientGlow: some View {
        ZStack {
            Circle()
                .fill(CrewInk.cyan.opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 100)
                .offset(x: 160, y: -220)
            Circle()
                .fill(CrewInk.purple.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 110)
                .offset(x: -170, y: 420)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    @ViewBuilder
    var toastView: some View {
        if let toast {
            Text(toast)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(UpdoTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .liquidGlass(in: Capsule())
                .padding(.top, 58)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    func showToast(_ text: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(2.4))
            withAnimation(.easeOut(duration: 0.25)) {
                if toast == text { toast = nil }
            }
        }
    }
}

// MARK: - Actions

private extension BackendCrewDetailView {
    func openChat() {
        NotificationCenter.default.post(name: .openCrewChatFromNotification, object: crew.id.uuidString)
    }

    func startTogether() {
        HapticManager.shared.success()
        CrewDeepLink.pendingFocusCrewID = crew.id
        NotificationCenter.default.post(name: .openFocusTabFromHome, object: nil)
    }

    func returnToRoom() {
        NotificationCenter.default.post(name: .openFocusTabFromHome, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            FocusSessionManager.shared.isExpanded = true
        }
    }

    /// Same payload the crew chat's focus pill sends: the app-level join sheet
    /// (who's in + Katıl) takes it from there.
    func joinLive(_ live: CrewFocusSessionDTO) {
        let names = liveParticipants.map(\.member_name)
        var userInfo: [AnyHashable: Any] = [
            "crew_id": live.crew_id.uuidString,
            "session_id": live.id.uuidString,
            "host_name": live.host_name,
            "crew_name": crew.name,
            "duration_minutes": live.duration_minutes,
            "started_at": live.started_at,
            "total_participants": max(names.count, 1)
        ]
        if let taskTitle = live.task_title { userInfo["task_title"] = taskTitle }
        if let hostID = live.host_user_id { userInfo["host_user_id"] = hostID.uuidString }
        if !names.isEmpty { userInfo["participant_names"] = names }

        NotificationCenter.default.post(name: .presentCrewFocusInviteSheet, object: userInfo)
    }

    func applyWeeklyGoal(_ minutes: Int) {
        weeklyGoalMinutes = minutes
        Task { await crewStore.setWeeklyGoal(crewID: crew.id, minutes: minutes) }
    }

    func ensureInviteCode() async -> String? {
        if !inviteCode.isEmpty { return inviteCode }
        guard let user = session.currentUser else { return nil }
        do {
            let code = try await crewStore.createInvite(for: crew.id, userID: user.id)
            inviteCode = code
            return code
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func openInviteSheet() async {
        if await ensureInviteCode() != nil { showInviteSheet = true }
    }

    func sendChatInvite(to friend: Friend) {
        guard let friendshipID = friend.backendFriendshipID,
              let friendUserID = friend.backendUserID
        else { return }

        sendingInviteFriendID = friend.id

        Task {
            defer { Task { @MainActor in sendingInviteFriendID = nil } }

            guard let code = await ensureInviteCode(),
                  let conversation = await ChatBackendClient.shared.syncFriendship(
                    friendshipID: friendshipID,
                    friendUserID: friendUserID
                  ) else { return }

            let text = CrewInviteMessage.encode(code: code, crewName: crew.name)
            let sent = await ChatBackendClient.shared.sendMessage(conversationID: conversation.id, text: text)

            if sent != nil {
                await MainActor.run {
                    _ = invitedFriendIDs.insert(friend.id)
                    HapticManager.shared.success()
                }
            }
        }
    }

    // MARK: Nudge

    var nudgeStoreKey: String { "crew.nudges.\(crew.id.uuidString)" }

    func loadNudges() -> [UUID: Date] {
        let raw = UserDefaults.standard.dictionary(forKey: nudgeStoreKey) as? [String: Double] ?? [:]
        var result: [UUID: Date] = [:]
        for (key, value) in raw {
            let date = Date(timeIntervalSince1970: value)
            if let id = UUID(uuidString: key), date > Date() { result[id] = date }
        }
        return result
    }

    func isNudgeCoolingDown(_ userID: UUID) -> Bool {
        (nudgedUntil[userID] ?? .distantPast) > Date()
    }

    func nudge(_ mate: CrewMateStat) async {
        guard nudgingID == nil, !isNudgeCoolingDown(mate.id) else { return }
        nudgingID = mate.id
        defer { nudgingID = nil }

        let myName = myUserID.map { memberName(from: memberProfilesByID[$0]) } ?? ""
        let result = await CrewBackendClient.shared.nudgeMember(crewID: crew.id, toUserID: mate.id, fromName: myName)

        let fallback = Date().addingTimeInterval(3 * 3600)
        switch result {
        case .sent(let next):
            nudgedUntil[mate.id] = next ?? fallback
            HapticManager.shared.success()
            showToast(tr("cdx_nudge_sent", mate.firstName))
        case .cooldown(let next):
            nudgedUntil[mate.id] = next ?? fallback
            showToast(tr("cdx_nudge_cooldown", mate.firstName))
        case .failed:
            showToast(tr("cdx_nudge_failed"))
            return
        }

        let raw = nudgedUntil.reduce(into: [String: Double]()) { $0[$1.key.uuidString] = $1.value.timeIntervalSince1970 }
        UserDefaults.standard.set(raw, forKey: nudgeStoreKey)
    }

    // MARK: Celebration

    /// Once per crew per week, the first time the page sees the goal met.
    func celebrateGoalIfNeeded() {
        guard weeklyGoalMinutes > 0, weekTotalMinutes >= weeklyGoalMinutes else { return }
        let key = "crew.goalCelebrated.\(crew.id.uuidString).\(Int(weekStart.timeIntervalSince1970))"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            celebrate = true
            showToast(tr("cdx_goal_reached"))
        }
    }
}

// MARK: - Sheets & dialogs

extension BackendCrewDetailView {
    fileprivate func attachSheets<Content: View>(to content: Content) -> some View {
        content
            .sheet(isPresented: $showAddMember) {
                Group {
                    AddCrewMemberView(crewID: crew.id)
                        .environmentObject(crewStore)
                }
                .updoPadSheet()
            }
            .sheet(isPresented: $showCreateTask) {
                Group {
                    BackendCreateCrewTaskSheet(
                        crew: crew,
                        members: crewMembers,
                        memberProfiles: crewStore.memberProfiles
                    )
                    .environmentObject(crewStore)
                    .environmentObject(session)
                }
                .updoPadSheet()
            }
            .sheet(item: $selectedTask) { task in
                Group {
                    BackendCrewTaskDetailView(task: task, crew: crew)
                        .environmentObject(crewStore)
                        .environmentObject(session)
                }
                .updoPadSheet()
            }
            .sheet(isPresented: $showShareSheet) {
                Group {
                    ShareSheet(items: [
                        String(format: String(localized: "backend_crew_share_text"), inviteCode)
                    ])
                }
                .updoPadSheet()
            }
            .sheet(isPresented: $showInviteSheet, onDismiss: { inviteCopied = false }) {
                Group {
                    inviteSheet
                }
                .updoPadSheet()
            }
    }

    fileprivate func attachDialogs<Content: View>(to content: Content) -> some View {
        content
            .alert(
                String(localized: "common_error"),
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button(String(localized: "common_ok"), role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? String(localized: "common_unknown_error"))
            }
            .confirmationDialog(
                String(localized: "backend_crew_remove_member_title"),
                isPresented: $showRemoveMemberConfirm,
                titleVisibility: .visible
            ) {
                Button(String(localized: "backend_crew_remove_member_action"), role: .destructive) {
                    guard let member = memberToRemove else { return }
                    guard member.role.lowercased() != "owner" else {
                        errorMessage = String(localized: "backend_crew_owner_cannot_be_removed")
                        return
                    }
                    Task {
                        do {
                            try await crewStore.removeMember(member, from: crew.id)
                            memberToRemove = nil
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                Button(String(localized: "common_cancel"), role: .cancel) {
                    memberToRemove = nil
                }
            } message: {
                Text(tr("backend_crew_remove_member_message"))
            }
            .confirmationDialog(
                String(localized: "backend_crew_delete_title"),
                isPresented: $showDeleteCrewConfirm,
                titleVisibility: .visible
            ) {
                Button(String(localized: "backend_crew_delete_action"), role: .destructive) {
                    Task {
                        guard let currentUserID = session.currentUser?.id else { return }
                        isDeletingCrew = true
                        do {
                            try await crewStore.deleteCrew(crewID: crew.id, currentUserID: currentUserID)
                            leave()
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                        isDeletingCrew = false
                    }
                }
                Button(String(localized: "common_cancel"), role: .cancel) { }
            } message: {
                Text(tr("backend_crew_delete_message"))
            }
    }

    // MARK: Invite sheet

    fileprivate var inviteSheet: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    CrewAvatarView(crewID: crew.id, name: crew.name, colorHex: crew.color_hex, size: 60, corner: 19)
                    VStack(alignment: .leading, spacing: 5) {
                        eyebrow(tr("cdx_invite_caps"))
                        accentTitle(crew.name, "crew", size: 26)
                    }
                }
                .padding(.top, 8)

                Text(tr("bcd_share_code"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(UpdoTheme.filmy(0.52))

                Text(inviteCode)
                    .font(.system(size: 38, weight: .black, design: .monospaced))
                    .tracking(6)
                    .foregroundStyle(UpdoTheme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(UpdoTheme.filmy(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(CrewInk.cyan.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                            )
                    )

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = inviteCode
                        HapticManager.shared.success()
                        withAnimation { inviteCopied = true }
                    } label: {
                        Label(
                            inviteCopied ? String(localized: "common_copied") : String(localized: "common_copy"),
                            systemImage: inviteCopied ? "checkmark" : "doc.on.doc"
                        )
                        .contentTransition(.symbolEffect(.replace))
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Capsule().fill(CrewInk.lime))
                    }
                    .buttonStyle(PressableButtonStyle())

                    ShareLink(item: String(format: String(localized: "backend_crew_share_text"), inviteCode)) {
                        Label(tr("cdx_share"), systemImage: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Capsule().fill(CrewInk.blue))
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                VStack(alignment: .leading, spacing: 10) {
                    eyebrow(tr("bcd_invite_friends_caps"))

                    if invitableFriends.isEmpty {
                        Text(tr("bcd_invite_no_friends"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(UpdoTheme.filmy(0.45))
                    } else {
                        VStack(spacing: 8) {
                            ForEach(invitableFriends, id: \.id) { friend in
                                inviteFriendRow(friend)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(UpdoTheme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Components

/// Weekly ring split into each crewmate's share, Apple Fitness style.
struct CrewWeekRing: View {
    struct Segment: Identifiable {
        let id: UUID
        let color: Color
        let start: Double
        let end: Double
    }

    let segments: [Segment]
    let track: Color
    let lineWidth: CGFloat
    var progress: Double = 1

    var body: some View {
        ZStack {
            Circle()
                .stroke(track, lineWidth: lineWidth)

            ForEach(segments) { segment in
                let gap = segments.count > 1 ? 0.006 : 0
                let start = min(segment.start, 1) * progress
                let end = max(start, (min(segment.end, 1) - gap) * progress)

                Circle()
                    .trim(from: start, to: end)
                    .stroke(segment.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            }
        }
        .rotationEffect(.degrees(-90))
        .padding(lineWidth / 2)
    }
}

/// Soft press: scales down a touch, like system buttons.
private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

private extension View {
    /// Rises in once on first appearance.
    func crewReveal(_ shown: Bool, delay: Double) -> some View {
        self
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .animation(.spring(response: 0.5, dampingFraction: 0.88).delay(delay), value: shown)
    }
}
