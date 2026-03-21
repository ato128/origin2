//
//  PushNotificationManager.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 21.03.2026.
//

import Foundation
import UserNotifications
import UIKit

enum PushNotificationManager {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("NOTIFICATION PERMISSION ERROR:", error.localizedDescription)
                return
            }

            print("NOTIFICATION PERMISSION GRANTED:", granted)

            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}
