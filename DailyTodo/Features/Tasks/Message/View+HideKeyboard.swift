//
//  View+HideKeyboard.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 15.03.2026.
//

import SwiftUI

#if canImport(UIKit)
extension View {
    func hideKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
    }
}
#endif
