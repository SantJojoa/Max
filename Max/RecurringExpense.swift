import Foundation
import SwiftData

@Model
final class RecurringExpense {
    var name: String
    var amount: Double
    var type: TransactionType
    var category: String
    var dayOfMonth: Int
    var isActive: Bool
    var lastGeneratedMonth: Int?
    var lastGeneratedYear: Int?
    var remoteID: UUID?
    var updatedAt: Date
    var isDeleted: Bool
    var needsSync: Bool

    init(name: String, amount: Double, type: TransactionType, category: String, dayOfMonth: Int, isActive: Bool = true) {
        self.name = name
        self.amount = amount
        self.type = type
        self.category = category
        self.dayOfMonth = dayOfMonth
        self.isActive = isActive
        self.lastGeneratedMonth = nil
        self.lastGeneratedYear = nil
        self.remoteID = nil
        self.updatedAt = .now
        self.isDeleted = false
        self.needsSync = true
    }
}
