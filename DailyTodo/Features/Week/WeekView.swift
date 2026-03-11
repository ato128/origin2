//
//  WeekView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 2.03.2026.
//

import SwiftUI
import SwiftData
import UIKit
import Combine

enum WeekMode {
    case personal
    case crew
}

struct WeekView: View {
    
    @Environment(\.modelContext)  var context
    
    @Query(sort: \EventItem.startMinute, order: .forward)
    private var allEvents: [EventItem]
    @Query var allCrewTasks: [CrewTask]
    @Query private var allCrews: [Crew]
    @Query(sort: \CrewActivity.createdAt, order: .reverse)
    var allCrewActivities: [CrewActivity]
    @Query(sort: \CrewTaskComment.createdAt, order: .reverse)
    var allCrewComments: [CrewTaskComment]
    
    var crewMap: [UUID: Crew] {
        Dictionary(uniqueKeysWithValues: allCrews.map { ($0.id, $0) })
    }
    
    private let liveTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    let dayTitles = ["Pzt","Sal","Çar","Per","Cum","Cmt","Paz"]
    
    private var allEventIDs: [UUID] { allEvents.map(\.id) }
    
    var eventsForDay: [EventItem] {
        allEvents
            .filter { $0.weekday == selectedDay }
            .sorted { $0.startMinute < $1.startMinute }
    }
    
    private var eventsForDayIDs: [UUID] { eventsForDay.map(\.id) }
    
    var totalMinutesForDay: Int {
        eventsForDay.reduce(0) { $0 + $1.durationMinute }
    }
    
    var firstEventOfDay: EventItem? {
        eventsForDay.first
    }
    
    var lastEventOfDay: EventItem? {
        eventsForDay.last
    }
    
    var isTodaySelected: Bool {
        selectedDay == weekdayIndexToday()
    }
    
    var liveEventForDay: EventItem? {
        guard isTodaySelected else { return nil }
        let now = currentMinuteOfDay()
        return eventsForDay.first(where: {
            now >= $0.startMinute && now < ($0.startMinute + $0.durationMinute)
        })
    }
    
    var currentTimeIndicatorText: String? {
        guard isTodaySelected else { return nil }
        
        let now = currentMinuteOfDay()
        
        if let live = eventsForDay.first(where: { now >= $0.startMinute && now < ($0.startMinute + $0.durationMinute) }) {
            let left = max(0, (live.startMinute + live.durationMinute) - now)
            return "Şu an \(hm(now)) • \(live.title) devam ediyor • \(left) dk kaldı"
        }
        
        if let next = eventsForDay.first(where: { $0.startMinute > now }) {
            return "Şu an \(hm(now)) • Sıradaki ders \(hm(next.startMinute))"
        }
        
        if !eventsForDay.isEmpty {
            return "Şu an \(hm(now)) • Bugünkü dersler bitti"
        }
        
        return nil
    }
    
    
    @State  var selectedDay: Int = 0
    @State  var showingAdd: Bool = false
    @State  var editingEvent: EventItem? = nil
    @State  var weekMode: WeekMode = .personal
    @State private var showCopied: Bool = false
    @State  var crewPulse = false
    @State  var commentPulse = false
    @State  var selectedCrewTask: CrewTask?
    @State  var selectedCrewForDetail: Crew?
    @State  var showCrewEntrance = false
    @State  var showCrewTaskHeader = false
    @State  var showCrewTaskCards = false
    @State private var didInitialAutoScroll: Bool = false
    @State private var lastAutoScrollTargetID: UUID? = nil
    @State private var didSetInitialDay: Bool = false
    @State  var animateSummary = false
    @State  var pulseTodayDot = false
    @State  var showCompletedCrewTasks = false
    @State  var showPersonalEntrance = false
    @State  var showPersonalEventCards = false
    @State  var crewScrollOffset: CGFloat = 0
    @State  var personalScrollOffset: CGFloat = 0
    
    var body: some View {
        ScrollViewReader { proxy in
            mainList(proxy: proxy)
                .animation(.easeInOut(duration: 0.25), value: weekMode)
                .toolbar { toolbarContent }
                .sheet(isPresented: $showingAdd) {
                    NavigationStack { AddEventView(defaultWeekday: selectedDay) }
                        .presentationDetents([.medium, .large])
                }
                .sheet(item: $editingEvent) { ev in
                    NavigationStack { EditEventView(event: ev) }
                        .presentationDetents([.medium, .large])
                }
                .sheet(item: $selectedCrewTask) { task in
                    if let crew = selectedCrewForDetail {
                        NavigationStack {
                            CrewTaskDetailView(task: task, crew: crew)
                                .presentationDetents([.medium, .large])
                                .presentationDragIndicator(.visible)
                                .presentationCornerRadius(28)
                        }
                    }
                }
                .overlay(toastView, alignment: .bottom)
                .onAppear {
                    onAppear(proxy: proxy)
                    crewPulse = true
                    commentPulse = true
                }
                .onChange(of: selectedDay) { _, _ in onDayChanged(proxy: proxy) }
                .onChange(of: eventsForDayIDs) { _, _ in
                    animateSummaryCard()
                    autoScrollIfNeeded(proxy: proxy)
                }
                .onChange(of: allEventIDs) { _, _ in
                    Task { await NotificationManager.shared.rescheduleAll(events: allEvents) }
                }
                .onReceive(liveTimer) { _ in
                    Task { await LiveActivityManager.shared.autoSyncIfNeeded(events: allEvents) }
                }
                .onChange(of: weekMode) { _, newValue in
                    if newValue == .crew {
                        showPersonalEntrance = false
                        showCrewEntrance = false
                        showCrewTaskHeader = false
                        showCrewTaskCards = false
                        showPersonalEventCards = false
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                showCrewEntrance = true
                            }
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                            withAnimation(.easeOut(duration: 0.28)) {
                                showCrewTaskHeader = true
                            }
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
                                showCrewTaskCards = true
                            }
                        }
                        
                    } else {
                        showCrewEntrance = false
                        showCrewTaskHeader = false
                        showCrewTaskCards = false
                        showPersonalEntrance = false
                        showPersonalEventCards = false

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                            withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                                showPersonalEntrance = true
                            }
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                            withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                                showPersonalEventCards = true
                            }
                        }
                    }
                }
        }
    }
}
 





// MARK: - Main UI
extension WeekView {
    
    @ViewBuilder
    func mainList(proxy: ScrollViewProxy) -> some View {
        if weekMode == .personal {
            personalWeekList(proxy: proxy)
                .id("personal")
                .transition(.opacity)
        } else {
            crewWeekList
                .id("crew")
                .transition(.opacity)
                .offset(y: showCrewEntrance ? 0 : 26)
                .opacity(showCrewEntrance ? 1 : 0)
                .scaleEffect(showCrewEntrance ? 1.0 : 0.985)
                .animation(.spring(response: 0.45, dampingFraction: 0.86), value: showCrewEntrance)
        }
    }
    
    
    var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Button {
                    Haptics.impact(.light)
                    shareDay()
                } label: {
                    Label("Bu günü paylaş", systemImage: "square.and.arrow.up")
                }
                
                Button {
                    Haptics.impact(.light)
                    shareWeek()
                } label: {
                    Label("Tüm haftayı paylaş", systemImage: "calendar")
                }
                
                Button {
                    UIPasteboard.general.string = shareTextForSelectedDay()
                    Haptics.notify(.success)
                    showCopiedToast()
                } label: {
                    Label("Kopyala", systemImage: "doc.on.doc")
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            
            Button {
                Haptics.impact(.medium)
                showingAdd = true
            } label: {
                Image(systemName: "plus")
            }
        }
    }
    var toastView: some View {
        Group {
            if showCopied {
                Text("Kopyalandı")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 30)
            }
        }
    }
    var sectionCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
   

//MARK - Legacy Crew Mode
extension WeekView {
    
    
    func premiumCardFill(_ priority: String, active: Bool, soon: Bool) -> LinearGradient {
        let tint = premiumPriorityColor(priority)
        
        return LinearGradient(
            colors: [
                tint.opacity(priority == "urgent" ? 0.16 : (active ? 0.12 : 0.08)),
                Color.white.opacity(active ? 0.07 : 0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    func premiumBorderColor(_ priority: String, active: Bool, soon: Bool) -> Color {
        let tint = premiumPriorityColor(priority)
        
        if priority == "urgent" {
            return tint.opacity(active ? 0.65 : 0.42)
        }
        
        if active {
            return tint.opacity(0.50)
        }
        
        if soon {
            return tint.opacity(0.30)
        }
        
        return tint.opacity(0.18)
    }
    
    func premiumGlowColor(_ priority: String, active: Bool, soon: Bool) -> Color {
        let tint = premiumPriorityColor(priority)
        
        if priority == "urgent" {
            return tint.opacity(active ? 0.35 : 0.22)
        }
        
        if active {
            return tint.opacity(0.20)
        }
        
        if soon {
            return tint.opacity(0.10)
        }
        
        return .clear
    }
    
    func premiumPriorityBadge(_ priority: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            if priority == "urgent" {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.bold))
            }
            
            Text(priorityTitle(priority))
                .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(tint.opacity(0.16))
        )
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.28), lineWidth: 1)
        )
        .foregroundStyle(tint)
    }
    
    func premiumMetaPill(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
        )
        .foregroundStyle(tint)
    }
    
    func crewTimelineTaskCard(_ task: CrewTask, isLast: Bool) -> some View {
        let crew = allCrews.first { $0.id == task.crewID }
        let active = isTaskActive(task)
        let soon = isTaskStartingSoon(task)
        
        let tint = premiumPriorityColor(task.priority)
        let cardFill = premiumCardFill(task.priority, active: active, soon: soon)
        let border = premiumBorderColor(task.priority, active: active, soon: soon)
        let glow = premiumGlowColor(task.priority, active: active, soon: soon)
        
        return HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(tint)
                    .frame(
                        width: active ? 16 : (soon ? 13 : 11),
                        height: active ? 16 : (soon ? 13 : 11)
                    )
                    .shadow(color: glow, radius: active ? 14 : (soon ? 8 : 0))
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(active ? 0.30 : 0.10), lineWidth: 1)
                    )
                    .scaleEffect(active ? 1.15 : (soon ? 1.06 : 1.0))
                
                if !isLast {
                    LinearGradient(
                        colors: [
                            tint.opacity(active ? 0.55 : 0.22),
                            Color.white.opacity(0.06)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 6)
                }
            }
            .frame(width: 18)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    if let start = task.scheduledStartMinute {
                        HStack(spacing: 5) {
                            Image(systemName: "clock")
                            Text(hm(start))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(active ? tint : .secondary)
                    }
                    
                    Spacer()
                    
                    premiumPriorityBadge(task.priority, tint: tint)
                }
                
                Text(task.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                if let crew {
                    HStack(spacing: 6) {
                        Image(systemName: "person.3.fill")
                        Text(crew.name)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 10) {
                    premiumMetaPill(
                        icon: "flag.fill",
                        text: statusTitle(task.status),
                        tint: .secondary
                    )
                    
                    if !task.assignedTo.isEmpty {
                        premiumMetaPill(
                            icon: "person.fill",
                            text: task.assignedTo,
                            tint: tint.opacity(0.95)
                        )
                    }
                }
                
                if active {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        
                        Text("Active now")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                } else if soon {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)
                        
                        Text("Starting soon")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(border, lineWidth: active ? 1.2 : 1)
            )
            .shadow(color: glow, radius: active ? 18 : (soon ? 10 : 0))
            .scaleEffect(active ? 1.015 : 1.0)
        }
        .animation(.spring(duration: 0.28), value: active)
        .animation(.easeInOut(duration: 0.25), value: soon)
    }
}
    //MARK - Shared Time Helpers
     extension WeekView {
        func currentMinuteOfDay() -> Int {
            let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
            return (c.hour ?? 0) * 60 + (c.minute ?? 0)
        }
        func timeText(for ev: EventItem) -> String {
            let start = ev.startMinute
            let end = ev.startMinute + ev.durationMinute
            return "\(hm(start)) – \(hm(end))"
        }
        
        func hm(_ minute: Int) -> String {
            let m = max(0, min(1439, minute))
            let h = m / 60
            let mm = m % 60
            return String(format: "%02d:%02d", h, mm)
        }
        
        func durationText(_ minutes: Int) -> String {
            let h = minutes / 60
            let m = minutes % 60
            
            if h == 0 { return "\(m)dk" }
            if m == 0 { return "\(h)s" }
            return "\(h)s \(m)dk"
        }
        
        
        func weekdayIndexToday() -> Int {
            let w = Calendar.current.component(.weekday, from: Date())
            return (w + 5) % 7
        }
        func animateSummaryCard() {
            animateSummary = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                animateSummary = false
            }
        }
        
    }
   
    // MARK: - Lifecycle
     extension WeekView {
        
        func onAppear(proxy: ScrollViewProxy) {
            if !didSetInitialDay {
                didSetInitialDay = true
                selectedDay = weekdayIndexToday()
            }
            
            if !didInitialAutoScroll {
                didInitialAutoScroll = true
                autoScrollIfNeeded(proxy: proxy)
            }
            
            animateSummary = true
            pulseTodayDot = true
            showCrewTaskHeader = weekMode == .crew
            showCrewTaskCards = weekMode == .crew
            showPersonalEntrance = weekMode == .personal
            showPersonalEventCards = weekMode == .personal

            if weekMode == .crew {
                showCrewEntrance = true
            }
            
            Task {
                await NotificationManager.shared.rescheduleAll(events: allEvents)
            }
        }
        
        func onDayChanged(proxy: ScrollViewProxy) {
            lastAutoScrollTargetID = nil
            animateSummaryCard()
            autoScrollIfNeeded(proxy: proxy)
            showPersonalEventCards = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.86)) {
                    showPersonalEventCards = true
                }
            }
        }
    }
    
    
    // MARK: - Logic
 extension WeekView {
        
        func delete(_ ev: EventItem) {
            context.delete(ev)
            try? context.save()
            WidgetAppSync.refreshFromSwiftData(context: context)
            
            Task {
                await NotificationManager.shared.rescheduleAll(events: allEvents.filter { $0.id != ev.id })
            }
        }
        
        
        
        func hasConflict(_ ev: EventItem) -> Bool {
            for other in eventsForDay {
                if other.id == ev.id { continue }
                if overlaps(ev, other) { return true }
            }
            return false
        }
        
        func overlaps(_ a: EventItem, _ b: EventItem) -> Bool {
            let aStart = a.startMinute
            let aEnd = a.startMinute + a.durationMinute
            let bStart = b.startMinute
            let bEnd = b.startMinute + b.durationMinute
            return max(aStart, bStart) < min(aEnd, bEnd)
        }
        
        func autoScrollTarget(now: Int) -> EventItem? {
            guard !eventsForDay.isEmpty else { return nil }
            
            if selectedDay == weekdayIndexToday() {
                if let live = eventsForDay.first(where: { ev in
                    let s = ev.startMinute
                    let e = ev.startMinute + ev.durationMinute
                    return now >= s && now < e
                }) {
                    return live
                }
                
                if let next = eventsForDay.first(where: { $0.startMinute > now }) {
                    return next
                }
            }
            
            return eventsForDay.first
        }
        
        func autoScrollIfNeeded(proxy: ScrollViewProxy) {
            let now = currentMinuteOfDay()
            guard let target = autoScrollTarget(now: now) else { return }
            
            if lastAutoScrollTargetID == target.id { return }
            lastAutoScrollTargetID = target.id
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(target.id, anchor: .center)
                }
            }
        }
    }
    
    
    // MARK: - Share
    extension WeekView {
        
        
        
        
        func shareDay() { presentShare(text: shareTextForSelectedDay()) }
        
        func shareWeek() {
            let parts: [String] = (0..<7).map { day in shareTextForDay(day) }
            presentShare(text: parts.joined(separator: "\n\n"))
        }
        
        func presentShare(text: String) {
            let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                root.present(vc, animated: true)
            }
        }
        
        func shareTextForSelectedDay() -> String { shareTextForDay(selectedDay) }
        
        
        
        func priorityTitle(_ value: String) -> String {
            switch value {
            case "low": return "Low"
            case "medium": return "Medium"
            case "high": return "High"
            case "urgent": return "Urgent"
            default: return value.capitalized
            }
        }
        
        func statusTitle(_ value: String) -> String {
            switch value {
            case "todo": return "Todo"
            case "inProgress": return "In Progress"
            case "review": return "Review"
            case "done": return "Done"
            default: return value.capitalized
            }
        }
        
        
        func shareTextForDay(_ day: Int) -> String {
            let d = max(0, min(6, day))
            let dayName = dayTitles[d]
            
            let items = allEvents
                .filter { $0.weekday == d }
                .sorted { $0.startMinute < $1.startMinute }
            
            if items.isEmpty { return "📅 \(dayName) — Ders yok" }
            
            let lines = items.map { ev in
                let start = hm(ev.startMinute)
                let end = hm(ev.startMinute + ev.durationMinute)
                let loc = (ev.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let locText = loc.isEmpty ? "" : " • \(loc)"
                return "• \(start)–\(end)  \(ev.title)\(locText)"
            }
            
            return """
        📅 \(dayName) Programım
        
        \(lines.joined(separator: "\n"))
        
        (DailyTodo ile oluşturuldu)
        """
        }
        
        func showCopiedToast() {
            withAnimation { showCopied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                withAnimation { showCopied = false }
            }
        }
    }
    
    
  
