import Foundation
import WidgetKit

enum WidgetDataStore {
    private static let suiteName = "group.com.santiago.max"

    static func update(income: Double, expense: Double, balance: Double) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(income, forKey: "widget_income")
        defaults.set(expense, forKey: "widget_expense")
        defaults.set(balance, forKey: "widget_balance")
        defaults.set(Date(), forKey: "widget_updatedAt")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
