//
//  Buget.swift
//  Max
//
//  Created by Santiago Jojoa on 29/08/26.
//

import Foundation
import SwiftData

@Model
final class Budget {
    
    var category: String
    var limitAmount: Double
    var month: Int   // 1 a 12
    var year: Int
    
    
    init(category: String, limitAmount: Double, month: Int, year: Int) {
            self.category = category
            self.limitAmount = limitAmount
            self.month = month
            self.year = year
        }
}
