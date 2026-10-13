//
//  QuickAddIntent.swift
//  MaxWidgets
//

import AppIntents

struct QuickAddIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Expense"
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: "group.com.santiago.max")?.set(true, forKey: "widget_quick_add_requested")
        return .result()
    }
}
