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
    var remoteID: UUID?
    var updatedAt: Date
    var isDeleted: Bool
    var needsSync: Bool

    init(name: String, scope: CategoryScope) {
        self.name = name
        self.scope = scope
        self.remoteID = nil
        self.updatedAt = .now
        self.isDeleted = false
        self.needsSync = true
    }
}
