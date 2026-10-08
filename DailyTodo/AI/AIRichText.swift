//
//  AIRichText.swift
//  DailyTodo
//
//  Renders Updo AI replies as a document instead of a chat bubble: headings,
//  lists, code blocks and real typeset math (SwiftMath, CoreText — no WebView).
//  The backend asks the model for Markdown + LaTeX only when the client sends
//  `render: "rich"`, so older app versions keep getting plain text.
//

import SwiftUI
import UIKit
import SwiftMath

// MARK: - Blocks

enum AIRichBlock: Equatable {
    enum Marker: Equatable { case bullet, number(String) }

    case paragraph(String)
    case heading(String, level: Int)
    case listItem(Marker, String, indent: Int)
    /// Display equation (`$$…$$`).
    case math(String)
    /// The final answer (`$$\boxed{…}$$`), shown as a highlighted card.
    case result(String)
    case code(language: String, body: String)
    case rule
}

enum AIRichParser {

    /// Splits a reply into blocks. While `streaming`, a half-written trailing
    /// equation / `$…` / `**` is held back so raw LaTeX never flashes on screen.
    static func parse(_ raw: String, streaming: Bool = false) -> [AIRichBlock] {
        var blocks: [AIRichBlock] = []
        var prose: [String] = []
        var code: [String]? = nil
        var codeLanguage = ""

        func flushProse(isEnd: Bool) {
            guard !prose.isEmpty else { return }
            blocks += parseProse(prose.joined(separator: "\n"), streaming: streaming && isEnd)
            prose.removeAll()
        }

        for line in raw.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if let body = code {
                    blocks.append(.code(language: codeLanguage, body: body.joined(separator: "\n")))
                    code = nil
                } else {
                    flushProse(isEnd: false)
                    codeLanguage = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    code = []
                }
            } else if code != nil {
                code?.append(line)
            } else {
                prose.append(line)
            }
        }
        if let body = code {
            // Unclosed fence: still show it (it's being written, or the model forgot).
            blocks.append(.code(language: codeLanguage, body: body.joined(separator: "\n")))
        }
        flushProse(isEnd: true)
        return blocks
    }

    // MARK: Prose

    private static func parseProse(_ text: String, streaming: Bool) -> [AIRichBlock] {
        let parts = normalizeDelimiters(text).components(separatedBy: "$$")
        var blocks: [AIRichBlock] = []
        for (i, part) in parts.enumerated() {
            let isLast = i == parts.count - 1
            if i % 2 == 0 {
                blocks += parseLines(isLast && streaming ? holdBackOpenInline(part) : part)
            } else if isLast {
                // `$$` opened but never closed.
                if !streaming { blocks += parseLines("$$" + part) }
            } else {
                let latex = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !latex.isEmpty else { continue }
                blocks.append(AIMath.containsBoxed(latex) ? .result(latex) : .math(latex))
            }
        }
        return blocks
    }

    /// `\[ \]` → `$$`, `\( \)` → `$` (models use both conventions).
    private static func normalizeDelimiters(_ s: String) -> String {
        guard s.contains("\\[") || s.contains("\\(") else { return s }
        return s
            .replacingOccurrences(of: "\\[", with: "$$")
            .replacingOccurrences(of: "\\]", with: "$$")
            .replacingOccurrences(of: "\\(", with: "$")
            .replacingOccurrences(of: "\\)", with: "$")
    }

    /// Streaming: hide an unclosed `$…` / `**` on the line being written.
    private static func holdBackOpenInline(_ s: String) -> String {
        let lineStart = s.range(of: "\n", options: .backwards)?.upperBound ?? s.startIndex
        var line = String(s[lineStart...])
        if AIInline.mathRanges(in: line).unmatchedOpen, let r = line.range(of: "$", options: .backwards) {
            line = String(line[..<r.lowerBound])
        }
        if line.components(separatedBy: "**").count % 2 == 0, let r = line.range(of: "**", options: .backwards) {
            line.removeSubrange(r)
        }
        return String(s[..<lineStart]) + line
    }

    private static let headingRegex = try! NSRegularExpression(pattern: #"^(#{1,4})\s+(.+?)\s*#*$"#)
    private static let bulletRegex = try! NSRegularExpression(pattern: #"^(\s*)[-*•]\s+(.*)$"#)
    private static let numberRegex = try! NSRegularExpression(pattern: #"^(\s*)(\d{1,3})[.)]\s+(.*)$"#)

    private static func parseLines(_ text: String) -> [AIRichBlock] {
        var blocks: [AIRichBlock] = []
        var paragraph: [String] = []

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))) }
            paragraph.removeAll()
        }

        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let ns = line as NSString
            let full = NSRange(location: 0, length: ns.length)

            if trimmed.isEmpty {
                flush()
            } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flush(); blocks.append(.rule)
            } else if let m = headingRegex.firstMatch(in: trimmed, range: NSRange(location: 0, length: (trimmed as NSString).length)) {
                flush()
                let t = trimmed as NSString
                let title = t.substring(with: m.range(at: 2)).replacingOccurrences(of: "**", with: "")
                blocks.append(.heading(title, level: m.range(at: 1).length))
            } else if let m = numberRegex.firstMatch(in: line, range: full) {
                flush()
                blocks.append(.listItem(.number(ns.substring(with: m.range(at: 2))),
                                        ns.substring(with: m.range(at: 3)),
                                        indent: indentLevel(m.range(at: 1).length)))
            } else if let m = bulletRegex.firstMatch(in: line, range: full) {
                flush()
                blocks.append(.listItem(.bullet, ns.substring(with: m.range(at: 2)),
                                        indent: indentLevel(m.range(at: 1).length)))
            } else if let only = soleInlineMath(trimmed) {
                // A line that is nothing but `$…$` reads better as a display equation.
                flush()
                blocks.append(AIMath.containsBoxed(only) ? .result(only) : .math(only))
            } else {
                paragraph.append(trimmed)
            }
        }
        flush()
        return blocks
    }

    private static func indentLevel(_ spaces: Int) -> Int { min(2, spaces / 2) }

    private static func soleInlineMath(_ s: String) -> String? {
        guard s.hasPrefix("$"), s.hasSuffix("$"), s.count > 2 else { return nil }
        let ranges = AIInline.mathRanges(in: s)
        guard ranges.ranges.count == 1, let r = ranges.ranges.first,
              r.lowerBound == s.startIndex, r.upperBound == s.endIndex else { return nil }
        return String(s.dropFirst().dropLast())
    }

    /// Plain text for the clipboard: delimiters dropped, LaTeX kept.
    static func plainText(_ raw: String) -> String {
        AIMath.stripBoxed(raw)
            .replacingOccurrences(of: "$$", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "**", with: "")
    }
}

// MARK: - Inline text ( **bold**, `code`, $math$ )

enum AIInline {

    struct MathScan {
        var ranges: [Range<String.Index>] = []
        var unmatchedOpen = false
    }

    /// Pandoc's rule: `$` opens only before a non-space, closes only after a
    /// non-space and not before a digit — so "$5 or $10" stays text.
    static func mathRanges(in s: String) -> MathScan {
        var scan = MathScan()
        var i = s.startIndex
        while i < s.endIndex {
            guard s[i] == "$", i == s.startIndex || s[s.index(before: i)] != "\\" else {
                i = s.index(after: i); continue
            }
            let afterOpen = s.index(after: i)
            guard afterOpen < s.endIndex, !s[afterOpen].isWhitespace else {
                if afterOpen == s.endIndex { scan.unmatchedOpen = true }
                i = afterOpen; continue
            }
            var j = afterOpen
            var close: String.Index? = nil
            while j < s.endIndex {
                if s[j] == "\n" { break }
                if s[j] == "$", s[s.index(before: j)] != "\\", !s[s.index(before: j)].isWhitespace {
                    let next = s.index(after: j)
                    if next == s.endIndex || !s[next].isNumber { close = j; break }
                }
                j = s.index(after: j)
            }
            if let close {
                scan.ranges.append(i..<s.index(after: close))
                i = s.index(after: close)
            } else {
                scan.unmatchedOpen = true
                i = afterOpen
            }
        }
        return scan
    }

    private static var cache: [String: Text] = [:]

    /// Inline Markdown with typeset `$math$` images flowing in the line.
    static func text(_ s: String) -> Text {
        let size = AIMath.inlineSize
        let key = "\(size)|\(s)"
        if let hit = cache[key] { return hit }

        let scan = mathRanges(in: s)
        var source = s
        var formulas: [String] = []
        // Swap each formula for a private-use placeholder so Markdown spans
        // (e.g. **Sonuç: $x$**) still parse across it.
        for r in scan.ranges.reversed() {
            let latex = String(s[s.index(after: r.lowerBound)..<s.index(before: r.upperBound)])
            formulas.insert(latex, at: 0)
            source.replaceSubrange(r, with: String(placeholder(scan.ranges.count - formulas.count)))
        }

        let attr = (try? AttributedString(
            markdown: source,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(source)

        var result = Text(verbatim: "")
        var cursor = attr.startIndex
        var idx = attr.startIndex
        while idx < attr.endIndex {
            let ch = attr.characters[idx]
            if let n = placeholderIndex(ch), n < formulas.count {
                if cursor < idx { result = result + Text(AttributedString(attr[cursor..<idx])) }
                result = result + mathText(formulas[n], size: size)
                cursor = attr.characters.index(after: idx)
            }
            idx = attr.characters.index(after: idx)
        }
        if cursor < attr.endIndex { result = result + Text(AttributedString(attr[cursor..<attr.endIndex])) }

        if cache.count > 400 { cache.removeAll(keepingCapacity: true) }
        cache[key] = result
        return result
    }

    private static func mathText(_ latex: String, size: CGFloat) -> Text {
        guard let r = AIMath.render(latex, size: size, display: false, maxWidth: AIMath.inlineMaxWidth) else {
            return Text(verbatim: AIMath.readableFallback(latex)).italic()
        }
        return Text(Image(uiImage: r.image).renderingMode(.template)).baselineOffset(-r.descent)
    }

    private static func placeholder(_ n: Int) -> Character {
        Character(UnicodeScalar(0xE000 + n)!)
    }

    private static func placeholderIndex(_ c: Character) -> Int? {
        guard let v = c.unicodeScalars.first?.value, v >= 0xE000, v < 0xE800 else { return nil }
        return Int(v - 0xE000)
    }
}

// MARK: - Math typesetting

enum AIMath {
    struct Rendered {
        let image: UIImage
        let descent: CGFloat
    }

    private final class Box: NSObject {
        let value: Rendered?
        init(_ v: Rendered?) { value = v }
    }

    private static let cache: NSCache<NSString, Box> = {
        let c = NSCache<NSString, Box>()
        c.countLimit = 400
        return c
    }()

    /// Body is SF 17 pt; XITS has a smaller x-height, so math runs a touch larger.
    static var inlineSize: CGFloat { UIFontMetrics(forTextStyle: .body).scaledValue(for: 18.5) }
    static var displaySize: CGFloat { UIFontMetrics(forTextStyle: .body).scaledValue(for: 21) }
    static let inlineMaxWidth: CGFloat = 280

    /// Typesets `latex` in black (callers draw it as a template image so it
    /// takes the text colour). Wide inline formulas are scaled down to fit.
    static func render(_ latex: String, size: CGFloat, display: Bool, maxWidth: CGFloat? = nil) -> Rendered? {
        let key = "\(display ? "D" : "I")\(size)|\(maxWidth ?? 0)|\(latex)" as NSString
        if let hit = cache.object(forKey: key) { return hit.value }

        let source = prepare(latex)
        var result: Rendered? = nil
        var fontSize = size
        for _ in 0..<3 {
            var img = MathImage(latex: source, fontSize: fontSize, textColor: .black,
                                labelMode: display ? .display : .text, textAlignment: .left)
            img.font = .xitsFont
            let (error, image, info) = img.asImage()
            guard error == nil, let image, let info, image.size.width > 0 else { break }
            result = Rendered(image: image, descent: info.descent)
            guard let maxWidth, image.size.width > maxWidth, fontSize > size * 0.7 else { break }
            fontSize = max(size * 0.7, fontSize * maxWidth / image.size.width)
        }
        cache.setObject(Box(result), forKey: key)
        return result
    }

    static func containsBoxed(_ s: String) -> Bool { s.contains("\\boxed") }

    /// `\boxed{X}` → `X` (SwiftMath has no \boxed; the card draws the box).
    static func stripBoxed(_ s: String) -> String {
        var out = s
        while let r = out.range(of: "\\boxed") {
            var i = r.upperBound
            while i < out.endIndex, out[i] == " " { i = out.index(after: i) }
            guard i < out.endIndex, out[i] == "{" else { out.removeSubrange(r); continue }
            var depth = 0
            var j = i
            var close: String.Index? = nil
            while j < out.endIndex {
                if out[j] == "{" { depth += 1 }
                if out[j] == "}" { depth -= 1; if depth == 0 { close = j; break } }
                j = out.index(after: j)
            }
            guard let close else { out.removeSubrange(r); continue }
            let inner = String(out[out.index(after: i)..<close])
            out.replaceSubrange(r.lowerBound...close, with: inner)
        }
        return out
    }

    private static let functionSpacing = try! NSRegularExpression(
        pattern: #"\\(ln|log|lg|exp|sin|cos|tan|cot|sec|csc|arcsin|arccos|arctan|sinh|cosh|tanh)((?:_\{[^}]*\}|_[^\s{\\])?(?:\^\{[^}]*\}|\^[^\s{\\])?)\s*(?=[A-Za-z0-9]|\\[A-Za-z])"#
    )

    /// Patches the handful of common commands SwiftMath doesn't know.
    private static func prepare(_ latex: String) -> String {
        var s = stripBoxed(latex)
            .replacingOccurrences(of: "\\dots", with: "\\ldots")
            .replacingOccurrences(of: "\\lvert", with: "|")
            .replacingOccurrences(of: "\\rvert", with: "|")
            .replacingOccurrences(of: "\\lVert", with: "\\|")
            .replacingOccurrences(of: "\\rVert", with: "\\|")
            .replacingOccurrences(of: "\\displaystyle", with: "")
        // `\ln x` typesets as "lnx" in SwiftMath — add TeX's thin space.
        let ns = s as NSString
        s = functionSpacing.stringByReplacingMatches(
            in: s, range: NSRange(location: 0, length: ns.length), withTemplate: "\\\\$1$2\\\\,"
        )
        return s
    }

    /// Shown when a formula can't be typeset — still readable, never raw `\frac`.
    static func readableFallback(_ latex: String) -> String {
        var s = stripBoxed(latex)
        let map: [(String, String)] = [
            ("\\cdot", "·"), ("\\times", "×"), ("\\div", "÷"), ("\\pm", "±"), ("\\le", "≤"), ("\\ge", "≥"),
            ("\\neq", "≠"), ("\\approx", "≈"), ("\\infty", "∞"), ("\\to", "→"), ("\\Rightarrow", "⇒"),
            ("\\sqrt", "√"), ("\\pi", "π"), ("\\theta", "θ"), ("\\alpha", "α"), ("\\beta", "β"),
            ("\\Delta", "Δ"), ("\\left", ""), ("\\right", ""), ("\\,", " "), ("\\;", " "), ("\\ ", " "),
            ("\\frac", ""), ("\\dfrac", ""), ("\\text", ""), ("\\mathrm", ""), ("\\", ""), ("{", ""), ("}", "")
        ]
        for (a, b) in map { s = s.replacingOccurrences(of: a, with: b) }
        return s
    }
}

// MARK: - Views

/// A whole reply laid out as a document. Each block is an `Equatable` view, so
/// while streaming only the block being written re-renders.
struct AIRichTextView: View {
    let blocks: [AIRichBlock]
    /// Streaming reveal progress for the newest glyphs (applied to the last block).
    var tail: [Double] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { i, block in
                AIRichBlockView(block: block, tail: i == blocks.count - 1 ? tail : [])
                    .equatable()
                    .padding(.top, i == 0 ? 0 : spacing(before: block, after: blocks[i - 1]))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func spacing(before block: AIRichBlock, after previous: AIRichBlock) -> CGFloat {
        switch (previous, block) {
        case (.listItem, .listItem): return 6
        case (_, .heading): return 18
        case (.heading, _): return 8
        case (_, .math), (.math, _): return 8
        case (_, .result), (_, .code): return 12
        default: return 12
        }
    }
}

private struct AIRichBlockView: View, Equatable {
    let block: AIRichBlock
    let tail: [Double]

    var body: some View {
        switch block {
        case .paragraph(let s):
            styled(AIInline.text(s))

        case .heading(let s, let level):
            styled(AIInline.text(s))
                .font(level <= 2 ? .title3.weight(.bold) : .headline)

        case .listItem(let marker, let s, let indent):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                switch marker {
                case .bullet:
                    Text(verbatim: "•")
                        .font(.body.weight(.bold))
                        .foregroundStyle(UpdoTheme.cyan)
                        .frame(minWidth: 10)
                case .number(let n):
                    Text(verbatim: "\(n).")
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(UpdoTheme.cyan)
                        .frame(minWidth: 18, alignment: .leading)
                }
                styled(AIInline.text(s))
            }
            .padding(.leading, CGFloat(indent) * 18)

        case .math(let latex):
            AIDisplayMath(latex: latex)

        case .result(let latex):
            AIResultCard(latex: latex)

        case .code(let language, let body):
            AICodeBlock(language: language, code: body)

        case .rule:
            Rectangle()
                .fill(UpdoTheme.border)
                .frame(height: 1)
                .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func styled(_ text: Text) -> some View {
        let base = text
            .font(.body)
            .lineSpacing(3)
            .foregroundStyle(UpdoTheme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
        if tail.isEmpty {
            base
        } else {
            base.textRenderer(AIStreamRevealRenderer(tail: tail))
        }
    }
}

/// A centred display equation; scrolls sideways instead of wrapping when wide.
private struct AIDisplayMath: View {
    let latex: String

    var body: some View {
        if let r = AIMath.render(latex, size: AIMath.displaySize, display: true) {
            let image = Image(uiImage: r.image).renderingMode(.template)
            ViewThatFits(in: .horizontal) {
                image
                    .frame(maxWidth: .infinity)
                ScrollView(.horizontal, showsIndicators: false) {
                    image.padding(.horizontal, 2)
                }
            }
            .foregroundStyle(UpdoTheme.textPrimary)
            .padding(.vertical, 4)
            .accessibilityLabel(Text(verbatim: AIMath.readableFallback(latex)))
        } else {
            Text(verbatim: AIMath.readableFallback(latex))
                .font(.body.italic())
                .foregroundStyle(UpdoTheme.textPrimary)
                .frame(maxWidth: .infinity)
        }
    }
}

/// The final answer, framed so it's findable at a glance.
private struct AIResultCard: View {
    let latex: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(tr("ai_result"), systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(UpdoTheme.cyan)
            AIDisplayMath(latex: latex)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(UpdoTheme.cyan.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [UpdoTheme.cyan.opacity(0.55), UpdoTheme.purple.opacity(0.45)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        )
    }
}

private struct AICodeBlock: View {
    let language: String
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: language.isEmpty ? "code" : language)
                    .font(.caption.monospaced())
                    .foregroundStyle(UpdoTheme.textMuted)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.snappy) { copied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.6))
                        withAnimation(.snappy) { copied = false }
                    }
                } label: {
                    Label(copied ? tr("ai_copied") : tr("ai_copy"),
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(copied ? UpdoTheme.lime : UpdoTheme.textMuted)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Rectangle().fill(UpdoTheme.border).frame(height: 1)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(verbatim: code)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(UpdoTheme.textPrimary)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(12)
            }
        }
        .background(UpdoTheme.surfaceHigh, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(UpdoTheme.border, lineWidth: 1))
    }
}

// MARK: - Streaming reveal

/// Draws the newest characters "settling in": each fades up from transparent,
/// rises ~3 pt and sharpens from a soft blur over `settleDuration`. Glyphs are
/// matched to the pacer's per-character progress counting from the END of the
/// text, so the effect stays anchored to the write head.
struct AIStreamRevealRenderer: TextRenderer {
    /// Settle progress (0…1) of the newest characters, newest first.
    let tail: [Double]

    var displayPadding: EdgeInsets { EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4) }

    func draw(layout: Text.Layout, in ctx: inout GraphicsContext) {
        guard !tail.isEmpty else {
            for line in layout { ctx.draw(line) }
            return
        }
        var total = 0
        for line in layout { for run in line { total += run.count } }
        let settledBefore = total - tail.count   // glyph index where the fade begins

        var index = 0
        for line in layout {
            for run in line {
                if index + run.count <= settledBefore {
                    ctx.draw(run)
                    index += run.count
                    continue
                }
                for glyph in run {
                    let fromEnd = total - 1 - index
                    index += 1
                    guard fromEnd >= 0, fromEnd < tail.count else {
                        ctx.draw(glyph)
                        continue
                    }
                    let p = tail[fromEnd]
                    let e = 1 - pow(1 - p, 3)            // ease-out cubic
                    var g = ctx
                    g.opacity = e
                    g.translateBy(x: 0, y: (1 - e) * 3)
                    if e < 0.97 { g.addFilter(.blur(radius: (1 - e) * 2.4)) }
                    g.draw(glyph)
                }
            }
        }
    }
}
