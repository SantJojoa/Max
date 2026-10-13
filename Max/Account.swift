import Foundation
import SwiftData

enum AccountKind: String, Codable, CaseIterable {
    case cash = "Efectivo"
    case bank = "Banco"
    case savings = "Ahorros"

    var icon: String {
        switch self {
        case .cash: return "banknote.fill"
        case .bank: return "building.columns.fill"
        case .savings: return "lock.shield.fill"
        }
    }
}

@Model
final class Account {
    var name: String
    var kind: AccountKind
    var initialBalance: Double

    @Relationship(deleteRule: .nullify, inverse: \Transaction.account)
    var transactions: [Transaction] = []

    var remoteID: UUID?
    var updatedAt: Date
    @Attribute(originalName: "isDeleted") var isRemoved: Bool
    var needsSync: Bool

    init(name: String, kind: AccountKind = .bank, initialBalance: Double = 0) {
        self.name = name
        self.kind = kind
        self.initialBalance = initialBalance
        self.remoteID = nil
        self.updatedAt = .now
        self.isRemoved = false
        self.needsSync = true
    }

    /// Saldo = saldo inicial + ingresos − gastos de los movimientos de esta cuenta.
    var balance: Double {
        let net = transactions
            .filter { !$0.isRemoved }
            .reduce(0.0) { $0 + ($1.type == .income ? $1.amount : -$1.amount) }
        return initialBalance + net
    }
}
