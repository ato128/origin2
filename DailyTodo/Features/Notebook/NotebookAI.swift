//
//  NotebookAI.swift
//  DailyTodo
//
//  Notebook ↔ Updo AI:
//  • Özetle — the page (typed text + the ink as an image) goes to the coach,
//    the summary is saved on the page (so every device sees it).
//  • Updo AI'a sor — the page is rendered into one picture and waits in the
//    Home chat's composer, like a question photo; the student types the ask.
//

import SwiftUI
import PencilKit

extension Notification.Name {
    /// A notebook page was sent to Updo AI: open Home's chat with it attached.
    static let notebookPageToChat = Notification.Name("notebookPageToChat")
    static let openHomeTab = Notification.Name("openHomeTab")
}

/// Hands a rendered page to the Home chat (which may not exist yet).
@MainActor
final class NotebookChatHandoff {
    static let shared = NotebookChatHandoff()
    private init() {}

    private(set) var pending: (image: UIImage, prompt: String)?

    func send(image: UIImage, title: String) {
        pending = (image, tr("nb_ask_prefill", title))
        NotificationCenter.default.post(name: .openHomeTab, object: nil)
        NotificationCenter.default.post(name: .notebookPageToChat, object: nil)
    }

    func consume() -> (image: UIImage, prompt: String)? {
        defer { pending = nil }
        return pending
    }
}

enum NotebookAIError: LocalizedError {
    case noCredits(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .noCredits(let message): return message
        case .empty: return tr("nb_ai_empty")
        }
    }
}

@MainActor
enum NotebookAI {
    /// The page as a picture: light paper, the typed text, then the ink —
    /// what the model reads and what the chat bubble shows.
    static func pageImage(_ note: NotebookNote, drawing: PKDrawing?) -> UIImage? {
        let ink = drawing.flatMap { inkImage($0) }
        let renderer = ImageRenderer(content: NotebookPageSnapshot(note: note, ink: ink))
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: NotebookPageSnapshot.width, height: nil)
        return renderer.uiImage
    }

    /// The strokes rendered in light mode (dark ink on paper), from the page's
    /// top-left so their positions match the text.
    static func inkImage(_ drawing: PKDrawing) -> UIImage? {
        guard !drawing.strokes.isEmpty else { return nil }
        let bounds = drawing.bounds
        let rect = CGRect(x: 0, y: 0, width: max(bounds.maxX, 1), height: max(bounds.maxY, 1))
        var image: UIImage?
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = drawing.image(from: rect, scale: 2)
        }
        return image
    }

    /// Summarizes the page with the coach; spends chat credits like a message.
    static func summarize(_ note: NotebookNote, drawing: PKDrawing?) async throws -> String {
        let credits = DailyCreditsManager.shared
        guard credits.canSendChatMessage else { throw NotebookAIError.noCredits(credits.limitMessage) }

        let text = note.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let ink = drawing.flatMap { inkImage($0) }
        guard !text.isEmpty || ink != nil else { throw NotebookAIError.empty }

        let english = appLanguageIsEnglish()
        let system = english
            ? """
              You are Updo AI, a study coach. Summarize the student's notebook page for revision. \
              Start with a one-line gist, then the key ideas as short bullet points, then any \
              formulas/definitions (LaTeX for math), and end with one "Watch out in the exam" line. \
              Read handwriting from the image carefully; if something is illegible, say so briefly. \
              Be concise. Reply in English.
              """
            : """
              Sen Updo AI'sın, bir çalışma koçu. Öğrencinin defter sayfasını tekrar için özetle. \
              Önce tek satırlık özü, sonra ana fikirleri kısa maddeler halinde, ardından varsa \
              formül/tanımları (matematik için LaTeX) yaz; sonunda tek satır "Sınavda dikkat" ekle. \
              Görseldeki el yazısını dikkatle oku; okunmayan yer varsa kısaca belirt. \
              Kısa ve net ol. Türkçe yanıt ver.
              """

        var content = english ? "Notebook page" : "Defter sayfası"
        if let course = note.course { content += " — \(course)" }
        content += "\n\(english ? "Title" : "Başlık"): \(note.displayTitle)"
        if !text.isEmpty {
            content += "\n\n\(english ? "Typed notes" : "Yazılı notlar"):\n\(String(text.prefix(12_000)))"
        }
        if ink != nil {
            content += "\n\n" + (english ? "The handwriting/drawings are in the image." : "El yazısı/çizimler görselde.")
        }

        var message: [String: Any] = ["role": "user", "content": content]
        if let ink, let jpeg = AIChatImageStore.prepareJPEG(ink) {
            message["images"] = [jpeg.base64EncodedString()]
        }

        let (reply, _) = try await AIService.shared.coachChat(system: system, messages: [message], maxTokens: 700)
        credits.noteMessageSent()
        Task { await credits.refresh() }
        let summary = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !summary.isEmpty else { throw NotebookAIError.empty }
        return summary
    }
}

/// What `pageImage` renders: a light page with the title, typed text and ink.
struct NotebookPageSnapshot: View {
    static let width: CGFloat = 900

    let note: NotebookNote
    let ink: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(note.displayTitle)
                .font(.system(size: 30, weight: .bold))
            if let course = note.course {
                Text(course.uppercased())
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundStyle(.gray)
            }
            let text = note.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                Text(text)
                    .font(.system(size: 19))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let ink {
                Image(uiImage: ink)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: min(ink.size.width, Self.width - 64), alignment: .leading)
            }
        }
        .foregroundStyle(.black)
        .padding(32)
        .frame(width: Self.width, alignment: .leading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }
}
