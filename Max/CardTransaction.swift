import Foundation
import SwiftData

enum CardTransactionType: String, Codable, CaseIterable {
    case purchase = "Compra"
    case payment = "Pago"
}

@Model
final class CardTransaction {
    var amount: Double
    var type: CardTransactionType
    var category: String
    var date: Date
    var note: String
    var card: CreditCard?

    var remoteID: UUID?
    var updatedAt: Date
    @Attribute(originalName: "isDeleted") var isRemoved: Bool
    var needsSync: Bool

    init(amount: Double, type: CardTransactionType, category: String = "", date: Date = .now, note: String = "", card: CreditCard? = nil) {
        self.amount = amount
        self.type = type
        self.category = category
        self.date = date
        self.note = note
        self.card = card
        self.remoteID = nil
        self.updatedAt = .now
        self.isRemoved = false
        self.needsSync = true
    }
}
