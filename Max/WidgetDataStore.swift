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

    static func updateBudget(total: Double, spent: Double, spentToday: Double, dailyAllowance: Double) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defaults.set(total, forKey: "widget_budget_total")
        defaults.set(spent, forKey: "widget_budget_spent")
        defaults.set(spentToday, forKey: "widget_spent_today")
        defaults.set(dailyAllowance, forKey: "widget_daily_allowance")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
