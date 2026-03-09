//
//  TodoListView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//

import SwiftUI
import SwiftData
import UIKit
import Combine

struct TodoListView: View {
    @Binding var selectedTab: AppTab
    @EnvironmentObject private var store: TodoStore
    
    @Query(sort: \EventItem.startMinute, order: .forward)
    private var allEvents: [EventItem]
    
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case today = "Today"
        case overdue = "Overdue"
        var id: String { rawValue }
    }
    
    enum NextClassStatus {
        case live
        case next
    }
    
    enum TopSection: String, CaseIterable, Identifiable {
        case home = "Home"
        case tasks = "Tasks"
        var id: String { rawValue }
    }
    
    @State private var searchText: String = ""
    @State private var filter: Filter = .all
    @State private var showDone: Bool = true
    
    @State private var showingAdd: Bool = false
    @State private var editingItem: DTTaskItem? = nil
    
    @State private var animatingTaskID: PersistentIdentifier? = nil
    @State private var sparkleTaskID: PersistentIdentifier? = nil
    @State private var topSection: TopSection = .home
    @State private var searchExpanded: Bool = false
    @FocusState private var searchFocused: Bool
    
    private let chipTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    @State private var now = Date()
    
    private var items: [DTTaskItem] { store.items }
    
    private var filteredItems: [DTTaskItem] {
        let q = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        var base = items
        
        if !showDone {
            base = base.filter { !$0.isDone }
        }
        
        if !q.isEmpty {
            base = base.filter {
                $0.title.lowercased().contains(q)
            }
        }
        
        switch filter {
        case .all:
            break
            
        case .today:
            base = base.filter { item in
                guard let d = item.dueDate else { return false }
                return Calendar.current.isDate(d, inSameDayAs: Date())
            }
            
        case .overdue:
            base = base.filter { store.isOverdue($0) }
        }
        
        let now = Date()
        
        return base.sorted { a, b in
            let aDate = a.dueDate ?? .distantFuture
            let bDate = b.dueDate ?? .distantFuture
            
            let aDiff = abs(aDate.timeIntervalSince(now))
            let bDiff = abs(bDate.timeIntervalSince(now))
            
            return aDiff < bDiff
        }
    }
    
    private var nextClassInfo: (title: String, timeText: String, status: NextClassStatus)? {
        let today = weekdayIndexToday()
        let nowMinute = currentMinuteOfDay()
        
        let todayEvents = allEvents
            .filter { $0.weekday == today }
            .sorted { $0.startMinute < $1.startMinute }
        
        if let live = todayEvents.first(where: {
            nowMinute >= $0.startMinute &&
            nowMinute < ($0.startMinute + $0.durationMinute)
        }) {
            let endMinute = live.startMinute + live.durationMinute
            let remain = max(0, endMinute - nowMinute)
            return (live.title, "\(remain) dk", .live)
        }
        
        if let next = todayEvents.first(where: { $0.startMinute > nowMinute }) {
            let remain = max(0, next.startMinute - nowMinute)
            return (next.title, "\(remain) dk", .next)
        }
        
        return nil
    }
    var body : some View {
        VStack(spacing: 0) {
            tasksHeader
            
            topSegment
            
            Group {
                if topSection == .home {
                    HomeDashboardView(
                        onAddTask: {
                            showingAdd = true
                            haptic(.medium)
                        },
                        onOpenWeek: {
                            selectedTab = .week
                        },
                        onOpenInsights: {
                            selectedTab = .insights
                        }
                    )
                    .environmentObject(store)
                } else {
                    if filteredItems.isEmpty {
                        emptyState
                    } else {
                        list
                    }
                }
            }
        }
        
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingAdd) {
            AddTaskView()
                .environmentObject(store)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                EditTaskView(item: item)
                    .environmentObject(store)
            }
            .presentationDetents([.medium, .large])
        }
        .overlay(alignment: .bottomTrailing) {
            if topSection == .tasks {
                floatingAddButton
            }
        }
        .onReceive(chipTimer) { value in
            now = value
        }
        .onChange(of: topSection) { _, newValue in
            if newValue != .tasks {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    searchExpanded = false
                    searchText = ""
                }
                searchFocused = false
            }
        }
    }
    
    private var topSegment: some View {
        VStack(spacing: 8) {
            Picker("", selection: $topSection) {
                ForEach(TopSection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
        .background(Color(.systemGroupedBackground))
    }
    private var tasksHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text(topSection == .home ? "Home" : "Tasks")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.primary)
                    .scaleEffect(searchExpanded && topSection == .tasks ? 0.95 : 1.0, anchor: .leading)
                    .offset(y: searchExpanded && topSection == .tasks ? -10 : 0)
                    .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.82, blendDuration: 0.08), value: searchExpanded)
                
                Spacer()
                
                if topSection == .tasks {
                    animatedSearchBar
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
    }
    private var animatedSearchBar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(
                    color: .black.opacity(searchExpanded ? 0.14 : 0.08),
                    radius: searchExpanded ? 12 : 6,
                    x: 0,
                    y: 4
                )
            
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .frame(maxWidth: searchExpanded ? nil : .infinity, alignment: .center)
                
                if searchExpanded {
                    TextField("Search", text: $searchText)
                        .focused($searchFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .transition(.opacity)
                    
                    if !searchText.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                searchText = ""
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    Button {
                        searchFocused = false
                        
                        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.84, blendDuration: 0.12)) {
                            searchExpanded = false
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            searchText = ""
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, searchExpanded ? 14 : 0)
            .frame(maxWidth: .infinity, alignment: searchExpanded ? .leading : .center)
            .clipped()
        }
        .frame(width: searchExpanded ? 236 : 56, height: 56)
        .scaleEffect(searchExpanded ? 1.0 : 0.98)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !searchExpanded else { return }
            
            withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.84, blendDuration: 0.12)) {
                searchExpanded = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                searchFocused = true
            }
        }
        .animation(.interactiveSpring(response: 0.26, dampingFraction: 0.82, blendDuration: 0.08), value: searchExpanded)
        .animation(.easeInOut(duration: 0.18), value: searchText.isEmpty)
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checklist")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.secondary)
            
            Text("Henüz görev yok")
                .font(.title3.weight(.semibold))
            
            Text("Sağ alttaki + ile yeni görev ekleyebilirsin.")
                .foregroundStyle(.secondary)
            
            Button {
                showingAdd = true
                haptic(.medium)
            } label: {
                Label("İlk görevi ekle", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .padding(.top, 50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var list: some View {
        List {
            Section {
                ForEach(filteredItems) { item in
                    row(item)
                        .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                handleToggle(item)
                            } label: {
                                Label(
                                    item.isDone ? "Geri al" : "Tamamla",
                                    systemImage: item.isDone ? "arrow.uturn.left" : "checkmark"
                                )
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.delete(item)
                                haptic(.heavy)
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }
    
    private func row(_ item: DTTaskItem) -> some View {
        let isAnimating = animatingTaskID == item.id
        let showSparkle = sparkleTaskID == item.id
        
        return Button {
            editingItem = item
        } label: {
            HStack(spacing: 10) {
                Button {
                    handleToggle(item)
                } label: {
                    ZStack {
                        if showSparkle {
                            SparkleBurstView()
                                .frame(width: 34, height: 34)
                                .transition(.scale.combined(with: .opacity))
                        }
                        
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(item.isDone ? .green : .secondary)
                            .scaleEffect(isAnimating ? 1.22 : 1.0)
                            .shadow(
                                color: item.isDone
                                ? .green.opacity(isAnimating ? 0.45 : 0.0)
                                : .clear,
                                radius: isAnimating ? 8 : 0
                            )
                    }
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .strikethrough(item.isDone, color: .secondary)
                            .opacity(item.isDone ? 0.6 : 1.0)
                            .lineLimit(2)
                        
                        Spacer(minLength: 8)
                        
                        if let badge = badgeText(for: item) {
                            Text(badge.text)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(badge.background))
                                .foregroundStyle(badge.foreground)
                                .scaleEffect(item.isDone && animatingTaskID == item.id ? 1.18 : 1.0)
                                .animation(.spring(response: 0.28, dampingFraction: 0.55), value: animatingTaskID == item.id)
                        }
                    }
                    
                    if let d = item.dueDate {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text(d, style: .date)
                            Text("•")
                            Text(d, style: .time)
                        }
                        .font(.caption)
                        .foregroundStyle(store.isOverdue(item) && !item.isDone ? .red : .secondary)
                    }
                }
                
                if store.isOverdue(item) && !item.isDone {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(item.isDone && isAnimating ? Color.green.opacity(0.08) : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                item.isDone
                                ? Color.green.opacity(isAnimating ? 0.35 : 0.12)
                                : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
            .scaleEffect(isAnimating ? 1.02 : 1.0)
            .opacity(item.isDone ? 0.88 : 1.0)
            .shadow(
                color: item.isDone
                ? .green.opacity(isAnimating ? 0.18 : 0.0)
                : .clear,
                radius: isAnimating ? 12 : 0,
                y: 4
            )
            .animation(.spring(response: 0.34, dampingFraction: 0.68), value: isAnimating)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func handleToggle(_ item: DTTaskItem) {
        let wasDone = item.isDone
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            store.toggleDone(item)
            animatingTaskID = item.id
        }
        
        if !wasDone {
            sparkleTaskID = item.id
            haptic(.rigid)
            notifySuccess()
            NotificationCenter.default.post(name: .taskCompleted, object: nil)
        } else {
            haptic(.light)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                animatingTaskID = nil
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeOut(duration: 0.2)) {
                sparkleTaskID = nil
            }
        }
    }
    
    private func badgeText(for item: DTTaskItem) -> (text: String, background: Color, foreground: Color)? {
        if item.isDone {
            return ("DONE", .green.opacity(0.16), .green)
        }
        
        if store.isOverdue(item) {
            return ("LATE", .red.opacity(0.16), .red)
        }
        
        if let d = item.dueDate, Calendar.current.isDate(d, inSameDayAs: Date()) {
            return ("TODAY", .orange.opacity(0.18), .orange)
        }
        
        return nil
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                
                Toggle("Done göster", isOn: $showDone)
                
                Button("Yenile") {
                    store.reload()
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            if let next = nextClassInfo {
                Button {
                    withAnimation(.easeInOut) {
                        selectedTab = .week
                    }
                    haptic(.light)
                } label: {
                    LiveBadgeView(next: next)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var floatingAddButton: some View {
        Button {
            showingAdd = true
            haptic(.medium)
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Circle().fill(Color.accentColor))
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }
    
    private func currentMinuteOfDay() -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: now)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    
    private func weekdayIndexToday() -> Int {
        let w = Calendar.current.component(.weekday, from: now)
        return (w + 5) % 7
    }
    
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }
    
    private func notifySuccess() {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(.success)
    }
    
    
    private struct SparkleBurstView: View {
        @State private var animate = false
        
        var body: some View {
            ZStack {
                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(
                            index.isMultiple(of: 2)
                            ? Color.yellow
                            : Color.green.opacity(0.9)
                        )
                        .frame(width: 5, height: 5)
                        .offset(y: animate ? -18 : 0)
                        .rotationEffect(.degrees(Double(index) * 45))
                        .scaleEffect(animate ? 1 : 0.2)
                        .opacity(animate ? 0 : 1)
                        .animation(
                            .easeOut(duration: 0.45).delay(Double(index) * 0.01),
                            value: animate
                        )
                }
            }
            .onAppear {
                animate = true
            }
        }
    }
    
    private struct LiveBadgeView: View {
        let next: (title: String, timeText: String, status: TodoListView.NextClassStatus)
        
        var body: some View {
            let isLive = next.status == .live
            
            return HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isLive ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                        .shadow(
                            color: isLive
                            ? Color.green.opacity(0.45)
                            : Color.orange.opacity(0.35),
                            radius: isLive ? 6 : 4
                        )
                        .scaleEffect(isLive ? 1.08 : 1.0)
                        .animation(
                            isLive
                            ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                            : .default,
                            value: isLive
                        )
                    
                    Text(isLive ? "LIVE" : "NEXT")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isLive ? .green : .orange)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(
                            isLive
                            ? Color.green.opacity(0.15)
                            : Color.orange.opacity(0.15)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isLive
                            ? Color.green.opacity(0.22)
                            : Color.orange.opacity(0.22),
                            lineWidth: 0.8
                        )
                )
                
                VStack(alignment: .leading, spacing: 0) {
                    Text(next.title.uppercased())
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    
                    Text(next.timeText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(height: 34)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .blur(radius: 0.1)
            .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
        }
    }
}
