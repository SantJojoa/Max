import Foundation
import SwiftData

/// Reparación única tras corregir el bug de `isDeleted`.
///
/// Antes, el nombre `isDeleted` chocaba con una propiedad interna de SwiftData: después de guardar, los
/// registros borrados se leían como "no borrados" y la sincronización pudo subir esa versión equivocada a la nube.
/// Ahora que la propiedad se llama `isRemoved`, volvemos a marcar como pendientes todos los registros borrados
/// para que la nube reciba el borrado correcto.
enum DeletionRepair {
    private static let key = "didRepairRemovedFlags_v1"

    @MainActor
    static func runIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        func repush<T: PersistentModel>(_ type: T.Type, removed: Predicate<T>, mark: (T) -> Void) {
            if let items = try? context.fetch(FetchDescriptor<T>(predicate: removed)) {
                items.forEach(mark)
            }
        }

        repush(Transaction.self, removed: #Predicate { $0.isRemoved }) { $0.needsSync = true }
        repush(CardTransaction.self, removed: #Predicate { $0.isRemoved }) { $0.needsSync = true }
        repush(CreditCard.self, removed: #Predicate { $0.isRemoved }) { $0.needsSync = true }
        repush(Budget.self, removed: #Predicate { $0.isRemoved }) { $0.needsSync = true }
        repush(Category.self, removed: #Predicate { $0.isRemoved }) { $0.needsSync = true }
        repush(SavingsGoal.self, removed: #Predicate { $0.isRemoved }) { $0.needsSync = true }
        repush(RecurringExpense.self, removed: #Predicate { $0.isRemoved }) { $0.needsSync = true }
        repush(Account.self, removed: #Predicate { $0.isRemoved }) { $0.needsSync = true }

        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }
}
