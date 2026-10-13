import Foundation
import SwiftData

@Model
final class CreditCard {
    var name: String
    var creditLimit: Double
    var closingDay: Int
    var monthlyInterestRate: Double
    var managementFee: Double
    var paymentDay: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \CardTransaction.card)
    var transactions: [CardTransaction] = []

    var remoteID: UUID?
    var updatedAt: Date
    var isDeleted: Bool
    var needsSync: Bool

    init(name: String, creditLimit: Double, closingDay: Int, monthlyInterestRate: Double, managementFee: Double) {
        self.name = name
        self.creditLimit = creditLimit
        self.closingDay = closingDay
        self.monthlyInterestRate = monthlyInterestRate
        self.managementFee = managementFee
        self.remoteID = nil
        self.updatedAt = .now
        self.isDeleted = false
        self.needsSync = true
    }
}
