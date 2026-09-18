//
//  ShareSheet.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 3.03.2026.
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - App-wide links (single source of truth)

enum AppLinks {
    /// Public App Store page for Updo. Region-agnostic `/app/id…` form so the
    /// link resolves to the visitor's own storefront. Used for friend invites
    /// (updo.me isn't built yet → share the store link directly).
    static let appStore = "https://apps.apple.com/app/id6761265170"
}
