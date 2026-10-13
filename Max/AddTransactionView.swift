import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var transactionToEdit: Transaction?

    @State private var amount: Double = 0
    @State private var type: TransactionType = .expense
    @State private var category: String = ""
    @State private var date: Date = .now
    @State private var note: String = ""

    @Query private var budgets: [Budget]
    @Query private var allTransactions: [Transaction]
    @Query(filter: #Predicate<Category> { !$0.isDeleted }, sort: \Category.name) private var allCategories: [Category]

    private var currentCategories: [String] {
        let scope: CategoryScope = type == .expense ? .expense : .income
        return allCategories.filter { $0.scope == scope }.map { $0.name }
    }

    private var isValid: Bool {
        guard amount > 0 else { return false }
        return !category.isEmpty
    }

    private var isEditing: Bool { transactionToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo") {
                    Picker("Tipo", selection: $type) {
                        ForEach(TransactionType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Detalles") {
                    AmountField(value: $amount)

                    Picker("Categoría", selection: $category) {
                        Text("Selecciona").tag("")
                        ForEach(currentCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }

                    DatePicker("Fecha", selection: $date, displayedComponents: .date)

                    TextField("Nota (opcional)", text: $note)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .tint(Color.appAccent)
            .navigationTitle(isEditing ? "Editar transacción" : "Nueva transacción")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let transaction = transactionToEdit {
                    amount = transaction.amount
                    type = transaction.type
                    category = transaction.category
                    date = transaction.date
                    note = transaction.note
                }
            }
            .onChange(of: type) {
                if !currentCategories.contains(category) {
                    category = ""
                }
            }
        }
    }

    private func save() {
        if let transaction = transactionToEdit {
            transaction.amount = amount
            transaction.type = type
            transaction.category = category
            transaction.date = date
            transaction.note = note
            transaction.updatedAt = .now
            transaction.needsSync = true
        } else {
            let transaction = Transaction(amount: amount, type: type, category: category, date: date, note: note)
            modelContext.insert(transaction)
        }

        if type == .expense {
            checkBudgetAndNotify(category: category, amount: amount)
        }

        dismiss()
    }

    private func checkBudgetAndNotify(category: String, amount: Double) {
        let month = Calendar.current.component(.month, from: date)
        let year = Calendar.current.component(.year, from: date)

        guard let budget = budgets.first(where: {
            $0.category == category && $0.month == month && $0.year == year
        }) else { return }

        // Sumamos los gastos de esa categoría/mes SIN contar la transacción actual (para no duplicarla si se está editando),
        // y le sumamos el monto actual manualmente.
        let spentExcludingThis = allTransactions
            .filter { $0 !== transactionToEdit }
            .filter {
                $0.type == .expense &&
                $0.category == category &&
                Calendar.current.component(.month, from: $0.date) == month &&
                Calendar.current.component(.year, from: $0.date) == year
            }
            .reduce(0) { $0 + $1.amount }

        let totalSpent = spentExcludingThis + amount
        let ratio = totalSpent / budget.limitAmount

        if ratio >= 1.0 {
            NotificationManager.shared.sendBudgetAlert(category: category, exceeded: true)
        } else if ratio >= 0.8 {
            NotificationManager.shared.sendBudgetAlert(category: category, exceeded: false)
        }
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
