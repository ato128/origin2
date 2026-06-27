//
//  UpdoWidgetIconTheme.swift
//  WidgetExtensionExtension
//
//  Maps the user's selected app icon (mirrored into the App Group) to a matching
//  logo gradient + accent color, so widgets and Live Activities reflect the same
//  identity as the chosen icon — exactly like the app's launch animation.
//

import SwiftUI

enum UpdoWidgetIconTheme {

    struct Theme {
        let mark: AnyShapeStyle   // logo gradient
        let accent: Color         // primary brand accent for the surface
        let glow: Color           // halo / shadow
    }

    /// Reads the mirrored icon name from the App Group and returns its theme.
    static func current() -> Theme {
        theme(for: WidgetShared.readUserState().iconName)
    }

    static func theme(for iconName: String?) -> Theme {
        func grad(_ hexes: [String]) -> AnyShapeStyle {
            AnyShapeStyle(
                LinearGradient(
                    colors: hexes.map { hexColor($0) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }

        switch iconName {
        case "AppIcon-Gold":
            return Theme(mark: grad(["#FCD34D", "#FBBF24", "#D97706"]), accent: hexColor("#FBBF24"), glow: hexColor("#F59E0B"))
        case "AppIcon-Chrome":
            return Theme(mark: grad(["#EEF3F7", "#9AA7B0", "#5B6770"]), accent: hexColor("#C7D0D8"), glow: hexColor("#AEB9C2"))
        case "AppIcon-Aurora":
            return Theme(mark: grad(["#22D3EE", "#7C3AED", "#EC4899"]), accent: hexColor("#A855F7"), glow: hexColor("#7C3AED"))
        case "AppIcon-Sunset":
            return Theme(mark: grad(["#FBBF24", "#FB7185", "#F472B6"]), accent: hexColor("#FB7185"), glow: hexColor("#FB7185"))
        case "AppIcon-Emerald":
            return Theme(mark: grad(["#6EE7B7", "#10B981", "#047857"]), accent: hexColor("#34D399"), glow: hexColor("#10B981"))
        case "AppIcon-Noir":
            return Theme(mark: AnyShapeStyle(hexColor("#F2F4F7")), accent: hexColor("#F2F4F7"), glow: hexColor("#FFFFFF"))
        case "AppIcon-Carbon":
            return Theme(mark: grad(["#A8B0BA", "#4B5563", "#1F2937"]), accent: hexColor("#9CA3AF"), glow: hexColor("#6B7280"))
        case "AppIcon-Ice":
            return Theme(mark: grad(["#EAF7FF", "#7DD3FC", "#38BDF8"]), accent: hexColor("#7DD3FC"), glow: hexColor("#7DD3FC"))
        default: // Steel
            return Theme(mark: grad(["#7FCBDD", "#5AB6CC", "#2E7C92"]), accent: hexColor("#5AB6CC"), glow: hexColor("#3C8FA6"))
        }
    }
}
