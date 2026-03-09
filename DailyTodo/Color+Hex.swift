//
//  Color+Hex.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 10.03.2026.
//

import SwiftUI

func hexColor(_ hex: String) -> Color {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)

    let a, r, g, b: UInt64
    switch hex.count {
    case 8:
        (a, r, g, b) = (
            (int >> 24) & 0xff,
            (int >> 16) & 0xff,
            (int >> 8) & 0xff,
            int & 0xff
        )
    case 6:
        (a, r, g, b) = (
            255,
            (int >> 16) & 0xff,
            (int >> 8) & 0xff,
            int & 0xff
        )
    default:
        (a, r, g, b) = (255, 59, 130, 246)
    }

    return Color(
        .sRGB,
        red: Double(r) / 255,
        green: Double(g) / 255,
        blue: Double(b) / 255,
        opacity: Double(a) / 255
    )
}
