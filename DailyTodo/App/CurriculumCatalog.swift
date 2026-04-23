//
//  CurriculumCatalog.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 23.04.2026.
//

import Foundation

struct CurriculumCourseSeed: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let name: String
    let yearNumber: Int
    let termNumber: Int?
}

struct CurriculumProgramSeed: Hashable {
    let universityName: String
    let majorName: String
    let courses: [CurriculumCourseSeed]
}

enum CurriculumCatalog {

    static let programs: [CurriculumProgramSeed] = [
        CurriculumProgramSeed(
            universityName: "Doğu Akdeniz Üniversitesi",
            majorName: "Computer Engineering",
            courses: [
                CurriculumCourseSeed(code: "CMPE107", name: "Foundations of Computer Engineering", yearNumber: 1, termNumber: 1),
                CurriculumCourseSeed(code: "MATH151", name: "Calculus I", yearNumber: 1, termNumber: 1),
                CurriculumCourseSeed(code: "MATH163", name: "Discrete Mathematics", yearNumber: 1, termNumber: 1),
                CurriculumCourseSeed(code: "PHYS101", name: "Physics I", yearNumber: 1, termNumber: 1),

                CurriculumCourseSeed(code: "CMPE112", name: "Programming Fundamentals", yearNumber: 1, termNumber: 2),
                CurriculumCourseSeed(code: "MATH152", name: "Calculus II", yearNumber: 1, termNumber: 2),
                CurriculumCourseSeed(code: "PHYS102", name: "Physics II", yearNumber: 1, termNumber: 2),

                CurriculumCourseSeed(code: "CMPE223", name: "Digital Logic Design", yearNumber: 2, termNumber: 3),
                CurriculumCourseSeed(code: "CMPE231", name: "Data Structures", yearNumber: 2, termNumber: 3),
                CurriculumCourseSeed(code: "CMPE211", name: "Object Oriented Programming", yearNumber: 2, termNumber: 3),
                CurriculumCourseSeed(code: "MATH241", name: "Linear Algebra and Ordinary Differential Equations", yearNumber: 2, termNumber: 3),

                CurriculumCourseSeed(code: "CMPE224", name: "Digital Logic Systems", yearNumber: 2, termNumber: 4),
                CurriculumCourseSeed(code: "CMPE226", name: "Electronics for Computer Engineers", yearNumber: 2, termNumber: 4),
                CurriculumCourseSeed(code: "CMPE242", name: "Operating Systems", yearNumber: 2, termNumber: 4),
                CurriculumCourseSeed(code: "MATH373", name: "Numerical Analysis for Engineers", yearNumber: 2, termNumber: 4)
            ]
        ),

        CurriculumProgramSeed(
            universityName: "Doğu Akdeniz Üniversitesi",
            majorName: "Software Engineering",
            courses: [
                CurriculumCourseSeed(code: "CMSE107", name: "Foundations of Software Engineering", yearNumber: 1, termNumber: 1),
                CurriculumCourseSeed(code: "MATH151", name: "Calculus I", yearNumber: 1, termNumber: 1),
                CurriculumCourseSeed(code: "MATH163", name: "Discrete Mathematics", yearNumber: 1, termNumber: 1),
                CurriculumCourseSeed(code: "PHYS101", name: "Physics I", yearNumber: 1, termNumber: 1),

                CurriculumCourseSeed(code: "CMSE112", name: "Programming Fundamentals", yearNumber: 1, termNumber: 2),
                CurriculumCourseSeed(code: "MATH152", name: "Calculus II", yearNumber: 1, termNumber: 2),
                CurriculumCourseSeed(code: "PHYS102", name: "Physics II", yearNumber: 1, termNumber: 2),

                CurriculumCourseSeed(code: "CMSE201", name: "Fundamentals of Software Engineering", yearNumber: 2, termNumber: 3),
                CurriculumCourseSeed(code: "CMSE211", name: "Object Oriented Programming", yearNumber: 2, termNumber: 3),
                CurriculumCourseSeed(code: "CMSE231", name: "Data Structures", yearNumber: 2, termNumber: 3),
                CurriculumCourseSeed(code: "MATH241", name: "Linear Algebra and Ordinary Differential Equations", yearNumber: 2, termNumber: 3)
            ]
        )
    ]

    static func suggestedCourses(
        universityName: String,
        majorName: String,
        gradeLevel: String
    ) -> [OnboardingCourseDraft] {
        guard let yearNumber = normalizedYear(from: gradeLevel) else { return [] }

        guard let program = programs.first(where: {
            $0.universityName.caseInsensitiveCompare(universityName) == .orderedSame &&
            $0.majorName.caseInsensitiveCompare(majorName) == .orderedSame
        }) else {
            return []
        }

        return program.courses
            .filter { $0.yearNumber == yearNumber }
            .sorted {
                if $0.termNumber == $1.termNumber {
                    return $0.code.localizedCaseInsensitiveCompare($1.code) == .orderedAscending
                }
                return ($0.termNumber ?? 0) < ($1.termNumber ?? 0)
            }
            .map {
                OnboardingCourseDraft(code: $0.code, name: $0.name)
            }
    }

    static func hasCatalog(
        universityName: String,
        majorName: String
    ) -> Bool {
        programs.contains {
            $0.universityName.caseInsensitiveCompare(universityName) == .orderedSame &&
            $0.majorName.caseInsensitiveCompare(majorName) == .orderedSame
        }
    }

    static func normalizedYear(from gradeLevel: String) -> Int? {
        switch gradeLevel {
        case "1": return 1
        case "2": return 2
        case "3": return 3
        case "4": return 4
        case "5": return 5
        case "6": return 6
        default: return nil
        }
    }
}
