//
//  SettingsView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//
import SwiftUI

struct SettingsView: View {

    @AppStorage("didFinishOnboarding") private var didFinishOnboarding = true
    @AppStorage("didFinishPermissionOnboarding") private var didFinishPermissionOnboarding = true
    @AppStorage("showOnlyToday") private var showOnlyToday: Bool = false
    var body: some View {
        Form {

            Section("Görünüm") {
                Toggle("Sadece bugünün görevlerini göster",
                       isOn: $showOnlyToday)
            }
            Section("App") {
                Button {
                    didFinishOnboarding = false
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.accentColor.opacity(0.14))
                                .frame(width: 34, height: 34)

                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.accentColor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Onboarding Again")
                                .foregroundStyle(.primary)

                            Text("Replay the welcome screens")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    didFinishPermissionOnboarding = false
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.orange.opacity(0.14))
                                .frame(width: 34, height: 34)

                            Image(systemName: "bell.badge")
                                .foregroundStyle(.orange)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Permission Screen")
                                .foregroundStyle(.primary)

                            Text("Replay notification permission intro")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Uygulama") {
                HStack {
                    Text("Versiyon")
                    Spacer()
                    Text("1.0")
                        .foregroundStyle(.secondary)
                }
            }

        }
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.inline)
    }
}
