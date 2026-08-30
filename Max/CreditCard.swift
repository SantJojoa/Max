//
//  CreditCard.swift
//  Max
//
//  Created by Santiago Jojoa on 29/08/26.
//

import Foundation
import SwiftData

@Model
final class CreditCard {
    var name: String
    var creditLimit: Double
    var closingDay: Int              // día de corte, 1 a 31
    var monthlyInterestRate: Double  // tasa de interés mensual, en % (ej: 2.5)
    var managementFee: Double        // cuota de manejo

    @Relationship(deleteRule: .cascade, inverse: \CardTransaction.card)
    var transactions: [CardTransaction] = []

    init(name: String, creditLimit: Double, closingDay: Int, monthlyInterestRate: Double, managementFee: Double) {
        self.name = name
        self.creditLimit = creditLimit
        self.closingDay = closingDay
        self.monthlyInterestRate = monthlyInterestRate
        self.managementFee = managementFee
    }
}
