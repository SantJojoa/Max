import Foundation
import SwiftData

@Model
final class Budget {
    var category: String
    var limitAmount: Double
    var month: Int
    var year: Int

    var remoteID: UUID?
    var updatedAt: Date
    @Attribute(originalName: "isDeleted") var isRemoved: Bool
    var needsSync: Bool

    init(category: String, limitAmount: Double, month: Int, year: Int) {
        self.category = category
        self.limitAmount = limitAmount
        self.month = month
        self.year = year
        self.remoteID = nil
        self.updatedAt = .now
        self.isRemoved = false
        self.needsSync = true
    }
}
