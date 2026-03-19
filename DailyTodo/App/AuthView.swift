//
//  AuthView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 18.03.2026.
//

import SwiftUI

struct AuthView: View {
    enum Mode {
        case signIn
        case signUp
    }

    @State private var mode: Mode = .signIn

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .signIn:
                    SignInView(
                        onShowSignUp: {
                            withAnimation(.spring()) {
                                mode = .signUp
                            }
                        }
                    )

                case .signUp:
                    SignUpView(
                        onShowSignIn: {
                            withAnimation(.spring()) {
                                mode = .signIn
                            }
                        }
                    )
                }
            }
        }
    }
}
