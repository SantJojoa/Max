//
//  SyncManager.swift
//  Max
//
//  Created by Santiago Jojoa on 29/08/26.
//

import Foundation
import SwiftData
import Supabase

@Observable
@MainActor
final class SyncManager {
    static let shared = SyncManager()
    private init() {}

    private(set) var isSyncing = false
    var lastError: String?

    func syncAll(context: ModelContext) async {
        guard !isSyncing else { return }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        print("🔄 Sync iniciado")

        do {
            try await syncCategories(context: context)
            try await syncSavingsGoals(context: context)
            try await syncRecurringExpenses(context: context)
            try await syncCreditCards(context: context)
            try await syncCardTransactions(context: context)
            try await syncTransactions(context: context)
            try await syncBudgets(context: context)
            print("✅ Sync completado sin errores")
        } catch {
            lastError = error.localizedDescription
            print("❌ Error sincronizando: \(error)")
        }
    }

    // MARK: - Tarjetas de crédito

    private struct CreditCardDTO: Codable {
        var id: UUID
        var name: String
        var creditLimit: Double
        var closingDay: Int
        var monthlyInterestRate: Double
        var managementFee: Double
        var isDeleted: Bool
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case creditLimit = "credit_limit"
            case closingDay = "closing_day"
            case monthlyInterestRate = "monthly_interest_rate"
            case managementFee = "management_fee"
            case isDeleted = "is_deleted"
            case updatedAt = "updated_at"
        }
    }

    private func syncCreditCards(context: ModelContext) async throws {
        // 1. Subir cambios locales pendientes
        let pending = try context.fetch(FetchDescriptor<CreditCard>(predicate: #Predicate { $0.needsSync }))

        for card in pending {
            let id = card.remoteID ?? UUID()
            let dto = CreditCardDTO(
                id: id,
                name: card.name,
                creditLimit: card.creditLimit,
                closingDay: card.closingDay,
                monthlyInterestRate: card.monthlyInterestRate,
                managementFee: card.managementFee,
                isDeleted: card.isDeleted,
                updatedAt: card.updatedAt
            )
            try await supabase.from("credit_cards").upsert(dto).execute()
            card.remoteID = id
            card.needsSync = false
        }

        // 2. Bajar todo lo que hay en Supabase
        let remoteItems: [CreditCardDTO] = try await supabase
            .from("credit_cards")
            .select()
            .execute()
            .value

        // 3. Fusionar con lo local
        let localItems = try context.fetch(FetchDescriptor<CreditCard>())
        var localByRemoteID: [UUID: CreditCard] = [:]
        for item in localItems {
            if let remoteID = item.remoteID {
                localByRemoteID[remoteID] = item
            }
        }

        for remote in remoteItems {
            if let local = localByRemoteID[remote.id] {
                // Ya existe localmente: el cambio más reciente gana
                if remote.updatedAt > local.updatedAt {
                    local.name = remote.name
                    local.creditLimit = remote.creditLimit
                    local.closingDay = remote.closingDay
                    local.monthlyInterestRate = remote.monthlyInterestRate
                    local.managementFee = remote.managementFee
                    local.isDeleted = remote.isDeleted
                    local.updatedAt = remote.updatedAt
                }
            } else {
                // No existe localmente: viene de otro dispositivo
                let newCard = CreditCard(
                    name: remote.name,
                    creditLimit: remote.creditLimit,
                    closingDay: remote.closingDay,
                    monthlyInterestRate: remote.monthlyInterestRate,
                    managementFee: remote.managementFee
                )
                newCard.remoteID = remote.id
                newCard.isDeleted = remote.isDeleted
                newCard.updatedAt = remote.updatedAt
                newCard.needsSync = false
                context.insert(newCard)
            }
        }

        try context.save()
    }
    
    // MARK: - Movimientos de tarjeta

    private struct CardTransactionDTO: Codable {
        var id: UUID
        var cardId: UUID
        var amount: Double
        var type: String
        var category: String
        var date: Date
        var note: String
        var isDeleted: Bool
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id, amount, type, category, date, note
            case cardId = "card_id"
            case isDeleted = "is_deleted"
            case updatedAt = "updated_at"
        }
    }

    private func syncCardTransactions(context: ModelContext) async throws {
        let pending = try context.fetch(FetchDescriptor<CardTransaction>(predicate: #Predicate { $0.needsSync }))

        for transaction in pending {
            guard let cardRemoteID = transaction.card?.remoteID else { continue }
            let id = transaction.remoteID ?? UUID()
            let dto = CardTransactionDTO(
                id: id,
                cardId: cardRemoteID,
                amount: transaction.amount,
                type: transaction.type.rawValue,
                category: transaction.category,
                date: transaction.date,
                note: transaction.note,
                isDeleted: transaction.isDeleted,
                updatedAt: transaction.updatedAt
            )
            try await supabase.from("card_transactions").upsert(dto).execute()
            transaction.remoteID = id
            transaction.needsSync = false
        }

        let remoteItems: [CardTransactionDTO] = try await supabase
            .from("card_transactions")
            .select()
            .execute()
            .value

        let localCards = try context.fetch(FetchDescriptor<CreditCard>())
        var cardsByRemoteID: [UUID: CreditCard] = [:]
        for card in localCards {
            if let remoteID = card.remoteID {
                cardsByRemoteID[remoteID] = card
            }
        }

        let localItems = try context.fetch(FetchDescriptor<CardTransaction>())
        var localByRemoteID: [UUID: CardTransaction] = [:]
        for item in localItems {
            if let remoteID = item.remoteID {
                localByRemoteID[remoteID] = item
            }
        }

        for remote in remoteItems {
            if let local = localByRemoteID[remote.id] {
                if remote.updatedAt > local.updatedAt {
                    local.amount = remote.amount
                    local.type = CardTransactionType(rawValue: remote.type) ?? .purchase
                    local.category = remote.category
                    local.date = remote.date
                    local.note = remote.note
                    local.isDeleted = remote.isDeleted
                    local.updatedAt = remote.updatedAt
                    if let card = cardsByRemoteID[remote.cardId] {
                        local.card = card
                    }
                }
            } else {
                guard let card = cardsByRemoteID[remote.cardId] else { continue }
                let newTransaction = CardTransaction(
                    amount: remote.amount,
                    type: CardTransactionType(rawValue: remote.type) ?? .purchase,
                    category: remote.category,
                    date: remote.date,
                    note: remote.note,
                    card: card
                )
                newTransaction.remoteID = remote.id
                newTransaction.isDeleted = remote.isDeleted
                newTransaction.updatedAt = remote.updatedAt
                newTransaction.needsSync = false
                context.insert(newTransaction)
            }
        }

        try context.save()
    }
    
    // MARK: - Transacciones

    private struct TransactionDTO: Codable {
        var id: UUID
        var amount: Double
        var type: String
        var category: String
        var date: Date
        var note: String
        var isDeleted: Bool
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id, amount, type, category, date, note
            case isDeleted = "is_deleted"
            case updatedAt = "updated_at"
        }
    }

    private func syncTransactions(context: ModelContext) async throws {
        let pending = try context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate { $0.needsSync }))

        for transaction in pending {
            let id = transaction.remoteID ?? UUID()
            let dto = TransactionDTO(
                id: id,
                amount: transaction.amount,
                type: transaction.type.rawValue,
                category: transaction.category,
                date: transaction.date,
                note: transaction.note,
                isDeleted: transaction.isDeleted,
                updatedAt: transaction.updatedAt
            )
            try await supabase.from("transactions").upsert(dto).execute()
            transaction.remoteID = id
            transaction.needsSync = false
        }

        let remoteItems: [TransactionDTO] = try await supabase
            .from("transactions")
            .select()
            .execute()
            .value

        let localItems = try context.fetch(FetchDescriptor<Transaction>())
        var localByRemoteID: [UUID: Transaction] = [:]
        for item in localItems {
            if let remoteID = item.remoteID {
                localByRemoteID[remoteID] = item
            }
        }

        for remote in remoteItems {
            if let local = localByRemoteID[remote.id] {
                if remote.updatedAt > local.updatedAt {
                    local.amount = remote.amount
                    local.type = TransactionType(rawValue: remote.type) ?? .expense
                    local.category = remote.category
                    local.date = remote.date
                    local.note = remote.note
                    local.isDeleted = remote.isDeleted
                    local.updatedAt = remote.updatedAt
                }
            } else {
                let newTransaction = Transaction(
                    amount: remote.amount,
                    type: TransactionType(rawValue: remote.type) ?? .expense,
                    category: remote.category,
                    date: remote.date,
                    note: remote.note
                )
                newTransaction.remoteID = remote.id
                newTransaction.isDeleted = remote.isDeleted
                newTransaction.updatedAt = remote.updatedAt
                newTransaction.needsSync = false
                context.insert(newTransaction)
            }
        }

        try context.save()
    }

    // MARK: - Presupuestos

    private struct BudgetDTO: Codable {
        var id: UUID
        var category: String
        var limitAmount: Double
        var month: Int
        var year: Int
        var isDeleted: Bool
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id, category, month, year
            case limitAmount = "limit_amount"
            case isDeleted = "is_deleted"
            case updatedAt = "updated_at"
        }
    }

    private func syncBudgets(context: ModelContext) async throws {
        let pending = try context.fetch(FetchDescriptor<Budget>(predicate: #Predicate { $0.needsSync }))

        for budget in pending {
            let id = budget.remoteID ?? UUID()
            let dto = BudgetDTO(
                id: id,
                category: budget.category,
                limitAmount: budget.limitAmount,
                month: budget.month,
                year: budget.year,
                isDeleted: budget.isDeleted,
                updatedAt: budget.updatedAt
            )
            try await supabase.from("budgets").upsert(dto).execute()
            budget.remoteID = id
            budget.needsSync = false
        }

        let remoteItems: [BudgetDTO] = try await supabase
            .from("budgets")
            .select()
            .execute()
            .value

        let localItems = try context.fetch(FetchDescriptor<Budget>())
        var localByRemoteID: [UUID: Budget] = [:]
        for item in localItems {
            if let remoteID = item.remoteID {
                localByRemoteID[remoteID] = item
            }
        }

        for remote in remoteItems {
            if let local = localByRemoteID[remote.id] {
                if remote.updatedAt > local.updatedAt {
                    local.category = remote.category
                    local.limitAmount = remote.limitAmount
                    local.month = remote.month
                    local.year = remote.year
                    local.isDeleted = remote.isDeleted
                    local.updatedAt = remote.updatedAt
                }
            } else {
                let newBudget = Budget(
                    category: remote.category,
                    limitAmount: remote.limitAmount,
                    month: remote.month,
                    year: remote.year
                )
                newBudget.remoteID = remote.id
                newBudget.isDeleted = remote.isDeleted
                newBudget.updatedAt = remote.updatedAt
                newBudget.needsSync = false
                context.insert(newBudget)
            }
        }

        try context.save()
    }
    
    


    // MARK: - Categorías

    private struct CategoryDTO: Codable {
        var id: UUID
        var name: String
        var scope: String
        var isDeleted: Bool
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id, name, scope
            case isDeleted = "is_deleted"
            case updatedAt = "updated_at"
        }
    }

    private func syncCategories(context: ModelContext) async throws {
        let pending = try context.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.needsSync }))

        for category in pending {
            let id = category.remoteID ?? UUID()
            let dto = CategoryDTO(
                id: id,
                name: category.name,
                scope: category.scope.rawValue,
                isDeleted: category.isDeleted,
                updatedAt: category.updatedAt
            )
            try await supabase.from("categories").upsert(dto).execute()
            category.remoteID = id
            category.needsSync = false
        }

        let remoteItems: [CategoryDTO] = try await supabase
            .from("categories")
            .select()
            .execute()
            .value

        let localItems = try context.fetch(FetchDescriptor<Category>())
        var localByRemoteID: [UUID: Category] = [:]
        for item in localItems {
            if let remoteID = item.remoteID {
                localByRemoteID[remoteID] = item
            }
        }

        for remote in remoteItems {
            if let local = localByRemoteID[remote.id] {
                if remote.updatedAt > local.updatedAt {
                    local.name = remote.name
                    local.scope = CategoryScope(rawValue: remote.scope) ?? .expense
                    local.isDeleted = remote.isDeleted
                    local.updatedAt = remote.updatedAt
                }
            } else {
                let newCategory = Category(name: remote.name, scope: CategoryScope(rawValue: remote.scope) ?? .expense)
                newCategory.remoteID = remote.id
                newCategory.isDeleted = remote.isDeleted
                newCategory.updatedAt = remote.updatedAt
                newCategory.needsSync = false
                context.insert(newCategory)
            }
        }

        try context.save()
    }


    // MARK: - Metas de ahorro

    private struct SavingsGoalDTO: Codable {
        var id: UUID
        var name: String
        var targetAmount: Double
        var savedAmount: Double
        var isDeleted: Bool
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id, name
            case targetAmount = "target_amount"
            case savedAmount = "saved_amount"
            case isDeleted = "is_deleted"
            case updatedAt = "updated_at"
        }
    }

    private func syncSavingsGoals(context: ModelContext) async throws {
        let pending = try context.fetch(FetchDescriptor<SavingsGoal>(predicate: #Predicate { $0.needsSync }))

        for goal in pending {
            let id = goal.remoteID ?? UUID()
            let dto = SavingsGoalDTO(
                id: id,
                name: goal.name,
                targetAmount: goal.targetAmount,
                savedAmount: goal.savedAmount,
                isDeleted: goal.isDeleted,
                updatedAt: goal.updatedAt
            )
            try await supabase.from("savings_goals").upsert(dto).execute()
            goal.remoteID = id
            goal.needsSync = false
        }

        let remoteItems: [SavingsGoalDTO] = try await supabase
            .from("savings_goals")
            .select()
            .execute()
            .value

        let localItems = try context.fetch(FetchDescriptor<SavingsGoal>())
        var localByRemoteID: [UUID: SavingsGoal] = [:]
        for item in localItems {
            if let remoteID = item.remoteID {
                localByRemoteID[remoteID] = item
            }
        }

        for remote in remoteItems {
            if let local = localByRemoteID[remote.id] {
                if remote.updatedAt > local.updatedAt {
                    local.name = remote.name
                    local.targetAmount = remote.targetAmount
                    local.savedAmount = remote.savedAmount
                    local.isDeleted = remote.isDeleted
                    local.updatedAt = remote.updatedAt
                }
            } else {
                let newGoal = SavingsGoal(name: remote.name, targetAmount: remote.targetAmount, savedAmount: remote.savedAmount)
                newGoal.remoteID = remote.id
                newGoal.isDeleted = remote.isDeleted
                newGoal.updatedAt = remote.updatedAt
                newGoal.needsSync = false
                context.insert(newGoal)
            }
        }

        try context.save()
    }

    // MARK: - Gastos fijos

    private struct RecurringExpenseDTO: Codable {
        var id: UUID
        var name: String
        var amount: Double
        var type: String
        var category: String
        var dayOfMonth: Int
        var isActive: Bool
        var lastGeneratedMonth: Int?
        var lastGeneratedYear: Int?
        var isDeleted: Bool
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id, name, amount, type, category
            case dayOfMonth = "day_of_month"
            case isActive = "is_active"
            case lastGeneratedMonth = "last_generated_month"
            case lastGeneratedYear = "last_generated_year"
            case isDeleted = "is_deleted"
            case updatedAt = "updated_at"
        }
    }

    private func syncRecurringExpenses(context: ModelContext) async throws {
        let pending = try context.fetch(FetchDescriptor<RecurringExpense>(predicate: #Predicate { $0.needsSync }))

        for item in pending {
            let id = item.remoteID ?? UUID()
            let dto = RecurringExpenseDTO(
                id: id,
                name: item.name,
                amount: item.amount,
                type: item.type.rawValue,
                category: item.category,
                dayOfMonth: item.dayOfMonth,
                isActive: item.isActive,
                lastGeneratedMonth: item.lastGeneratedMonth,
                lastGeneratedYear: item.lastGeneratedYear,
                isDeleted: item.isDeleted,
                updatedAt: item.updatedAt
            )
            try await supabase.from("recurring_expenses").upsert(dto).execute()
            item.remoteID = id
            item.needsSync = false
        }

        let remoteItems: [RecurringExpenseDTO] = try await supabase
            .from("recurring_expenses")
            .select()
            .execute()
            .value

        let localItems = try context.fetch(FetchDescriptor<RecurringExpense>())
        var localByRemoteID: [UUID: RecurringExpense] = [:]
        for item in localItems {
            if let remoteID = item.remoteID {
                localByRemoteID[remoteID] = item
            }
        }

        for remote in remoteItems {
            if let local = localByRemoteID[remote.id] {
                if remote.updatedAt > local.updatedAt {
                    local.name = remote.name
                    local.amount = remote.amount
                    local.type = TransactionType(rawValue: remote.type) ?? .expense
                    local.category = remote.category
                    local.dayOfMonth = remote.dayOfMonth
                    local.isActive = remote.isActive
                    local.lastGeneratedMonth = remote.lastGeneratedMonth
                    local.lastGeneratedYear = remote.lastGeneratedYear
                    local.isDeleted = remote.isDeleted
                    local.updatedAt = remote.updatedAt
                }
            } else {
                let newItem = RecurringExpense(
                    name: remote.name,
                    amount: remote.amount,
                    type: TransactionType(rawValue: remote.type) ?? .expense,
                    category: remote.category,
                    dayOfMonth: remote.dayOfMonth,
                    isActive: remote.isActive
                )
                newItem.remoteID = remote.id
                newItem.lastGeneratedMonth = remote.lastGeneratedMonth
                newItem.lastGeneratedYear = remote.lastGeneratedYear
                newItem.isDeleted = remote.isDeleted
                newItem.updatedAt = remote.updatedAt
                newItem.needsSync = false
                context.insert(newItem)
            }
        }

        try context.save()
    }
}
