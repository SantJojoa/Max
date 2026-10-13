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

    /// Programa un recordatorio mensual el día antes (a las 9:00) de cada gasto fijo activo.
    /// Si el gasto vence el día 1, avisa ese mismo día.
    func scheduleRecurringReminders(_ items: [RecurringExpense]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix("recurring-") }
            center.removePendingNotificationRequests(withIdentifiers: old)

            for (index, item) in items.enumerated() where item.isActive && !item.isDeleted && item.type == .expense {
                let day = min(max(item.dayOfMonth, 1), 31)
                let reminderDay = day == 1 ? 1 : day - 1

                let content = UNMutableNotificationContent()
                content.title = day == 1 ? "Hoy vence \(item.name)" : "Mañana vence \(item.name)"
                content.body = "Gasto fijo de \(CurrencyFormat.string(for: item.amount))."
                content.sound = .default

                var components = DateComponents()
                components.day = reminderDay
                components.hour = 9
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                center.add(UNNotificationRequest(identifier: "recurring-\(index)-\(item.name)", content: content, trigger: trigger))
            }
        }
    }

    /// Recordatorios mensuales (9:00) el día antes del corte y del pago de cada tarjeta.
    func scheduleCardReminders(_ cards: [CreditCard]) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let old = pending.map(\.identifier).filter { $0.hasPrefix("card-") }
            center.removePendingNotificationRequests(withIdentifiers: old)

            func add(id: String, title: String, body: String, day: Int) {
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                var components = DateComponents()
                components.day = day == 1 ? 1 : day - 1
                components.hour = 9
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }

            for (index, card) in cards.enumerated() where !card.isDeleted {
                add(id: "card-cut-\(index)-\(card.name)",
                    title: "Corte de \(card.name)",
                    body: card.closingDay == 1 ? "Hoy es el corte de tu tarjeta." : "Mañana es el corte de tu tarjeta.",
                    day: min(max(card.closingDay, 1), 31))
                if card.paymentDay > 0 {
                    add(id: "card-pay-\(index)-\(card.name)",
                        title: "Pago de \(card.name)",
                        body: card.paymentDay == 1 ? "Hoy vence el pago de tu tarjeta." : "Mañana vence el pago de tu tarjeta.",
                        day: min(max(card.paymentDay, 1), 31))
                }
            }
        }
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
