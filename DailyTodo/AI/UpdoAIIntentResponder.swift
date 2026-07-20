//
//  UpdoAIIntentResponder.swift
//  DailyTodo
//
//  Token'sız yerel "akıllı koç" katmanı: en sık sorulan, kullanıcının KENDİ
//  verisiyle cevaplanabilen sorular (bugünkü plan, haftalık istatistik, seri,
//  motivasyon, selamlaşma) hiç API'ye gitmeden anında yanıtlanır. Komut
//  yorumlayıcıdan (görev ekle/sil) sonra, ücretli LLM'den önce çalışır.
//
//  Kural: sadece KISA ve net kalıplar yakalanır — uzun/karmaşık mesajlar
//  gerçek sohbettir, LLM'e gider.
//

import Foundation

enum UpdoAIIntentResponder {

    struct Context {
        let openTasks: [String]        // en fazla 5 açık görev başlığı
        let todayFocusMinutes: Int
        let weekFocusMinutes: Int
        let weekSessionCount: Int
        let streak: Int
    }

    /// Yerel cevap; nil = LLM'e düş.
    static func answer(_ text: String, context: Context) -> String? {
        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Uzun mesajlar kişisel bağlam taşır — yerel kalıba sokma.
        guard normalized.count <= 70 else { return nil }

        let en = appLanguageIsEnglish()

        if matches(normalized, [
            "bugün ne yap", "bugün ne çalış", "bugünkü plan", "bugün plan",
            "nereden başla", "ne yapmalıyım",
            "what should i do today", "today's plan", "where do i start"
        ]) {
            return todayPlanReply(context: context, en: en)
        }

        if matches(normalized, [
            "bu hafta kaç", "ne kadar çalıştım", "kaç saat çalıştım",
            "haftalık istatistik", "istatistiklerim",
            "how much did i study", "how much did i focus", "my stats"
        ]) {
            return weekStatsReply(context: context, en: en)
        }

        if matches(normalized, [
            "serim ne", "serim kaç", "kaç günlük seri", "seri durumu", "serim nasıl",
            "my streak", "streak"
        ]) {
            return streakReply(context: context, en: en)
        }

        if matches(normalized, [
            "motivasyon", "motive et", "moral ver", "motive ol",
            "motivate me", "i need motivation"
        ]) {
            return motivationReply(context: context, en: en)
        }

        if ["selam", "merhaba", "naber", "hey", "hi", "hello", "sa", "selamlar"]
            .contains(normalized) {
            return greetingReply(context: context, en: en)
        }

        return nil
    }

    private static func matches(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    // MARK: - Replies (gerçek veriyle doldurulur)

    private static func todayPlanReply(context: Context, en: Bool) -> String {
        if context.openTasks.isEmpty {
            return en
            ? "Your list is clear right now. Add one small task for today, then start a 25-minute focus on it — momentum beats planning."
            : "Şu an listen boş. Bugün için küçük bir görev ekle, sonra ona 25 dakikalık bir focus başlat — momentum plandan önemli."
        }

        let list = context.openTasks.prefix(4).map { "• \($0)" }.joined(separator: "\n")

        return en
        ? "Here's what's open:\n\(list)\nPick the smallest one and start a 25-minute focus on it. One finished task changes the whole day."
        : "Açık görevlerin şunlar:\n\(list)\nEn küçüğünü seç ve ona 25 dakikalık focus başlat. Bitmiş tek görev bile günün tamamını değiştirir."
    }

    private static func weekStatsReply(context: Context, en: Bool) -> String {
        let hours = context.weekFocusMinutes / 60
        let mins = context.weekFocusMinutes % 60
        let timeText = hours > 0
            ? (en ? "\(hours)h \(mins)m" : "\(hours) sa \(mins) dk")
            : (en ? "\(mins)m" : "\(mins) dk")

        if context.weekFocusMinutes == 0 {
            return en
            ? "No focus logged in the last 7 days yet. Start with just one 25-minute session today — the chart starts moving with the first bar."
            : "Son 7 günde henüz odak kaydın yok. Bugün tek bir 25 dakikalık seansla başla — grafik ilk çubukla hareketlenir."
        }

        return en
        ? "Last 7 days: \(timeText) of focus across \(context.weekSessionCount) sessions" +
          (context.todayFocusMinutes > 0 ? ", \(context.todayFocusMinutes)m of it today. " : ". ") +
          "Keep the rhythm — same time tomorrow."
        : "Son 7 gün: \(context.weekSessionCount) seansta toplam \(timeText) odak" +
          (context.todayFocusMinutes > 0 ? ", bugün \(context.todayFocusMinutes) dk. " : ". ") +
          "Ritmi koru — yarın aynı saatte devam."
    }

    private static func streakReply(context: Context, en: Bool) -> String {
        if context.streak <= 0 {
            return en
            ? "No active streak right now — today is the perfect day 1. Finish one task and one focus session and the flame lights up."
            : "Şu an aktif serin yok — bugün mükemmel bir 1. gün. Bir görev + bir focus tamamla, alev yansın."
        }

        return en
        ? "Your streak is \(context.streak) days 🔥 Don't break the chain: one task and one focus today keeps it alive."
        : "Serin \(context.streak) gün 🔥 Zinciri kırma: bugün bir görev ve bir focus, seriyi yaşatır."
    }

    private static func motivationReply(context: Context, en: Bool) -> String {
        if context.streak > 0 {
            return en
            ? "You've shown up \(context.streak) days in a row — that's not luck, that's who you're becoming. Open one task, give it 25 minutes, and let today count too."
            : "\(context.streak) gündür buradasın — bu şans değil, kim olduğunun kanıtı. Bir görev aç, 25 dakika ver, bugün de saysın."
        }

        return en
        ? "Motivation follows action, not the other way around. Pick the easiest task on your list and start a 25-minute focus — you'll feel it kick in by minute five."
        : "Motivasyon harekete gelir, hareket motivasyona değil. Listendeki en kolay görevi seç ve 25 dakikalık focus başlat — beşinci dakikada geldiğini hissedeceksin."
    }

    private static func greetingReply(context: Context, en: Bool) -> String {
        let taskPart: String
        if context.openTasks.isEmpty {
            taskPart = en ? "Your list is clear" : "Listen temiz"
        } else {
            taskPart = en
            ? "You have \(context.openTasks.count) open task\(context.openTasks.count > 1 ? "s" : "")"
            : "\(context.openTasks.count) açık görevin var"
        }

        return en
        ? "Hey! \(taskPart). Want a plan for today, or shall we start a focus session?"
        : "Selam! \(taskPart). Bugün için plan ister misin, yoksa direkt bir focus mu başlatalım?"
    }
}
