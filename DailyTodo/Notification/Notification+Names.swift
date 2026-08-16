//
//  Notification+Names.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 17.03.2026.
//

import Foundation

extension Notification.Name {
    static let workoutCompleted = Notification.Name("workoutCompleted")
    /// Posted after the user switches the app icon, so scheduled notifications
    /// can re-render their icon attachment with the newly chosen icon.
    static let appIconDidChange = Notification.Name("appIconDidChange")
    /// Ayarlardan "Uygulama Turu"na basınca rehberli turu yeniden başlatır.
    static let startAppTour = Notification.Name("startAppTour")
    /// App tour son adımından sonra: gerçek app-icon/Live Activity/widget ekranını
    /// göstermek için Ayarlar sheet'ini aç (insights tab'ında).
    static let openSettingsHub = Notification.Name("openSettingsHub")
}
