//
//  WorkoutExerciseLibrary.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 17.03.2026.
//

import Foundation

enum WorkoutExerciseLibrary {
    static func recommended(for day: String) -> [String] {
        switch day {
        case "Leg Day":
            return [
                "Squat",
                "Leg Press",
                "Romanian Deadlift",
                "Walking Lunge",
                "Calf Raise"
            ]
        case "Push Day":
            return [
                "Bench Press",
                "Incline Dumbbell Press",
                "Shoulder Press",
                "Lateral Raise",
                "Triceps Pushdown"
            ]
        case "Pull Day":
            return [
                "Deadlift",
                "Lat Pulldown",
                "Barbell Row",
                "Seated Cable Row",
                "Biceps Curl"
            ]
        case "Chest Day":
            return [
                "Bench Press",
                "Incline Dumbbell Press",
                "Chest Fly",
                "Push-Up",
                "Cable Crossover"
            ]
        case "Back Day":
            return [
                "Pull-Up",
                "Lat Pulldown",
                "Barbell Row",
                "Single Arm Row",
                "Face Pull"
            ]
        case "Shoulder Day":
            return [
                "Shoulder Press",
                "Lateral Raise",
                "Rear Delt Fly",
                "Arnold Press",
                "Front Raise"
            ]
        case "Arm Day":
            return [
                "Barbell Curl",
                "Hammer Curl",
                "Triceps Pushdown",
                "Overhead Triceps Extension",
                "Preacher Curl"
            ]
        case "Full Body":
            return [
                "Squat",
                "Bench Press",
                "Row",
                "Shoulder Press",
                "Walking Lunge"
            ]
        default:
            return []
        }
    }

    static func all(for day: String) -> [String] {
        switch day {
        case "Leg Day":
            return [
                "Hack Squat",
                "Bulgarian Split Squat",
                "Leg Extension",
                "Leg Curl",
                "Hip Thrust",
                "Wall Sit",
                "Glute Bridge",
                "Seated Calf Raise"
            ]
        case "Push Day":
            return [
                "Dumbbell Bench Press",
                "Machine Chest Press",
                "Cable Fly",
                "Dip",
                "Skull Crusher",
                "Front Raise"
            ]
        case "Pull Day":
            return [
                "T-Bar Row",
                "Machine Row",
                "Straight Arm Pulldown",
                "Face Pull",
                "EZ Bar Curl",
                "Concentration Curl"
            ]
        case "Chest Day":
            return [
                "Decline Press",
                "Machine Fly",
                "Incline Cable Fly",
                "Dumbbell Pullover"
            ]
        case "Back Day":
            return [
                "Chest Supported Row",
                "Reverse Pec Deck",
                "Cable Row",
                "Shrug",
                "Hyperextension"
            ]
        case "Shoulder Day":
            return [
                "Cable Lateral Raise",
                "Upright Row",
                "Smith Shoulder Press",
                "Reverse Fly"
            ]
        case "Arm Day":
            return [
                "Cable Curl",
                "Spider Curl",
                "Bench Dip",
                "Rope Pushdown"
            ]
        case "Full Body":
            return [
                "Deadlift",
                "Pull-Up",
                "Push-Up",
                "Plank",
                "Farmer Carry"
            ]
        default:
            return []
        }
    }
}
