import Foundation
import SwiftData

enum CategoryScope: String, Codable, CaseIterable {
    case expense = "Gasto"
    case income = "Ingreso"
    case card = "Tarjeta"
}

@Model
final class Category {
    var name: String
    var scope: CategoryScope
    var emoji: String?
    var remoteID: UUID?
    var updatedAt: Date
    @Attribute(originalName: "isDeleted") var isRemoved: Bool
    var needsSync: Bool

    init(name: String, scope: CategoryScope) {
        self.name = name
        self.scope = scope
        self.emoji = nil
        self.remoteID = nil
        self.updatedAt = .now
        self.isRemoved = false
        self.needsSync = true
    }
}
