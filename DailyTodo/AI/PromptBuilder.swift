//
//  PromptBuilder.swift
//  DailyTodo
//

import Foundation

enum PromptBuilder {

    // MARK: - Exam Planner

    static func examPlannerSystem() -> String {
        """
        You are an expert study planner for students. \
        Create day-by-day study plans and return ONLY a valid JSON array — no markdown, no explanation.
        Each item must follow exactly: \
        {"date":"YYYY-MM-DD","topic":"string","minutes":int,"phase":"string","notes":"string"}
        Valid phase values: syllabusScan, lectureReview, noteRewrite, examples, \
        problemSet, pastQuestions, weakTopics, mockExam, finalReview
        Topic and notes should be in the language the user specifies.
        """
    }

    static func examPlannerUser(
        courseName: String,
        examType: String,
        examDate: Date,
        topics: String,
        dailyHours: Int,
        languageCode: String
    ) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        let today = fmt.string(from: Date())
        let exam = fmt.string(from: examDate)
        let lang = languageCode.hasPrefix("tr") ? "Turkish" : "English"

        return """
        Create a complete study plan for:
        - Course: \(courseName)
        - Exam type: \(examType)
        - Exam date: \(exam) (today is \(today))
        - Topics to cover: \(topics.isEmpty ? "full standard curriculum" : topics)
        - Daily available study time: \(dailyHours) hours/day (max \(dailyHours * 60) min per day total)
        - Language for topic and notes fields: \(lang)

        Rules:
        - Include every day from today up to (but not including) the exam date
        - Start with syllabusScan or lectureReview, build to problemSet and mockExam, end with finalReview
        - Weekend days can have 1.4x the normal minutes
        - Do not exceed \(dailyHours * 60) total minutes on any single day
        - Return ONLY the raw JSON array, nothing else
        """
    }

    // MARK: - Smart Insights

    static func smartInsightsSystem() -> String {
        """
        You are a study analytics assistant. Analyze data and return ONLY a valid JSON array \
        of exactly 3 insight objects — no markdown, no explanation.
        Each item: {"title":"string","body":"string","icon":"SF Symbol name","accent":"#hex"}
        Use SF Symbol names like: chart.bar.fill, brain.head.profile, flame.fill, \
        moon.stars.fill, calendar.badge.clock, bolt.fill, star.fill, target
        Colors: #3B82F6 blue, #8B5CF6 purple, #F59E0B amber, #10B981 green, #EC4899 pink, \
        #EF4444 red, #06B6D4 cyan
        Keep body under 55 words. Be specific and actionable — reference the actual numbers.
        """
    }

    static func smartInsightsUser(
        sessions: [FocusSessionRecord],
        tasks: [DTTaskItem],
        languageCode: String
    ) -> String {
        let lang = languageCode.hasPrefix("tr") ? "Turkish" : "English"
        let cal = Calendar.current
        let now = Date()
        let weekAgo = cal.date(byAdding: .day, value: -7, to: now)!

        let recent = sessions.filter { $0.startedAt >= weekAgo }
        let totalMin = recent.reduce(0) { $0 + $1.completedSeconds / 60 }
        let completedTasks = tasks.filter { $0.isDone && ($0.completedAt ?? .distantPast) >= weekAgo }.count
        let completionRate = recent.isEmpty ? 0 : Int(Double(recent.filter(\.isCompleted).count) * 100.0 / Double(recent.count))

        var hourBuckets = [Int: Int]()
        var dayBuckets = [Int: Int]()
        var courseBuckets = [String: Int]()

        for s in recent {
            let h = cal.component(.hour, from: s.startedAt)
            let d = cal.component(.weekday, from: s.startedAt)
            hourBuckets[h, default: 0] += s.completedSeconds / 60
            dayBuckets[d, default: 0] += s.completedSeconds / 60
            let name = s.title.isEmpty ? "General" : s.title
            courseBuckets[name, default: 0] += s.completedSeconds / 60
        }

        let topHours = hourBuckets.sorted { $0.value > $1.value }.prefix(3)
            .map { "\($0.key):00" }.joined(separator: ", ")

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let bestDay = dayBuckets.max { $0.value < $1.value }
            .map { dayNames[max(0, $0.key - 1)] } ?? "N/A"

        let courseList = courseBuckets.sorted { $0.value > $1.value }.prefix(4)
            .map { "\($0.key): \($0.value)min" }.joined(separator: ", ")

        let avgSession = recent.isEmpty ? 0 : totalMin / recent.count

        return """
        Analyze this student's last 7 days and return 3 personalized insights in \(lang):

        - Total focus time: \(totalMin) min across \(recent.count) sessions
        - Average session length: \(avgSession) min
        - Session completion rate: \(completionRate)%
        - Completed tasks: \(completedTasks)
        - Peak productive hours: \(topHours.isEmpty ? "no data" : topHours)
        - Best study day: \(bestDay)
        - Course/subject breakdown: \(courseList.isEmpty ? "no data" : courseList)
        - Total sessions this week: \(recent.count)

        Focus on patterns, peak times, and one actionable improvement. Return ONLY the JSON array.
        """
    }

    // MARK: - Study Coach

    static func studyCoachSystem() -> String {
        """
        You are a warm, encouraging personal study coach. \
        Help the student build and refine their daily study routine through conversation.
        When you have enough information to create or update a routine, \
        include a JSON block at the END of your response wrapped in <routine> tags:
        <routine>{"title":"string","items":[{"time":"HH:MM","activity":"string","duration":int,"course":"string"}]}</routine>
        Keep your conversational text concise (2-4 sentences max). \
        Be specific, encouraging, and reference what the student told you.
        Duration in minutes. Time in 24h format.
        """
    }

    static func studyCoachSystemCompressed() -> String {
        """
        You are a concise study coach. Reply in max 3 bullet points, under 120 tokens total. \
        Match the student's language (Turkish or English). \
        If creating a routine, append <routine>{"title":"string","items":[{"time":"HH:MM","activity":"string","duration":int,"course":"string"}]}</routine> at the very end — no extra text after it.
        """
    }

    static func studyCoachFirstMessage(
        courses: [String],
        goals: String,
        languageCode: String
    ) -> String {
        let lang = languageCode.hasPrefix("tr") ? "Please respond in Turkish." : "Please respond in English."
        let courseStr = courses.isEmpty ? "various subjects" : courses.joined(separator: ", ")
        return """
        \(lang)
        My courses: \(courseStr)
        My study goals: \(goals.isEmpty ? "study consistently and improve my grades" : goals)
        Please create a daily study routine for me.
        """
    }
}
