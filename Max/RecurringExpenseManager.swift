import Foundation
import SwiftData

enum RecurringExpenseManager {
    static func generateIfNeeded(context: ModelContext) {
        let calendar = Calendar.current
        let today = Date()
        let currentDay = calendar.component(.day, from: today)
        let currentMonth = calendar.component(.month, from: today)
        let currentYear = calendar.component(.year, from: today)
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 31

        guard let items = try? context.fetch(
            FetchDescriptor<RecurringExpense>(predicate: #Predicate { !$0.isDeleted && $0.isActive })
        ) else { return }

        var didGenerate = false

        for item in items {
            let alreadyGenerated = item.lastGeneratedMonth == currentMonth && item.lastGeneratedYear == currentYear
            let effectiveDay = min(item.dayOfMonth, daysInMonth)
            guard !alreadyGenerated, currentDay >= effectiveDay else { continue }

            let transaction = Transaction(
                amount: item.amount,
                type: item.type,
                category: item.category,
                date: today,
                note: "\(item.name) (fijo)"
            )
            context.insert(transaction)

            item.lastGeneratedMonth = currentMonth
            item.lastGeneratedYear = currentYear
            item.updatedAt = .now
            item.needsSync = true
            didGenerate = true
        }

        if didGenerate {
            try? context.save()
        }
    }
}
