//
//  SettingsView.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 5.03.2026.
//
import SwiftUI

struct SettingsView: View {

    @AppStorage("showOnlyToday")
    private var showOnlyToday: Bool = false

    var body: some View {
        Form {

            Section("Görünüm") {
                Toggle("Sadece bugünün görevlerini göster",
                       isOn: $showOnlyToday)
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
