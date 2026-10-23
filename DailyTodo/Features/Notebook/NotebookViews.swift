//
//  NotebookViews.swift
//  DailyTodo
//
//  Notebook (Defter) screens.
//  • iPad: pages on the left (notebook = course chips + page list), the open
//    page on the right — paper, typed text and Apple Pencil ink on the same
//    page (Kalem / Metin), Özetle and Updo AI'a sor.
//  • iPhone: read-only — browse pages, read text + ink + summary, send a page
//    to Updo AI.
//

import SwiftUI
import PencilKit

// MARK: - Root

struct NotebookRootView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var studentStore: StudentStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = NotebookStore.shared

    /// nil = all notebooks.
    @State private var selectedCourse: String? = nil
    @State private var selectedNoteID: UUID? = nil
    /// iPad: the page fills the screen (list hidden) — entered when writing
    /// starts, left with the ✕ at the page's top-left.
    @State private var isFullPage = false
    /// The page whose full-page mode was closed by hand: writing on it
    /// doesn't jump back to full page (until another page is opened).
    @State private var fullPageDismissedFor: UUID? = nil

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        Group {
            if isPad {
                padLayout
            } else {
                NavigationStack {
                    NotebookPageList(
                        selectedCourse: $selectedCourse,
                        selectedNoteID: $selectedNoteID,
                        canWrite: false,
                        onClose: { dismiss() }
                    )
                    .navigationDestination(item: $selectedNoteID) { id in
                        NotebookReaderView(noteID: id, onSentToChat: { dismiss() })
                    }
                }
            }
        }
        .background(UpdoTheme.background.ignoresSafeArea())
        .updoColorScheme()
        .onAppear { store.activate(userID: session.currentUser?.id.uuidString) }
    }

    private var padLayout: some View {
        HStack(spacing: 0) {
            if !isFullPage {
                NotebookPageList(
                    selectedCourse: $selectedCourse,
                    selectedNoteID: $selectedNoteID,
                    canWrite: true,
                    onClose: { dismiss() }
                )
                .frame(width: 340)
                .transition(.move(edge: .leading).combined(with: .opacity))

                Rectangle().fill(UpdoTheme.border).frame(width: 1).ignoresSafeArea()
                    .transition(.opacity)
            }

            Group {
                if let id = selectedNoteID, store.note(id) != nil {
                    NotebookEditorView(
                        noteID: id,
                        isFullPage: isFullPage,
                        onStartedWriting: {
                            guard !isFullPage, fullPageDismissedFor != id else { return }
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { isFullPage = true }
                        },
                        onExitFullPage: {
                            fullPageDismissedFor = id
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) { isFullPage = false }
                        },
                        onSentToChat: { dismiss() },
                        onDeleted: {
                            selectedNoteID = nil
                            withAnimation(.snappy) { isFullPage = false }
                        }
                    )
                    .id(id)
                } else {
                    NotebookEmptyPage {
                        let note = store.createNote(course: selectedCourse)
                        selectedNoteID = note.id
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if selectedNoteID == nil { selectedNoteID = store.liveNotes.first?.id }
        }
        .onChange(of: selectedNoteID) { _, _ in fullPageDismissedFor = nil }
    }
}

// MARK: - Colors per course

@MainActor
enum NotebookColors {
    static func color(for course: String?, in courses: [Course]) -> Color {
        guard let course else { return Color(arenaHex: "#7C3AED") }
        if let hex = courses.first(where: { $0.name.caseInsensitiveCompare(course) == .orderedSame })?.colorHex {
            return Color(arenaHex: hex)
        }
        let palette = ["#22D3EE", "#8B5CF6", "#F59E0B", "#34D399", "#F472B6", "#60A5FA", "#F97316"]
        let index = abs(course.lowercased().unicodeScalars.reduce(0) { $0 &+ Int($1.value) }) % palette.count
        return Color(arenaHex: palette[index])
    }
}

// MARK: - Page list (notebooks + pages)

struct NotebookPageList: View {
    @Binding var selectedCourse: String?
    @Binding var selectedNoteID: UUID?
    let canWrite: Bool
    let onClose: () -> Void

    @EnvironmentObject private var studentStore: StudentStore
    @ObservedObject private var store = NotebookStore.shared

    private var notebooks: [String] {
        var names = studentStore.courses.filter { !$0.isArchived }.map(\.name)
        for course in store.courses where !names.contains(where: { $0.caseInsensitiveCompare(course) == .orderedSame }) {
            names.append(course)
        }
        return names
    }

    private var pages: [NotebookNote] {
        let all = store.liveNotes
        guard let selectedCourse else { return all }
        return all.filter { ($0.course ?? "").caseInsensitiveCompare(selectedCourse) == .orderedSame }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 12)

            notebookChips
                .padding(.bottom, 10)

            if pages.isEmpty {
                emptyList
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(pages) { note in
                            pageRow(note)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(UpdoFloatingRail.panelBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(UpdoTheme.filmy(0.8))
                    .frame(width: 36, height: 36)
                    .liquidGlass(in: Circle())
                    .overlay(Circle().strokeBorder(UpdoTheme.border, lineWidth: 1))
                    .contentShape(.hoverEffect, Circle())
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel(tr("common_close"))

            VStack(alignment: .leading, spacing: 0) {
                Text(tr("nb_eyebrow"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.8)
                    .foregroundStyle(UpdoTheme.cyan)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(tr("nb_title_first"))
                        .font(.system(size: 23, weight: .black))
                        .foregroundStyle(UpdoTheme.textPrimary)
                    Text(tr("nb_title_italic"))
                        .font(.system(size: 21, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(LinearGradient(colors: [UpdoTheme.cyan, UpdoTheme.purple],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .lineLimit(1)
                .fixedSize()
            }

            Spacer(minLength: 0)

            if store.isSyncing {
                ProgressView().controlSize(.small)
            } else if store.syncFailed {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(UpdoTheme.filmy(0.45))
                    .accessibilityLabel(tr("nb_offline"))
            }

            if canWrite {
                Button {
                    let note = store.createNote(course: selectedCourse)
                    withAnimation(.snappy) { selectedNoteID = note.id }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(LinearGradient(colors: [UpdoTheme.cyan, Color(arenaHex: "#1593FF")],
                                                                 startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .contentShape(.hoverEffect, Circle())
                }
                .buttonStyle(.plain)
                .hoverEffect(.lift)
                .keyboardShortcut("n", modifiers: .command)
                .accessibilityLabel(tr("nb_new_page"))
            }
        }
    }

    private var notebookChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: tr("nb_all"), color: UpdoTheme.cyan, isOn: selectedCourse == nil) {
                    selectedCourse = nil
                }
                ForEach(notebooks, id: \.self) { course in
                    chip(title: course,
                         color: NotebookColors.color(for: course, in: studentStore.courses),
                         isOn: selectedCourse?.caseInsensitiveCompare(course) == .orderedSame) {
                        selectedCourse = course
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(title: String, color: Color, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            withAnimation(.snappy) { action() }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isOn ? UpdoTheme.textPrimary : UpdoTheme.filmy(0.6))
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(isOn ? color.opacity(0.22) : UpdoTheme.filmy(0.05)))
            .overlay(Capsule().strokeBorder(isOn ? color.opacity(0.55) : UpdoTheme.border, lineWidth: 1))
            .contentShape(.hoverEffect, Capsule())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }

    private func pageRow(_ note: NotebookNote) -> some View {
        let isSelected = selectedNoteID == note.id
        let tint = NotebookColors.color(for: note.course, in: studentStore.courses)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button {
            Haptics.selection()
            selectedNoteID = note.id
        } label: {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(tint)
                    .frame(width: 4)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(note.displayTitle)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundStyle(UpdoTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(appRelativeDate(note.updatedAt))
                        if let course = note.course {
                            Text("·")
                            Text(course).lineLimit(1)
                        }
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(UpdoTheme.filmy(0.45))

                    if !note.preview.isEmpty {
                        Text(note.preview)
                            .font(.system(size: 12.5))
                            .foregroundStyle(UpdoTheme.filmy(0.6))
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                VStack(spacing: 6) {
                    if note.hasDrawing {
                        Image(systemName: "pencil.tip")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(UpdoTheme.filmy(0.45))
                    }
                    if note.summary != nil {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(UpdoTheme.cyan.opacity(0.8))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(isSelected ? tint.opacity(0.14) : UpdoTheme.filmy(0.035)))
            .overlay(shape.strokeBorder(isSelected ? tint.opacity(0.5) : UpdoTheme.border, lineWidth: 1))
            .contentShape(.hoverEffect, shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .contextMenu {
            if canWrite {
                Button(role: .destructive) {
                    if selectedNoteID == note.id { selectedNoteID = nil }
                    store.delete(note.id)
                } label: {
                    Label(tr("nb_delete_page"), systemImage: "trash")
                }
            }
        }
    }

    private var emptyList: some View {
        VStack(spacing: 10) {
            Image(systemName: "book.closed")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(UpdoTheme.filmy(0.35))
            Text(canWrite ? tr("nb_empty_list") : tr("nb_empty_list_phone"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Empty page (iPad)

struct NotebookEmptyPage: View {
    let onNew: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "pencil.and.scribble")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [UpdoTheme.cyan, UpdoTheme.purple],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(tr("nb_empty_title"))
                .font(.title2.weight(.bold))
                .foregroundStyle(UpdoTheme.textPrimary)
            Text(tr("nb_empty_sub"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            Button(action: onNew) {
                Label(tr("nb_new_page"), systemImage: "square.and.pencil")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(UpdoTheme.onAccent)
                    .padding(.horizontal, 22)
                    .frame(height: 46)
                    .background(Capsule().fill(LinearGradient(colors: [Color(arenaHex: "#1593FF"), UpdoTheme.purple],
                                                              startPoint: .leading, endPoint: .trailing)))
                    .contentShape(.hoverEffect, Capsule())
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ArenaBackground(primaryGlow: UpdoTheme.purple, secondaryGlow: UpdoTheme.cyan,
                                    warmGlow: Color(arenaHex: "#FF5A44"), intensity: 0.6).ignoresSafeArea())
    }
}

// MARK: - Paper

struct NotebookPaperBackground: View {
    let paper: NotebookPaper
    static let lineSpacing: CGFloat = 34
    static let topMargin: CGFloat = 26

    var body: some View {
        Canvas { context, size in
            let ink = Color.adaptive(light: Color(arenaHex: "#9DB4D6"), dark: Color(arenaHex: "#5B7BB0"))
            switch paper {
            case .lined:
                var y = Self.topMargin + Self.lineSpacing
                while y < size.height {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(ink.opacity(0.32)), lineWidth: 1)
                    y += Self.lineSpacing
                }
            case .grid:
                let step: CGFloat = 26
                var path = Path()
                var x: CGFloat = 0
                while x < size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += step }
                var y: CGFloat = 0
                while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += step }
                context.stroke(path, with: .color(ink.opacity(0.2)), lineWidth: 0.8)
            case .dotted:
                let step: CGFloat = 26
                var y: CGFloat = step
                while y < size.height {
                    var x: CGFloat = step
                    while x < size.width {
                        context.fill(Path(ellipseIn: CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4)),
                                     with: .color(ink.opacity(0.45)))
                        x += step
                    }
                    y += step
                }
            case .blank:
                break
            }
        }
        .background(Color.adaptive(light: Color(arenaHex: "#FFFDF7"), dark: Color(arenaHex: "#0D1424")))
        .allowsHitTesting(false)
    }
}

// MARK: - PencilKit canvas

struct NotebookCanvas: UIViewRepresentable {
    let initialDrawing: PKDrawing
    let isPenMode: Bool
    /// Page look: ink and the tool palette follow it (black ink shows white).
    var isDark: Bool = true
    let onChange: (PKDrawing) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = initialDrawing
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        // With an Apple Pencil, fingers keep scrolling the page.
        canvas.drawingPolicy = UIPencilInteraction.prefersPencilOnlyDrawing ? .pencilOnly : .anyInput
        canvas.tool = PKInkingTool(.pen, color: .label, width: 3)
        canvas.delegate = context.coordinator
        context.coordinator.canvas = canvas
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.onChange = onChange
        canvas.isUserInteractionEnabled = isPenMode
        canvas.overrideUserInterfaceStyle = isDark ? .dark : .light
        let picker = context.coordinator.toolPicker
        picker.colorUserInterfaceStyle = isDark ? .dark : .light
        picker.addObserver(canvas)
        picker.setVisible(isPenMode, forFirstResponder: canvas)
        if isPenMode {
            DispatchQueue.main.async { canvas.becomeFirstResponder() }
        } else if canvas.isFirstResponder {
            canvas.resignFirstResponder()
        }
    }

    static func dismantleUIView(_ canvas: PKCanvasView, coordinator: Coordinator) {
        coordinator.toolPicker.setVisible(false, forFirstResponder: canvas)
        coordinator.toolPicker.removeObserver(canvas)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var onChange: (PKDrawing) -> Void
        let toolPicker = PKToolPicker()
        weak var canvas: PKCanvasView?

        init(onChange: @escaping (PKDrawing) -> Void) { self.onChange = onChange }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            onChange(canvasView.drawing)
        }
    }
}

// MARK: - Editor (iPad)

struct NotebookEditorView: View {
    let noteID: UUID
    var isFullPage: Bool = false
    var onStartedWriting: () -> Void = {}
    var onExitFullPage: () -> Void = {}
    let onSentToChat: () -> Void
    let onDeleted: () -> Void

    @Environment(\.colorScheme) private var appColorScheme
    /// Page look, remembered: "light" / "dark", or follow the app ("").
    @AppStorage("notebook.paperStyle") private var paperStyle = ""
    private var pageIsDark: Bool {
        paperStyle.isEmpty ? appColorScheme == .dark : paperStyle == "dark"
    }

    @EnvironmentObject private var studentStore: StudentStore
    @ObservedObject private var store = NotebookStore.shared

    @State private var title = ""
    @State private var text = ""
    @State private var drawing = PKDrawing()
    @State private var drawingLoaded = false
    /// The text as loaded — typing past it counts as "started writing".
    @State private var loadedText: String? = nil
    @State private var isPenMode = true
    @State private var saveTask: Task<Void, Never>?
    @State private var isSummarizing = false
    @State private var summaryError: String?
    @State private var showSummary = true
    @State private var showDeleteConfirm = false
    @FocusState private var textFocused: Bool

    private var note: NotebookNote? { store.note(noteID) }
    private var tint: Color { NotebookColors.color(for: note?.course, in: studentStore.courses) }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 10)

            if showSummary, let summary = note?.summary {
                summaryCard(summary)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if let summaryError {
                Text(summaryError)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(arenaHex: "#FF5A44"))
                    .padding(.horizontal, 22)
                    .padding(.bottom, 8)
            }

            page
        }
        .background(UpdoTheme.background.ignoresSafeArea())
        .task { await load() }
        .onDisappear { flushSave() }
        .confirmationDialog(tr("nb_delete_confirm"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(tr("nb_delete_page"), role: .destructive) {
                store.delete(noteID)
                onDeleted()
            }
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(alignment: .center, spacing: 12) {
            if isFullPage {
                // Back to the page list (and from there, out of the notebook).
                Button(action: onExitFullPage) {
                    toolbarIcon("xmark")
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel(tr("nb_exit_full"))
                .transition(.scale.combined(with: .opacity))
            }

            VStack(alignment: .leading, spacing: 4) {
                courseMenu
                TextField(tr("nb_title_placeholder"), text: $title)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(UpdoTheme.textPrimary)
                    .submitLabel(.done)
                    .onChange(of: title) { _, _ in scheduleTextSave() }
            }

            Spacer(minLength: 12)

            modeSwitch

            Button {
                Haptics.selection()
                withAnimation(.easeInOut(duration: 0.25)) { paperStyle = pageIsDark ? "light" : "dark" }
            } label: {
                toolbarIcon(pageIsDark ? "moon.fill" : "sun.max.fill")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .accessibilityLabel(tr(pageIsDark ? "nb_page_light" : "nb_page_dark"))

            paperMenu

            aiMenu

            Button {
                showDeleteConfirm = true
            } label: {
                toolbarIcon("trash")
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .accessibilityLabel(tr("nb_delete_page"))
        }
    }

    private var courseMenu: some View {
        Menu {
            Button(tr("nb_general")) { store.update(noteID) { $0.course = nil } }
            ForEach(studentStore.courses.filter { !$0.isArchived }, id: \.id) { course in
                Button(course.name) { store.update(noteID) { $0.course = course.name } }
            }
        } label: {
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 8, height: 8)
                Text((note?.course ?? tr("nb_general")).uppercased())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.4)
                Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(tint)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var modeSwitch: some View {
        HStack(spacing: 2) {
            modeButton(pen: true, icon: "pencil.tip", label: tr("nb_mode_pen"))
            modeButton(pen: false, icon: "keyboard", label: tr("nb_mode_text"))
        }
        .padding(3)
        .background(Capsule().fill(UpdoTheme.filmy(0.06)))
        .overlay(Capsule().strokeBorder(UpdoTheme.border, lineWidth: 1))
    }

    private func modeButton(pen: Bool, icon: String, label: String) -> some View {
        let isOn = isPenMode == pen
        return Button {
            Haptics.selection()
            withAnimation(.snappy) { isPenMode = pen }
            if !pen { DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { textFocused = true } }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13, weight: .bold))
                Text(label).font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(isOn ? Color.black : UpdoTheme.filmy(0.7))
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background { if isOn { Capsule().fill(UpdoTheme.cyan) } }
            .contentShape(.hoverEffect, Capsule())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var paperMenu: some View {
        Menu {
            ForEach(NotebookPaper.allCases) { paper in
                Button {
                    store.update(noteID) { $0.paper = paper }
                } label: {
                    Label(tr(paper.titleKey), systemImage: note?.paper == paper ? "checkmark" : paper.icon)
                }
            }
        } label: {
            toolbarIcon(note?.paper.icon ?? "line.3.horizontal")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr("nb_paper"))
    }

    private var aiMenu: some View {
        Menu {
            Button {
                Task { await summarize() }
            } label: {
                Label(note?.summary == nil ? tr("nb_ai_summarize") : tr("nb_ai_resummarize"), systemImage: "sparkles")
            }
            Button {
                sendToChat()
            } label: {
                Label(tr("nb_ai_ask"), systemImage: "bubble.left.and.text.bubble.right")
            }
        } label: {
            HStack(spacing: 7) {
                if isSummarizing {
                    ProgressView().controlSize(.small).tint(.white)
                } else {
                    UpdoAIOrb(mode: .idle, size: 16)
                }
                Text("Updo AI").font(.system(size: 13.5, weight: .bold))
            }
            .foregroundStyle(UpdoTheme.onAccent)
            .padding(.horizontal, 14)
            .frame(height: 38)
            .background(Capsule().fill(LinearGradient(colors: [Color(arenaHex: "#1593FF"), UpdoTheme.purple],
                                                      startPoint: .leading, endPoint: .trailing)))
            .contentShape(.hoverEffect, Capsule())
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .disabled(isSummarizing)
    }

    private func toolbarIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(UpdoTheme.filmy(0.8))
            .frame(width: 38, height: 38)
            .liquidGlass(in: Circle())
            .overlay(Circle().strokeBorder(UpdoTheme.border, lineWidth: 1))
            .contentShape(.hoverEffect, Circle())
    }

    // MARK: Summary

    private func summaryCard(_ summary: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(tr("nb_summary"), systemImage: "sparkles")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(UpdoTheme.cyan)
                Spacer()
                Button {
                    withAnimation(.snappy) { showSummary = false }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(UpdoTheme.filmy(0.5))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("nb_summary_hide"))
            }
            ScrollView {
                AIRichTextView(blocks: AIRichParser.parse(summary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 220)
        }
        .padding(16)
        .background(shape.fill(UpdoTheme.cyan.opacity(0.07)))
        .overlay(shape.strokeBorder(UpdoTheme.cyan.opacity(0.3), lineWidth: 1))
    }

    // MARK: Page

    private var page: some View {
        GeometryReader { geo in
            let height = max(geo.size.height, 1100) + CGFloat(note?.pageHeight ?? 0)
            ScrollView {
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        NotebookPaperBackground(paper: note?.paper ?? .lined)

                        TextField(isPenMode ? "" : tr("nb_text_placeholder"), text: $text, axis: .vertical)
                            .font(.system(size: 19))
                            .lineSpacing(NotebookPaperBackground.lineSpacing - 22.7)
                            .foregroundStyle(UpdoTheme.textPrimary)
                            .focused($textFocused)
                            .padding(.horizontal, 36)
                            .padding(.top, NotebookPaperBackground.topMargin + 7)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .allowsHitTesting(!isPenMode)
                            .onChange(of: text) { old, new in
                                scheduleTextSave()
                                if let loadedText, new != loadedText { onStartedWriting() }
                            }

                        if drawingLoaded {
                            NotebookCanvas(initialDrawing: drawing, isPenMode: isPenMode, isDark: pageIsDark) { newDrawing in
                                drawing = newDrawing
                                scheduleDrawingSave()
                                onStartedWriting()
                            }
                        }
                    }
                    // The page has its own light / dark, independent of the app.
                    .environment(\.colorScheme, pageIsDark ? .dark : .light)
                    .frame(height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(UpdoTheme.border, lineWidth: 1))

                    Button {
                        store.update(noteID) { $0.pageHeight += 800 }
                    } label: {
                        Label(tr("nb_extend_page"), systemImage: "plus")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(UpdoTheme.filmy(0.7))
                            .padding(.horizontal, 16)
                            .frame(height: 38)
                            .background(Capsule().fill(UpdoTheme.filmy(0.06)))
                            .contentShape(.hoverEffect, Capsule())
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                    .padding(.vertical, 18)
                }
                .padding(.horizontal, 22)
            }
            .scrollIndicators(.automatic)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    // MARK: Load / save

    private func load() async {
        guard let note else { return }
        title = note.title
        text = note.body
        loadedText = note.body
        isPenMode = note.body.isEmpty || note.hasDrawing
        if let data = await store.drawingData(for: noteID), let loaded = try? PKDrawing(data: data) {
            drawing = loaded
        }
        drawingLoaded = true
    }

    private func scheduleTextSave() {
        guard let note, title != note.title || text != note.body else { return }
        let newTitle = title, newText = text
        store.update(noteID) {
            $0.title = newTitle
            $0.body = newText
        }
    }

    private func scheduleDrawingSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(0.8))
            guard !Task.isCancelled else { return }
            store.saveDrawing(noteID, data: drawing.dataRepresentation(), isEmpty: drawing.strokes.isEmpty)
        }
    }

    private func flushSave() {
        if saveTask != nil {
            saveTask?.cancel()
            store.saveDrawing(noteID, data: drawing.dataRepresentation(), isEmpty: drawing.strokes.isEmpty)
        }
    }

    // MARK: AI

    private func summarize() async {
        guard let note else { return }
        flushSave()
        summaryError = nil
        isSummarizing = true
        defer { isSummarizing = false }
        do {
            let summary = try await NotebookAI.summarize(note, drawing: drawing)
            store.update(noteID) { $0.summary = summary }
            withAnimation(.snappy) { showSummary = true }
            Haptics.notify(.success)
        } catch {
            summaryError = (error as? LocalizedError)?.errorDescription ?? tr("nb_ai_failed")
        }
    }

    private func sendToChat() {
        guard let note else { return }
        flushSave()
        guard let image = NotebookAI.pageImage(note, drawing: drawing) else { return }
        NotebookChatHandoff.shared.send(image: image, title: note.displayTitle)
        onSentToChat()
    }
}

// MARK: - Reader (iPhone)

struct NotebookReaderView: View {
    let noteID: UUID
    let onSentToChat: () -> Void

    @EnvironmentObject private var studentStore: StudentStore
    @ObservedObject private var store = NotebookStore.shared
    @State private var ink: UIImage?
    @State private var drawing: PKDrawing?

    private var note: NotebookNote? { store.note(noteID) }

    var body: some View {
        ScrollView {
            if let note {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Circle().fill(NotebookColors.color(for: note.course, in: studentStore.courses)).frame(width: 8, height: 8)
                            Text((note.course ?? tr("nb_general")).uppercased())
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .tracking(1.4)
                                .foregroundStyle(UpdoTheme.filmy(0.55))
                            Text("· " + appRelativeDate(note.updatedAt))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(UpdoTheme.filmy(0.4))
                        }
                        Text(note.displayTitle)
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(UpdoTheme.textPrimary)
                    }

                    if let summary = note.summary {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(tr("nb_summary"), systemImage: "sparkles")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .tracking(1.4)
                                .foregroundStyle(UpdoTheme.cyan)
                            AIRichTextView(blocks: AIRichParser.parse(summary))
                                .textSelection(.enabled)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(UpdoTheme.cyan.opacity(0.07)))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(UpdoTheme.cyan.opacity(0.3), lineWidth: 1))
                    }

                    if !note.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(note.body)
                            .font(.system(size: 17))
                            .foregroundStyle(UpdoTheme.textPrimary)
                            .textSelection(.enabled)
                    }

                    if let ink {
                        Image(uiImage: ink)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
                            .accessibilityLabel(tr("nb_handwriting"))
                    } else if note.hasDrawing {
                        ProgressView().frame(maxWidth: .infinity).padding(30)
                    }
                }
                .padding(20)
            }
        }
        .background(UpdoTheme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    guard let note, let image = NotebookAI.pageImage(note, drawing: drawing) else { return }
                    NotebookChatHandoff.shared.send(image: image, title: note.displayTitle)
                    onSentToChat()
                } label: {
                    Label(tr("nb_ai_send"), systemImage: "paperplane.fill")
                }
            }
        }
        .task {
            if let data = await store.drawingData(for: noteID), let loaded = try? PKDrawing(data: data) {
                drawing = loaded
                ink = NotebookAI.inkImage(loaded)
            }
        }
    }
}

// MARK: - Profile card

/// Profile's entry to the notebook — the size the streak calendar had. Empty,
/// it previews what a page looks like (paper, handwriting, a formula, the AI
/// summary chip); with pages, the latest page as a little sheet of paper
/// beside the most recent pages.
struct NotebookProfileCard: View {
    let onOpen: () -> Void

    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var studentStore: StudentStore
    @ObservedObject private var store = NotebookStore.shared

    /// The preview area's height (≈ the old streak calendar card in total).
    private static let previewHeight: CGFloat = 190

    var body: some View {
        let pages = store.liveNotes
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 16) {
                header(pages)

                Group {
                    if let latest = pages.first {
                        filledPreview(latest: latest, pages: pages)
                    } else {
                        emptyPreview
                    }
                }
                .frame(height: Self.previewHeight)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(shape.fill(LinearGradient(colors: [UpdoTheme.cyan.opacity(0.08), UpdoTheme.purple.opacity(0.06), UpdoTheme.filmy(0.03)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(shape.strokeBorder(UpdoTheme.filmy(0.08), lineWidth: 1))
            .contentShape(.hoverEffect, shape)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .onAppear { store.activate(userID: session.currentUser?.id.uuidString) }
    }

    private func header(_ pages: [NotebookNote]) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "book.pages.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: [UpdoTheme.cyan, UpdoTheme.purple],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 42, height: 42)
                .background(Circle().fill(UpdoTheme.cyan.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(tr("nb_eyebrow"))
                    .font(.system(size: 10.5, weight: .black, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(UpdoTheme.cyan)
                Text(pages.isEmpty ? tr("nb_card_empty") : (appLanguageIsEnglish() && pages.count == 1 ? "1 page" : tr("nb_card_count", pages.count)))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(UpdoTheme.textPrimary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(UpdoTheme.filmy(0.35))
        }
    }

    // MARK: Empty — a sample page

    private var emptyPreview: some View {
        HStack(alignment: .center, spacing: 16) {
            NotebookSamplePage()
                .frame(width: UIDevice.current.userInterfaceIdiom == .pad ? 168 : 138)
                .rotationEffect(.degrees(-2.5))
                .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 10) {
                Text(UIDevice.current.userInterfaceIdiom == .pad ? tr("nb_card_hint_pad") : tr("nb_card_hint_phone"))
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(UpdoTheme.filmy(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                // Writing happens on iPad; the phone reads and sends to AI.
                if UIDevice.current.userInterfaceIdiom == .pad {
                    VStack(alignment: .leading, spacing: 7) {
                        featureLine("pencil.tip", tr("nb_feat_pen"))
                        featureLine("keyboard", tr("nb_feat_text"))
                        featureLine("sparkles", tr("nb_feat_ai"))
                    }

                    Label(tr("nb_new_page"), systemImage: "square.and.pencil")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Capsule().fill(LinearGradient(colors: [UpdoTheme.cyan, Color(arenaHex: "#1593FF")],
                                                                  startPoint: .leading, endPoint: .trailing)))
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func featureLine(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(UpdoTheme.cyan)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(UpdoTheme.filmy(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    // MARK: With pages — the latest page + recent list

    private func filledPreview(latest: NotebookNote, pages: [NotebookNote]) -> some View {
        HStack(alignment: .top, spacing: 16) {
            NotebookPageThumbnail(note: latest,
                                  tint: NotebookColors.color(for: latest.course, in: studentStore.courses))
                .frame(width: 150)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(pages.prefix(4)) { note in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(NotebookColors.color(for: note.course, in: studentStore.courses))
                            .frame(width: 3, height: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(note.displayTitle)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(UpdoTheme.filmy(0.9))
                                .lineLimit(1)
                            Text([note.course, appRelativeDate(note.updatedAt)]
                                .compactMap { $0 }.joined(separator: " · "))
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(UpdoTheme.filmy(0.45))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if note.summary != nil {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(UpdoTheme.cyan.opacity(0.8))
                        }
                        if note.hasDrawing {
                            Image(systemName: "pencil.tip")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(UpdoTheme.filmy(0.4))
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A made-up page for the empty card: lined paper, a handwritten title, a
/// pen-drawn curve, a formula and the AI summary chip.
private struct NotebookSamplePage: View {
    private var ink: Color { Color.adaptive(light: Color(arenaHex: "#1E2A44"), dark: Color(arenaHex: "#E8EEFF")) }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        ZStack(alignment: .topLeading) {
            NotebookPaperBackground(paper: .lined)

            VStack(alignment: .leading, spacing: 6) {
                Text(tr("nb_preview_title"))
                    .font(.system(size: 17, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // A quick pen sketch: axes and a parabola, underlined in cyan.
                Canvas { context, size in
                    var axes = Path()
                    axes.move(to: CGPoint(x: 6, y: size.height - 6))
                    axes.addLine(to: CGPoint(x: size.width - 6, y: size.height - 6))
                    axes.move(to: CGPoint(x: size.width / 2, y: 4))
                    axes.addLine(to: CGPoint(x: size.width / 2, y: size.height - 2))
                    context.stroke(axes, with: .color(ink.opacity(0.5)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

                    var curve = Path()
                    let w = size.width - 24, h = size.height - 14
                    for step in 0...24 {
                        let t = Double(step) / 24
                        let x = 12 + w * t
                        let y = 4 + h * pow(2 * t - 1, 2)
                        if step == 0 { curve.move(to: CGPoint(x: x, y: y)) } else { curve.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(curve, with: .color(UpdoTheme.cyan), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                }
                .frame(height: 52)

                Text(tr("nb_preview_formula"))
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(ink.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            HStack(spacing: 4) {
                Image(systemName: "sparkles").font(.system(size: 9, weight: .bold))
                Text(tr("nb_preview_chip")).font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Capsule().fill(LinearGradient(colors: [Color(arenaHex: "#1593FF"), UpdoTheme.purple],
                                                      startPoint: .leading, endPoint: .trailing)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(8)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(UpdoTheme.filmy(0.12), lineWidth: 1))
        .shadow(color: UpdoTheme.cardShadow(0.35), radius: 12, y: 6)
        .accessibilityHidden(true)
    }
}

/// The latest page as a small sheet of paper: its title, a few lines of text
/// and its ink.
private struct NotebookPageThumbnail: View {
    let note: NotebookNote
    let tint: Color

    @State private var ink: UIImage?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        ZStack(alignment: .topLeading) {
            NotebookPaperBackground(paper: note.paper)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Circle().fill(tint).frame(width: 6, height: 6)
                    Text(note.displayTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(UpdoTheme.textPrimary)
                        .lineLimit(1)
                }
                if !note.preview.isEmpty {
                    Text(note.preview)
                        .font(.system(size: 9.5))
                        .foregroundStyle(UpdoTheme.filmy(0.7))
                        .lineLimit(4)
                }
                if let ink {
                    Image(uiImage: ink)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(UpdoTheme.filmy(0.12), lineWidth: 1))
        .shadow(color: UpdoTheme.cardShadow(0.3), radius: 10, y: 5)
        .accessibilityHidden(true)
        .task(id: note.drawingUpdatedAt ?? note.updatedAt) {
            guard note.hasDrawing,
                  let data = NotebookStore.shared.cachedDrawingData(for: note.id),
                  let drawing = try? PKDrawing(data: data) else {
                ink = nil
                return
            }
            // Ink in the card's own appearance (white on dark paper).
            let bounds = drawing.bounds
            ink = drawing.image(from: CGRect(x: 0, y: 0, width: max(bounds.maxX, 1), height: max(bounds.maxY, 1)), scale: 1)
        }
    }
}
