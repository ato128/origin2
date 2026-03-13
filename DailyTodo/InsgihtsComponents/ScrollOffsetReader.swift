//
//  ScrollOffsetReader.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 13.03.2026.
//

import SwiftUI

struct ScrollOffsetReader: View {
    var coordinateSpaceName: String = "scroll"

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .preference(
                    key: ScrollOffsetPreference.self,
                    value: geo.frame(in: .named(coordinateSpaceName)).minY
                )
        }
        .frame(height: 0)
    }
}
