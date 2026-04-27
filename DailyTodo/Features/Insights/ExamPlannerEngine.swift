//
//  ExamPlannerEngine.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 27.04.2026.
//

import Foundation

enum ExamPlannerEngine {

    static func generate(
        course: Course,
        examType: ExamPlannerType,
        examDate: Date,
        ownerUserID: String?
    ) -> [ExamStudyPlanItem] {

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let target = calendar.startOfDay(for: examDate)

        let daysUntilExam = max(
            calendar.dateComponents([.day], from: today, to: target).day ?? 1,
            1
        )

        let studyDays = max(daysUntilExam - 1, 1)
        let intensity = intensityProfile(examType: examType, days: daysUntilExam)

        return (0..<studyDays).compactMap { index -> ExamStudyPlanItem? in
            guard let date = calendar.date(byAdding: .day, value: index, to: today) else {
                return nil
            }

            let dayPosition = Double(index + 1) / Double(studyDays)
            let weekday = calendar.component(.weekday, from: date)
            let isWeekend = weekday == 1 || weekday == 7

            let phase = phaseFor(
                dayPosition: dayPosition,
                index: index,
                total: studyDays
            )

            let minutes = plannedMinutes(
                base: intensity.baseMinutes,
                phase: phase,
                isWeekend: isWeekend,
                daysUntilExam: daysUntilExam
            )

            return ExamStudyPlanItem(
                ownerUserID: ownerUserID,
                courseID: course.id,
                courseName: course.name,
                courseCode: course.code,
                examType: examType,
                examDate: target,
                studyDate: date,
                minutes: minutes,
                topic: phase.title,
                isRevisionDay: phase.isRevision,
                isWeakTopicBoost: phase == .weakTopics
            )
        }
    }
}

// MARK: - Smart Planning Logic

private extension ExamPlannerEngine {

    enum StudyPhase: Equatable {
        case syllabusScan
        case lectureReview
        case noteRewrite
        case examples
        case problemSet
        case pastQuestions
        case weakTopics
        case mockExam
        case finalReview

        var title: String {
            switch self {
            case .syllabusScan:
                return "Konu listesi çıkar"
            case .lectureReview:
                return "Ders notlarını oku"
            case .noteRewrite:
                return "Özet not hazırla"
            case .examples:
                return "Örnek soruları incele"
            case .problemSet:
                return "Soru çözümü"
            case .pastQuestions:
                return "Çıkmış soru çöz"
            case .weakTopics:
                return "Zayıf konuları kapat"
            case .mockExam:
                return "Deneme sınavı"
            case .finalReview:
                return "Son tekrar"
            }
        }

        var multiplier: Double {
            switch self {
            case .syllabusScan:
                return 0.65
            case .lectureReview:
                return 0.90
            case .noteRewrite:
                return 1.00
            case .examples:
                return 1.05
            case .problemSet:
                return 1.15
            case .pastQuestions:
                return 1.25
            case .weakTopics:
                return 1.25
            case .mockExam:
                return 1.45
            case .finalReview:
                return 0.90
            }
        }

        var isRevision: Bool {
            switch self {
            case .weakTopics, .mockExam, .finalReview:
                return true
            default:
                return false
            }
        }
    }

    struct IntensityProfile {
        let baseMinutes: Int
    }

    static func intensityProfile(
        examType: ExamPlannerType,
        days: Int
    ) -> IntensityProfile {
        let base: Int

        switch days {
        case 0...2:
            base = 95
        case 3...5:
            base = 75
        case 6...9:
            base = 60
        case 10...16:
            base = 45
        default:
            base = 35
        }

        let multiplier: Double

        switch examType {
        case .quiz:
            multiplier = 0.75
        case .midterm:
            multiplier = 1.00
        case .final:
            multiplier = 1.28
        }

        return IntensityProfile(
            baseMinutes: roundToFive(Int(Double(base) * multiplier))
        )
    }

    static func phaseFor(
        dayPosition: Double,
        index: Int,
        total: Int
    ) -> StudyPhase {

        if total <= 1 {
            return .finalReview
        }

        if total <= 2 {
            return index == total - 1 ? .finalReview : .weakTopics
        }

        if total <= 5 {
            if index == 0 { return .lectureReview }
            if index == total - 1 { return .finalReview }
            if index == total - 2 { return .mockExam }
            return .problemSet
        }

        if index == 0 {
            return .syllabusScan
        }

        if index == total - 1 {
            return .finalReview
        }

        if index == total - 2 {
            return .mockExam
        }

        if index == total - 3 {
            return .weakTopics
        }

        if dayPosition < 0.25 {
            return .lectureReview
        }

        if dayPosition < 0.42 {
            return .noteRewrite
        }

        if dayPosition < 0.58 {
            return .examples
        }

        if dayPosition < 0.76 {
            return .problemSet
        }

        return .pastQuestions
    }

    static func plannedMinutes(
        base: Int,
        phase: StudyPhase,
        isWeekend: Bool,
        daysUntilExam: Int
    ) -> Int {
        var value = Double(base) * phase.multiplier

        if isWeekend {
            value *= 1.45
        }

        if daysUntilExam <= 5 {
            value *= 1.12
        }

        return roundToFive(max(20, Int(value)))
    }

    static func roundToFive(_ value: Int) -> Int {
        ((value + 4) / 5) * 5
    }
}
