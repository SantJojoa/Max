import Foundation
import SwiftData

/// Mantenimiento de categorías: siembra las de ejemplo solo en cuentas realmente nuevas,
/// limpia duplicados y asigna emojis a las categorías por defecto.
enum CategoryMaintenance {
    static let defaultEmojis: [String: String] = [
        "comida": "🍔",
        "transporte": "🚗",
        "vivienda": "🏠",
        "entretenimiento": "🎮",
        "salud": "💊",
        "compras": "🛍️",
        "suscripciones": "🔁",
        "salario": "💰",
        "freelance": "💻",
        "regalo": "🎁",
        "otros": "🔖"
    ]

    private static let backfillKey = "didBackfillDefaultCategoryEmojis"

    /// Debe llamarse DESPUÉS de sincronizar con éxito. Así, si ya tienes categorías en tu cuenta
    /// (aunque sea una instalación nueva en este teléfono), nunca se crean las de ejemplo.
    @MainActor
    static func run(context: ModelContext, syncSucceeded: Bool) {
        if syncSucceeded {
            seedIfNeeded(context: context)
        }
        removeDuplicates(context: context)
        backfillEmojisIfNeeded(context: context)
        adoptLocalEmojis(context: context)
        try? context.save()
    }

    /// Cuenta "nueva" = ni una sola categoría guardada, ni siquiera borradas.
    @MainActor
    private static func seedIfNeeded(context: ModelContext) {
        let total = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard total == 0 else { return }

        let expense = ["Comida", "Transporte", "Vivienda", "Entretenimiento", "Salud", "Otros"]
        let income = ["Salario", "Freelance", "Regalo", "Otros"]
        let card = ["Comida", "Transporte", "Compras", "Entretenimiento", "Salud", "Suscripciones", "Otros"]

        for name in expense { context.insert(Category(name: name, scope: .expense)) }
        for name in income { context.insert(Category(name: name, scope: .income)) }
        for name in card { context.insert(Category(name: name, scope: .card)) }

        for name in Set(expense + income + card) {
            if let emoji = defaultEmojis[name.lowercased()] {
                CategoryStyle.setEmoji(emoji, for: name)
            }
        }
        UserDefaults.standard.set(true, forKey: backfillKey)
    }

    /// Si hay varias categorías con el mismo nombre y tipo, conserva una y marca las demás como borradas.
    /// Los movimientos guardan la categoría por nombre, así que no se pierde nada.
    @MainActor
    private static func removeDuplicates(context: ModelContext) {
        guard let all = try? context.fetch(FetchDescriptor<Category>(predicate: #Predicate { !$0.isRemoved })) else { return }

        var groups: [String: [Category]] = [:]
        for category in all {
            let key = "\(category.scope.rawValue)|\(category.name.trimmingCharacters(in: .whitespaces).lowercased())"
            groups[key, default: []].append(category)
        }

        for (_, items) in groups where items.count > 1 {
            // Prefiere la que ya está sincronizada y es más antigua.
            let sorted = items.sorted {
                let a = $0.remoteID != nil, b = $1.remoteID != nil
                if a != b { return a }
                return $0.updatedAt < $1.updatedAt
            }
            for duplicate in sorted.dropFirst() {
                duplicate.isRemoved = true
                duplicate.updatedAt = .now
                duplicate.needsSync = true
            }
        }
    }

    /// Pasa los emojis que solo estaban en este teléfono al modelo de la categoría para que se sincronicen,
    /// y al revés: copia al caché local los que vengan de la nube.
    @MainActor
    private static func adoptLocalEmojis(context: ModelContext) {
        guard let all = try? context.fetch(FetchDescriptor<Category>(predicate: #Predicate { !$0.isRemoved })) else { return }
        for category in all {
            let local = CategoryStyle.emoji(for: category.name)
            if category.emoji == nil, let local {
                category.emoji = local
                category.needsSync = true
            } else if let cloud = category.emoji, local == nil {
                CategoryStyle.setEmoji(cloud, for: category.name)
            }
        }
    }

    /// Una sola vez por instalación: pone emoji a las categorías con nombre por defecto que aún no tienen uno.
    @MainActor
    private static func backfillEmojisIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: backfillKey) else { return }
        guard let all = try? context.fetch(FetchDescriptor<Category>(predicate: #Predicate { !$0.isRemoved })) else { return }

        for category in all {
            if CategoryStyle.emoji(for: category.name) == nil,
               let emoji = defaultEmojis[category.name.lowercased()] {
                CategoryStyle.setEmoji(emoji, for: category.name)
            }
        }
        UserDefaults.standard.set(true, forKey: backfillKey)
    }
}
