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
    var installments: Int = 1
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
        self.installments = 1
        self.card = card
        self.remoteID = nil
        self.updatedAt = .now
        self.isRemoved = false
        self.needsSync = true
    }
}

extension CardTransaction {
    /// Valor de cada cuota (sin intereses).
    var installmentValue: Double {
        amount / Double(max(installments, 1))
    }

    /// Cuotas ya transcurridas (estimado por meses calendario desde la compra).
    var installmentsElapsed: Int {
        guard installments > 1 else { return installments }
        let months = Calendar.current.dateComponents([.month], from: date, to: .now).month ?? 0
        return min(max(months, 0), installments)
    }

    var installmentsRemaining: Int {
        max(installments - installmentsElapsed, 0)
    }

    /// Una compra en cuotas que todavía tiene cuotas por pagar.
    var isActiveInstallmentPlan: Bool {
        type == .purchase && installments > 1 && installmentsRemaining > 0
    }
}
