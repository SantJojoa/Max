import Foundation
import SwiftData

enum TransactionType: String, Codable, CaseIterable {
    case income = "Ingreso"
    case expense = "Gasto"
}

@Model
final class Transaction {
    var amount: Double
    var type: TransactionType
    var category: String
    var date: Date
    var note: String

    init(amount: Double, type: TransactionType, category: String, date: Date = .now, note: String = "") {
        self.amount = amount
        self.type = type
        self.category = category
        self.date = date
        self.note = note
    }
}
