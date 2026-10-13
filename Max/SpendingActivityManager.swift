import ActivityKit
import Foundation

/// Mantiene una Live Activity con el gasto del día en la pantalla de bloqueo y la Dynamic Island.
@MainActor
enum SpendingActivityManager {
    static let enabledKey = "liveActivityEnabled"

    private static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    static func update(spentToday: Double, dailyAllowance: Double) {
        guard isEnabled else { end(); return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard spentToday > 0 else { end(); return }

        let hasAllowance = dailyAllowance > 0
        let state = SpendingActivityAttributes.ContentState(
            spentText: CurrencyFormat.string(for: spentToday, decimals: 0),
            allowanceText: hasAllowance ? CurrencyFormat.string(for: dailyAllowance, decimals: 0) : nil,
            ratio: hasAllowance ? min(spentToday / dailyAllowance, 1) : 0,
            overLimit: hasAllowance && spentToday > dailyAllowance
        )
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: .now) ?? .now.addingTimeInterval(3600)
        let content = ActivityContent(state: state, staleDate: endOfDay)

        if let current = Activity<SpendingActivityAttributes>.activities.first {
            Task { await current.update(content) }
        } else {
            _ = try? Activity.request(attributes: SpendingActivityAttributes(title: "Gasto de hoy"), content: content, pushType: nil)
        }
    }

    static func end() {
        for activity in Activity<SpendingActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
