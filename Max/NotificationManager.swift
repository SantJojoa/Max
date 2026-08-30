//
//  NotificationManager.swift
//  Max
//
//  Created by Santiago Jojoa on 29/08/26.
//

import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error pidiendo permiso de notificaciones: \(error)")
            }
        }
    }

    func sendBudgetAlert(category: String, exceeded: Bool) {
        let content = UNMutableNotificationContent()
        content.title = exceeded ? "¡Presupuesto superado!" : "Cuidado con tu presupuesto"
        content.body = exceeded
            ? "Ya superaste el presupuesto de \(category) este mes."
            : "Vas en el 80% o más del presupuesto de \(category) este mes."
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // Deja que la notificación se muestre aunque la app esté abierta (si no, en el Simulador no verías nada mientras pruebas)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
