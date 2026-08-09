//
//  WeeklyScheduleEditorView.swift
//  DailyTodo
//
//  Hafta ekranından açılan "Haftalık Programı Düzenle" bölümü: kullanıcı
//  haftalık tekrar eden dersleri/etkinlikleri (EventItem, scheduledDate == nil)
//  güne göre görür, yanlış olanı siler, elle etkinlik ekler ya da (Pro ise)
//  fotoğraftan AI ile tarayıp ekler. Tarama pipeline'ı onboarding'deki
//  CourseSetupSheet ile birebir aynı (ScheduleScanClient + ScheduleScanPreviewSheet).
//

import SwiftUI
import SwiftData
import PhotosUI

struct WeeklyScheduleEditorView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var studentStore: StudentStore
    @EnvironmentObject private var friendStore: FriendStore
    @ObservedObject private var subscription = SubscriptionManager.shared

    @Query(sort: \EventItem.startMinute, order: .forward)
    private var allEvents: [EventItem]

    @State private var showingAdd = false
    @State private var showPaywall = false

    // Fotoğraftan tarama
    @State private var scanPickerItems: [PhotosPickerItem] = []
    @State private var isScanning = false
    @State private var scanError: String?
    @State private var scannedCourses: [ScannedScheduleCourse] = []
    @State private var showScanPreview = false

    private var gold: Color { Color(arenaHex: "#FBBF24") }
    private var coral: Color { Color(arenaHex: "#FF6B57") }

    var body: some View {
        NavigationStack {
            ZStack {
                UpdoTheme.background.ignoresSafeArea()

                Circle()
                    .fill(UpdoTheme.cyan.opacity(0.07))
                    .frame(width: 280, height: 280)
                    .blur(radius: 90)
                    .offset(x: 150, y: -260)
                    .ignoresSafeArea()

                Circle()
                    .fill(UpdoTheme.purple.opacity(0.09))
                    .frame(width: 320, height: 320)
                    .blur(radius: 100)
                    .offset(x: -170, y: 380)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        actionsCard

                        if eventsByWeekday.isEmpty {
                            emptyState
                        } else {
                            ForEach(eventsByWeekday, id: \.weekday) { group in
                                dayGroup(group.weekday, group.events)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 48)
                }
            }
            .navigationTitle(tr("wk_sched_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("common_done")) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(UpdoTheme.cyan)
        .sheet(isPresented: $showingAdd) {
            NavigationStack {
                AddEventView(defaultWeekday: todayWeekday, defaultDate: nil)
                    .environmentObject(session)
                    .environmentObject(friendStore)
                    .environmentObject(studentStore)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: "schedule_scan")
        }
        .sheet(isPresented: $showScanPreview) {
            ScheduleScanPreviewSheet(
                courses: scannedCourses,
                onSave: { kept in saveScannedCourses(kept) }
            )
        }
        .onChange(of: scanPickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await runScheduleScan(newItems) }
        }
    }

    // MARK: - Actions (ekle · fotoğraftan tara)

    private var actionsCard: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.impact(.light)
                showingAdd = true
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .black))
                    Text(tr("wk_sched_add_manual"))
                        .font(.system(size: 15, weight: .heavy))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [UpdoTheme.cyan, Color(arenaHex: "#22D3EE")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)

            scanButton

            Text(tr("wk_sched_scan_sub"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let scanError {
                Text(scanError)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(coral)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    @ViewBuilder
    private var scanButton: some View {
        if subscription.isPro {
            PhotosPicker(
                selection: $scanPickerItems,
                maxSelectionCount: 4,
                matching: .images
            ) {
                scanButtonLabel
            }
            .disabled(isScanning)
        } else {
            Button {
                Haptics.impact(.light)
                showPaywall = true
            } label: {
                scanButtonLabel
            }
            .buttonStyle(.plain)
        }
    }

    private var scanButtonLabel: some View {
        HStack(spacing: 9) {
            if isScanning {
                ProgressView().scaleEffect(0.8).tint(.black)
                Text(tr("css_scan_scanning"))
                    .font(.system(size: 15, weight: .heavy))
            } else {
                Image(systemName: subscription.isPro ? "camera.viewfinder" : "lock.fill")
                    .font(.system(size: 15, weight: .black))
                Text(tr("wk_sched_scan"))
                    .font(.system(size: 15, weight: .heavy))
                if !subscription.isPro {
                    Spacer(minLength: 0)
                    Text(tr("wk_sched_pro_badge"))
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.black.opacity(0.72))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.black.opacity(0.14)))
                }
            }
        }
        .foregroundStyle(.black)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [gold, coral],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .opacity(isScanning ? 0.75 : 1)
    }

    // MARK: - Gün grupları

    private func dayGroup(_ weekday: Int, _ events: [EventItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localizedWeekdayFull(weekday).uppercased())
                .font(.system(size: 11, weight: .black))
                .tracking(1.4)
                .foregroundStyle(.secondary.opacity(0.8))
                .padding(.leading, 2)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                ForEach(events) { event in
                    eventRow(event)
                }
            }
        }
    }

    private func eventRow(_ event: EventItem) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(arenaHex: event.colorHex))
                .frame(width: 3, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(rowMeta(event))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                delete(event)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(coral.opacity(0.9))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.05)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(cardBackground)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(UpdoTheme.cyan.opacity(0.75))

            Text(tr("wk_sched_empty_title"))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)

            Text(tr("wk_sched_empty_sub"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.045))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
    }

    // MARK: - Veri

    /// Sadece haftalık tekrar eden (scheduledDate == nil), kullanıcıya ait etkinlikler.
    private var recurringEvents: [EventItem] {
        guard let userID = session.currentUser?.id else { return [] }
        return allEvents.filter {
            $0.ownerUserID == userID.uuidString && $0.scheduledDate == nil
        }
    }

    private var eventsByWeekday: [(weekday: Int, events: [EventItem])] {
        let grouped = Dictionary(grouping: recurringEvents) { min(max($0.weekday, 0), 6) }
        return (0...6).compactMap { day in
            guard let evs = grouped[day], !evs.isEmpty else { return nil }
            return (day, evs.sorted { $0.startMinute < $1.startMinute })
        }
    }

    private var todayWeekday: Int {
        let wd = Calendar.current.component(.weekday, from: Date()) // 1=Paz … 7=Cmt
        return (wd + 5) % 7 // Pzt=0
    }

    // MARK: - Mutasyonlar

    private func delete(_ event: EventItem) {
        Haptics.notify(.warning)
        let remaining = currentUserEvents().filter { $0.id != event.id }

        context.delete(event)
        do {
            try context.save()
        } catch {
            Log.debug("WeeklyScheduleEditor.delete error:", error)
            return
        }

        WidgetAppSync.refreshFromSwiftData(context: context)
        rescheduleAndSync(with: remaining)
    }

    private func saveScannedCourses(_ kept: [ScannedScheduleCourse]) {
        guard !kept.isEmpty else { return }

        let palette = ["#22D3EE", "#8B5CF6", "#F59E0B", "#34D399", "#F472B6", "#60A5FA", "#F97316"]

        for (index, course) in kept.enumerated() {
            studentStore.addCourse(
                name: course.name,
                code: course.code,
                colorHex: palette[index % palette.count],
                sourceType: "ai_scan"
            )
        }

        let parsed = kept.map { course in
            ParsedCourse(
                code: course.code,
                name: course.name,
                slots: course.slots.map {
                    ParsedCourseSlot(
                        weekday: $0.weekday,
                        startMinute: $0.startMinute,
                        durationMinute: $0.durationMinute,
                        room: $0.room
                    )
                }
            )
        }

        studentStore.createScheduleEvents(from: parsed)
        WidgetAppSync.refreshFromSwiftData(context: context)
        rescheduleAndSync(with: currentUserEvents())
        HapticManager.shared.success()
    }

    private func runScheduleScan(_ items: [PhotosPickerItem]) async {
        isScanning = true
        scanError = nil

        var images: [UIImage] = []
        for item in items.prefix(4) {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }

        scanPickerItems = []

        guard !images.isEmpty else {
            isScanning = false
            scanError = tr("css_scan_err_generic")
            return
        }

        do {
            let courses = try await ScheduleScanClient.scan(images)
            isScanning = false

            if courses.isEmpty {
                scanError = tr("css_scan_none")
            } else {
                scannedCourses = courses
                showScanPreview = true
                HapticManager.shared.success()
            }
        } catch {
            isScanning = false
            scanError = error.localizedDescription
        }
    }

    // MARK: - Yardımcılar

    /// Kayıt/silme sonrası, context'ten taze fetch — @Query snapshot'ının
    /// gecikmesine takılmadan bildirim/haftalık paylaşımı güncel tutar.
    private func currentUserEvents() -> [EventItem] {
        guard let userID = session.currentUser?.id else { return [] }
        let all = (try? context.fetch(FetchDescriptor<EventItem>())) ?? []
        return all.filter { $0.ownerUserID == userID.uuidString }
    }

    private func rescheduleAndSync(with events: [EventItem]) {
        Task {
            await NotificationManager.shared.rescheduleAll(events: events)
        }
        Task {
            guard let userID = session.currentUser?.id else { return }
            await friendStore.resyncSharedWeekIfNeeded(for: userID, events: events)
        }
    }

    private func rowMeta(_ event: EventItem) -> String {
        let start = hm(event.startMinute)
        let end = hm(event.startMinute + event.durationMinute)
        let loc = (event.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let locText = loc.isEmpty ? "" : " · \(loc)"
        return "\(start)–\(end)\(locText)"
    }

    private func hm(_ minute: Int) -> String {
        let m = max(0, min(1439, minute))
        return String(format: "%02d:%02d", m / 60, m % 60)
    }
}
