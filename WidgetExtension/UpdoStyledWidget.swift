//
//  UpdoStyledWidget.swift
//  WidgetExtensionExtension
//
//  The "Focus Card" — one widget, nine skins. The user picks a style in
//  Settings (same identities as the Live Activity styles) and this widget
//  renders today's focus / streak / level in that design. Classic is free;
//  Pro styles fall back to classic when the subscription lapses.
//

import WidgetKit
import SwiftUI

struct UpdoStyledWidgetView: View {
    let state: WidgetUserState
    @Environment(\.widgetFamily) private var family

    private var isSmall: Bool { family == .systemSmall }

    private var style: FocusLiveStyle {
        let chosen = FocusLiveStyle(rawValue: WidgetShared.readWidgetStyle())
        guard state.isPro else { return .classic }
        return chosen ?? .classic
    }

    var body: some View {
        UpdoWidgetStyleContent(style: style, state: state, isSmall: isSmall)
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .adaptiveContainerBackground {
                WidgetStyleBackground(style: style)
            }
    }
}

private extension View {
    @ViewBuilder
    func adaptiveContainerBackground<BG: View>(@ViewBuilder _ bg: @escaping () -> BG) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) { bg() }
        } else {
            self.background(bg())
        }
    }
}

struct UpdoStyledWidget: Widget {
    let kind: String = "UpdoStyledWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProStateProvider()) { entry in
            UpdoStyledWidgetView(state: entry.state)
                .widgetURL(URL(string: "dailytodo://focus"))
        }
        .configurationDisplayName(widgetLocalized("Focus Kartı", "Focus Card"))
        .description(widgetLocalized(
            "Bugünkü odağın — ayarlardan seçtiğin stilde.",
            "Today's focus — in the style you pick in Settings."
        ))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
