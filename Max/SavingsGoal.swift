import Foundation
import SwiftData

@Model
final class SavingsGoal {
    var name: String
    var targetAmount: Double
    var savedAmount: Double
    var targetDate: Date?
    var remoteID: UUID?
    var updatedAt: Date
    var isDeleted: Bool
    var needsSync: Bool

    init(name: String, targetAmount: Double, savedAmount: Double = 0) {
        self.name = name
        self.targetAmount = targetAmount
        self.savedAmount = savedAmount
        self.targetDate = nil
        self.remoteID = nil
        self.updatedAt = .now
        self.isDeleted = false
        self.needsSync = true
    }
}
