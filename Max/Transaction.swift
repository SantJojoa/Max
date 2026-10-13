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
    @Attribute(.externalStorage) var receiptData: Data?

    var remoteID: UUID?
    var updatedAt: Date
    var isDeleted: Bool
    var needsSync: Bool

    init(amount: Double, type: TransactionType, category: String, date: Date = .now, note: String = "") {
        self.amount = amount
        self.type = type
        self.category = category
        self.date = date
        self.note = note
        self.receiptData = nil
        self.remoteID = nil
        self.updatedAt = .now
        self.isDeleted = false
        self.needsSync = true
    }
}
