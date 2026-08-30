//
//  CardTransaction.swift
//  Max
//
//  Created by Santiago Jojoa on 29/08/26.
//

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

    init(amount: Double, type: CardTransactionType, category: String = "", date: Date = .now, note: String = "", card: CreditCard? = nil) {
        self.amount = amount
        self.type = type
        self.category = category
        self.date = date
        self.note = note
        self.card = card
    }
}
