import Foundation
import SwiftData

enum SharedModelContainer {
    static let container: ModelContainer = {
        let schema = Schema([Transaction.self, Budget.self, CreditCard.self, CardTransaction.self, Category.self, SavingsGoal.self, RecurringExpense.self])
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("No se pudo crear el ModelContainer: \(error)")
        }
    }()
}
