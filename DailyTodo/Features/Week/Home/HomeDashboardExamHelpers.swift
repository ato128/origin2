//
//  HomeDashboardExamHelpers.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 3.04.2026.
//

import SwiftUI
import SwiftData

extension HomeDashboardView {

    var userScopedExams: [ExamItem] {
        let currentUserID = session.currentUser?.id.uuidString
        return allExams.filter { $0.ownerUserID == currentUserID }
    }

    var upcomingExams: [ExamItem] {
        userScopedExams
            .filter { !$0.isCompleted && $0.examDate >= Date() }
            .sorted { $0.examDate < $1.examDate }
    }

    var nextUpcomingExam: ExamItem? {
        upcomingExams.first
    }
    
    var heroUpcomingExam: ExamItem? {
        guard let exam = nextUpcomingExam else { return nil }
        let days = daysUntilExam(exam)
        guard days >= 0 && days <= 7 else { return nil }
        return exam
    }

    var hasUpcomingExamSoon: Bool {
        guard let exam = nextUpcomingExam else { return false }
        let days = daysUntilExam(exam)
        return days >= 0 && days <= 10
    }

    func daysUntilExam(_ exam: ExamItem) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: exam.examDate)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    func examCountdownText(_ exam: ExamItem) -> String {
        let days = daysUntilExam(exam)

        if days <= 0 {
            return "Bugün"
        } else if days == 1 {
            return "Yarın"
        } else {
            return "\(days) gün kaldı"
        }
    }

    func examDateText(_ exam: ExamItem) -> String {
        exam.examDate.formatted(date: .abbreviated, time: .shortened)
    }

    func examAccentColor(_ exam: ExamItem) -> Color {
        switch exam.examType.lowercased() {
        case "final":
            return .red
        case "quiz":
            return .orange
        case "vize":
            return .blue
        default:
            return .purple
        }
    }

    func suggestedStudyMinutes(for exam: ExamItem) -> Int {
        let days = daysUntilExam(exam)

        switch days {
        case 0...1:
            return 90
        case 2...3:
            return 75
        case 4...6:
            return 60
        case 7...14:
            return 45
        default:
            return max(45, exam.preferredStudyMinutes)
        }
    }

    func suggestedStudyLabel(for exam: ExamItem) -> String {
        let minutes = suggestedStudyMinutes(for: exam)

        switch minutes {
        case 0..<50:
            return "Hafif tekrar"
        case 50..<70:
            return "Standart çalışma"
        case 70..<90:
            return "Derin odak"
        default:
            return "Son tekrar"
        }
    }

    var shouldSuggestExamPrep: Bool {
        guard let exam = nextUpcomingExam else { return false }
        let days = daysUntilExam(exam)

        if isFocusActive || hasAnyActiveFocusSession {
            return false
        }

        return days >= 0 && days <= 7
    }
}
