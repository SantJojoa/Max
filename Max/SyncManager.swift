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

        // Cada paso va aislado: si uno falla (por ejemplo, una columna nueva que aún no existe en Supabase),
        // los demás se sincronizan igual.
        var firstError: String?

        func run(_ name: String, _ work: () async throws -> Void) async {
            do {
                try await work()
            } catch {
                print("❌ Error sincronizando \(name): \(error)")
                if firstError == nil { firstError = "\(name): \(error.localizedDescription)" }
            }
        }

        await run("categorías") { try await syncCategories(context: context) }
        await run("cuentas") { try await syncAccounts(context: context) }
        await run("metas") { try await syncSavingsGoals(context: context) }
        await run("gastos fijos") { try await syncRecurringExpenses(context: context) }
        await run("tarjetas") { try await syncCreditCards(context: context) }
        await run("movimientos de tarjeta") { try await syncCardTransactions(context: context) }
        await run("movimientos") { try await syncTransactions(context: context) }
        await run("presupuestos") { try await syncBudgets(context: context) }

        if let firstError {
            lastError = firstError
        } else {
            print("✅ Sync completado sin errores")
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
        var isRemoved: Bool
        var updatedAt: Date
        var paymentDay: Int?

        enum CodingKeys: String, CodingKey {
            case paymentDay = "payment_day"
            case id
            case name
            case creditLimit = "credit_limit"
            case closingDay = "closing_day"
            case monthlyInterestRate = "monthly_interest_rate"
            case managementFee = "management_fee"
            case isRemoved = "is_deleted"
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
                isRemoved: card.isRemoved,
                updatedAt: card.updatedAt,
                paymentDay: card.paymentDay
            )
            try await supabase.from("credit_cards").upsert(dto).execute()
            card.remoteID = id
            card.needsSync = false
            try context.save() // guarda ya el remoteID: si no, un reintento duplicaría la fila en la nube
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
                if remote.updatedAt > local.updatedAt && !local.needsSync {
                    local.name = remote.name
                    local.creditLimit = remote.creditLimit
                    local.closingDay = remote.closingDay
                    local.monthlyInterestRate = remote.monthlyInterestRate
                    local.managementFee = remote.managementFee
                    local.paymentDay = remote.paymentDay ?? local.paymentDay
                    local.isRemoved = remote.isRemoved
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
                newCard.paymentDay = remote.paymentDay ?? 0
                newCard.remoteID = remote.id
                newCard.isRemoved = remote.isRemoved
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
        var isRemoved: Bool
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id, amount, type, category, date, note
            case cardId = "card_id"
            case isRemoved = "is_deleted"
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
                isRemoved: transaction.isRemoved,
                updatedAt: transaction.updatedAt
            )
            try await supabase.from("card_transactions").upsert(dto).execute()
            transaction.remoteID = id
            transaction.needsSync = false
            try context.save() // guarda ya el remoteID: si no, un reintento duplicaría la fila en la nube
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
                if remote.updatedAt > local.updatedAt && !local.needsSync {
                    local.amount = remote.amount
                    local.type = CardTransactionType(rawValue: remote.type) ?? .purchase
                    local.category = remote.category
                    local.date = remote.date
                    local.note = remote.note
                    local.isRemoved = remote.isRemoved
                    local.updatedAt = remote.updatedAt
                    if let card = cardsByRemoteID[remote.cardId] {
                        local.card = card
                    }
                }
            } else {
                guard let card = cardsByRemoteID[remote.cardId] else { continue }
                print("⬇️ Movimiento de tarjeta bajado de la nube: \(remote.amount) · \(remote.type) · borrado=\(remote.isRemoved) · id=\(remote.id)")
                let newTransaction = CardTransaction(
                    amount: remote.amount,
                    type: CardTransactionType(rawValue: remote.type) ?? .purchase,
                    category: remote.category,
                    date: remote.date,
                    note: remote.note,
                    card: card
                )
                newTransaction.remoteID = remote.id
                newTransaction.isRemoved = remote.isRemoved
                newTransaction.updatedAt = remote.updatedAt
                newTransaction.needsSync = false
                context.insert(newTransaction)
            }
        }

        try context.save()
    }
    
    // MARK: - Cuentas

    private struct AccountDTO: Codable {
        var id: UUID
        var name: String
        var kind: String
        var initialBalance: Double
        var isRemoved: Bool
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id, name, kind
            case initialBalance = "initial_balance"
            case isRemoved = "is_deleted"
            case updatedAt = "updated_at"
        }
    }

    private func syncAccounts(context: ModelContext) async throws {
        let pending = try context.fetch(FetchDescriptor<Account>(predicate: #Predicate { $0.needsSync }))

        for account in pending {
            let id = account.remoteID ?? UUID()
            let dto = AccountDTO(
                id: id,
                name: account.name,
                kind: account.kind.rawValue,
                initialBalance: account.initialBalance,
                isRemoved: account.isRemoved,
                updatedAt: account.updatedAt
            )
            try await supabase.from("accounts").upsert(dto).execute()
            account.remoteID = id
            account.needsSync = false
            try context.save() // guarda ya el remoteID: si no, un reintento duplicaría la fila en la nube
        }

        let remoteItems: [AccountDTO] = try await supabase
            .from("accounts")
            .select()
            .execute()
            .value

        let localItems = try context.fetch(FetchDescriptor<Account>())
        var localByRemoteID: [UUID: Account] = [:]
        for item in localItems {
            if let remoteID = item.remoteID {
                localByRemoteID[remoteID] = item
            }
        }

        for remote in remoteItems {
            if let local = localByRemoteID[remote.id] {
                if remote.updatedAt > local.updatedAt && !local.needsSync {
                    local.name = remote.name
                    local.kind = AccountKind(rawValue: remote.kind) ?? .bank
                    local.initialBalance = remote.initialBalance
                    local.isRemoved = remote.isRemoved
                    local.updatedAt = remote.updatedAt
                }
            } else {
                let newAccount = Account(name: remote.name, kind: AccountKind(rawValue: remote.kind) ?? .bank, initialBalance: remote.initialBalance)
                newAccount.remoteID = remote.id
                newAccount.isRemoved = remote.isRemoved
                newAccount.updatedAt = remote.updatedAt
                newAccount.needsSync = false
                context.insert(newAccount)
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
        var isRemoved: Bool
        var updatedAt: Date
        var accountId: UUID?
        var receiptPath: String?

        enum CodingKeys: String, CodingKey {
            case id, amount, type, category, date, note
            case isRemoved = "is_deleted"
            case updatedAt = "updated_at"
            case accountId = "account_id"
            case receiptPath = "receipt_path"
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id)
            try c.encode(amount, forKey: .amount)
            try c.encode(type, forKey: .type)
            try c.encode(category, forKey: .category)
            try c.encode(date, forKey: .date)
            try c.encode(note, forKey: .note)
            try c.encode(isRemoved, forKey: .isRemoved)
            try c.encode(updatedAt, forKey: .updatedAt)
            try c.encode(accountId, forKey: .accountId)     // null quita la cuenta
            try c.encode(receiptPath, forKey: .receiptPath) // null quita el recibo
        }
    }

    private static let receiptsBucket = "receipts"

    private func syncTransactions(context: ModelContext) async throws {
        let pending = try context.fetch(FetchDescriptor<Transaction>(predicate: #Predicate { $0.needsSync }))
        let userId = try? await supabase.auth.session.user.id

        for transaction in pending {
            let id = transaction.remoteID ?? UUID()

            // Recibo: se sube primero para guardar su ruta junto con el movimiento.
            if transaction.receiptNeedsUpload, let userId {
                if let data = transaction.receiptData {
                    let path = "\(userId.uuidString.lowercased())/\(id.uuidString.lowercased()).jpg"
                    do {
                        try await supabase.storage
                            .from(Self.receiptsBucket)
                            .upload(path, data: data, options: FileOptions(contentType: "image/jpeg", upsert: true))
                        transaction.receiptPath = path
                        transaction.receiptNeedsUpload = false
                    } catch {
                        print("⚠️ No se pudo subir el recibo: \(error)")
                    }
                } else {
                    transaction.receiptPath = nil
                    transaction.receiptNeedsUpload = false
                }
            }

            let dto = TransactionDTO(
                id: id,
                amount: transaction.amount,
                type: transaction.type.rawValue,
                category: transaction.category,
                date: transaction.date,
                note: transaction.note,
                isRemoved: transaction.isRemoved,
                updatedAt: transaction.updatedAt,
                accountId: transaction.account?.remoteID,
                receiptPath: transaction.receiptPath
            )
            try await supabase.from("transactions").upsert(dto).execute()
            transaction.remoteID = id
            transaction.needsSync = false
            try context.save() // guarda ya el remoteID: si no, un reintento duplicaría la fila en la nube
        }

        let remoteItems: [TransactionDTO] = try await supabase
            .from("transactions")
            .select()
            .execute()
            .value

        let localAccounts = try context.fetch(FetchDescriptor<Account>())
        var accountsByRemoteID: [UUID: Account] = [:]
        for account in localAccounts {
            if let remoteID = account.remoteID {
                accountsByRemoteID[remoteID] = account
            }
        }

        let localItems = try context.fetch(FetchDescriptor<Transaction>())
        var localByRemoteID: [UUID: Transaction] = [:]
        for item in localItems {
            if let remoteID = item.remoteID {
                localByRemoteID[remoteID] = item
            }
        }

        var needingReceipt: [Transaction] = []

        for remote in remoteItems {
            if let local = localByRemoteID[remote.id] {
                if remote.updatedAt > local.updatedAt && !local.needsSync {
                    local.amount = remote.amount
                    local.type = TransactionType(rawValue: remote.type) ?? .expense
                    local.category = remote.category
                    local.date = remote.date
                    local.note = remote.note
                    local.isRemoved = remote.isRemoved
                    local.updatedAt = remote.updatedAt
                    local.account = remote.accountId.flatMap { accountsByRemoteID[$0] }
                    if local.receiptPath != remote.receiptPath {
                        local.receiptPath = remote.receiptPath
                        local.receiptData = nil
                    }
                }
                if local.receiptData == nil, local.receiptPath != nil, !local.receiptNeedsUpload {
                    needingReceipt.append(local)
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
                newTransaction.isRemoved = remote.isRemoved
                newTransaction.updatedAt = remote.updatedAt
                newTransaction.needsSync = false
                newTransaction.account = remote.accountId.flatMap { accountsByRemoteID[$0] }
                newTransaction.receiptPath = remote.receiptPath
                context.insert(newTransaction)
                if remote.receiptPath != nil { needingReceipt.append(newTransaction) }
            }
        }

        try context.save()

        // Descarga los recibos que faltan en este dispositivo.
        for transaction in needingReceipt {
            guard let path = transaction.receiptPath else { continue }
            do {
                transaction.receiptData = try await supabase.storage.from(Self.receiptsBucket).download(path: path)
            } catch {
                print("⚠️ No se pudo bajar el recibo \(path): \(error)")
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
        var isRemoved: Bool
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id, category, month, year
            case limitAmount = "limit_amount"
            case isRemoved = "is_deleted"
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
                isRemoved: budget.isRemoved,
                updatedAt: budget.updatedAt
            )
            try await supabase.from("budgets").upsert(dto).execute()
            budget.remoteID = id
            budget.needsSync = false
            try context.save() // guarda ya el remoteID: si no, un reintento duplicaría la fila en la nube
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
                if remote.updatedAt > local.updatedAt && !local.needsSync {
                    local.category = remote.category
                    local.limitAmount = remote.limitAmount
                    local.month = remote.month
                    local.year = remote.year
                    local.isRemoved = remote.isRemoved
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
                newBudget.isRemoved = remote.isRemoved
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
        var isRemoved: Bool
        var updatedAt: Date
        var emoji: String?

        enum CodingKeys: String, CodingKey {
            case id, name, scope, emoji
            case isRemoved = "is_deleted"
            case updatedAt = "updated_at"
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id)
            try c.encode(name, forKey: .name)
            try c.encode(scope, forKey: .scope)
            try c.encode(isRemoved, forKey: .isRemoved)
            try c.encode(updatedAt, forKey: .updatedAt)
            try c.encode(emoji, forKey: .emoji) // null borra el emoji en la nube
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
                isRemoved: category.isRemoved,
                updatedAt: category.updatedAt,
                emoji: category.emoji
            )
            try await supabase.from("categories").upsert(dto).execute()
            category.remoteID = id
            category.needsSync = false
            try context.save() // guarda ya el remoteID: si no, un reintento duplicaría la fila en la nube
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
                if remote.updatedAt > local.updatedAt && !local.needsSync {
                    local.name = remote.name
                    local.scope = CategoryScope(rawValue: remote.scope) ?? .expense
                    local.emoji = remote.emoji
                    local.isRemoved = remote.isRemoved
                    local.updatedAt = remote.updatedAt
                } else if local.emoji == nil, let emoji = remote.emoji {
                    local.emoji = emoji
                }
            } else {
                let newCategory = Category(name: remote.name, scope: CategoryScope(rawValue: remote.scope) ?? .expense)
                newCategory.remoteID = remote.id
                newCategory.emoji = remote.emoji
                newCategory.isRemoved = remote.isRemoved
                newCategory.updatedAt = remote.updatedAt
                newCategory.needsSync = false
                context.insert(newCategory)
            }
        }

        try context.save()

        // Refresca el caché local de emojis con lo que dice la nube.
        for category in try context.fetch(FetchDescriptor<Category>(predicate: #Predicate { !$0.isRemoved })) {
            if let emoji = category.emoji, !emoji.isEmpty {
                CategoryStyle.setEmoji(emoji, for: category.name)
            }
        }
    }


    // MARK: - Metas de ahorro

    private struct SavingsGoalDTO: Codable {
        var id: UUID
        var name: String
        var targetAmount: Double
        var savedAmount: Double
        var isRemoved: Bool
        var updatedAt: Date
        var targetDate: Date?

        enum CodingKeys: String, CodingKey {
            case id, name
            case targetAmount = "target_amount"
            case savedAmount = "saved_amount"
            case targetDate = "target_date"
            case isRemoved = "is_deleted"
            case updatedAt = "updated_at"
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(id, forKey: .id)
            try c.encode(name, forKey: .name)
            try c.encode(targetAmount, forKey: .targetAmount)
            try c.encode(savedAmount, forKey: .savedAmount)
            try c.encode(isRemoved, forKey: .isRemoved)
            try c.encode(updatedAt, forKey: .updatedAt)
            try c.encode(targetDate, forKey: .targetDate)
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
                isRemoved: goal.isRemoved,
                updatedAt: goal.updatedAt,
                targetDate: goal.targetDate
            )
            try await supabase.from("savings_goals").upsert(dto).execute()
            goal.remoteID = id
            goal.needsSync = false
            try context.save() // guarda ya el remoteID: si no, un reintento duplicaría la fila en la nube
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
                if remote.updatedAt > local.updatedAt && !local.needsSync {
                    local.name = remote.name
                    local.targetAmount = remote.targetAmount
                    local.savedAmount = remote.savedAmount
                    local.targetDate = remote.targetDate
                    local.isRemoved = remote.isRemoved
                    local.updatedAt = remote.updatedAt
                }
            } else {
                let newGoal = SavingsGoal(name: remote.name, targetAmount: remote.targetAmount, savedAmount: remote.savedAmount)
                newGoal.remoteID = remote.id
                newGoal.targetDate = remote.targetDate
                newGoal.isRemoved = remote.isRemoved
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
        var isRemoved: Bool
        var updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id, name, amount, type, category
            case dayOfMonth = "day_of_month"
            case isActive = "is_active"
            case lastGeneratedMonth = "last_generated_month"
            case lastGeneratedYear = "last_generated_year"
            case isRemoved = "is_deleted"
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
                isRemoved: item.isRemoved,
                updatedAt: item.updatedAt
            )
            try await supabase.from("recurring_expenses").upsert(dto).execute()
            item.remoteID = id
            item.needsSync = false
            try context.save() // guarda ya el remoteID: si no, un reintento duplicaría la fila en la nube
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
                if remote.updatedAt > local.updatedAt && !local.needsSync {
                    local.name = remote.name
                    local.amount = remote.amount
                    local.type = TransactionType(rawValue: remote.type) ?? .expense
                    local.category = remote.category
                    local.dayOfMonth = remote.dayOfMonth
                    local.isActive = remote.isActive
                    local.lastGeneratedMonth = remote.lastGeneratedMonth
                    local.lastGeneratedYear = remote.lastGeneratedYear
                    local.isRemoved = remote.isRemoved
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
                newItem.isRemoved = remote.isRemoved
                newItem.updatedAt = remote.updatedAt
                newItem.needsSync = false
                context.insert(newItem)
            }
        }

        try context.save()
    }
}
