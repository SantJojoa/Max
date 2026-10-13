import SwiftUI
import SwiftData

/// Contenido de la sección "Presupuestos" dentro de `PlanningView`.
/// No es dueño de su propio `List`/`NavigationStack`: sus filas se insertan
/// directamente en la `Section` del `List` que lo contiene.
struct BudgetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Budget> { !$0.isDeleted }) private var budgets: [Budget]
    @Query(filter: #Predicate<Transaction> { !$0.isDeleted }) private var transactions: [Transaction]
    @State private var showingAddBudget = false
    @State private var editingBudget: Budget?

    private var currentMonth: Int { Calendar.current.component(.month, from: .now) }
    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

    private var currentBudgets: [Budget] {
        budgets.filter { $0.month == currentMonth && $0.year == currentYear }
    }

    private func spent(for category: String) -> Double {
        transactions
            .filter { transaction in
                transaction.type == .expense &&
                transaction.category == category &&
                Calendar.current.component(.month, from: transaction.date) == currentMonth &&
                Calendar.current.component(.year, from: transaction.date) == currentYear
            }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        Group {
            if currentBudgets.isEmpty {
                emptyRow
            } else {
                ForEach(currentBudgets) { budget in
                    BudgetRow(budget: budget, spent: spent(for: budget.category))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .swipeActions(edge: .leading) {
                            Button {
                                editingBudget = budget
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
                .onDelete(perform: deleteBudgets)
            }

            addRow
        }
        .sheet(isPresented: $showingAddBudget) {
            AddBudgetView()
        }
        .sheet(item: $editingBudget) { budget in
            AddBudgetView(budgetToEdit: budget)
        }
    }

    private var emptyRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sin presupuestos este mes")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.appTextPrimary)
            Text("Toca \"Nuevo presupuesto\" para crear el primero.")
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var addRow: some View {
        Button {
            showingAddBudget = true
        } label: {
            Label("Nuevo presupuesto", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appAccent)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func deleteBudgets(at offsets: IndexSet) {
        for index in offsets {
            let budget = currentBudgets[index]
            budget.isDeleted = true
            budget.updatedAt = .now
            budget.needsSync = true
        }
    }
}

private struct BudgetRow: View {
    let budget: Budget
    let spent: Double

    private var progress: Double {
        guard budget.limitAmount > 0 else { return 0 }
        return min(spent / budget.limitAmount, 1.0)
    }

    private var progressColor: Color {
        let ratio = budget.limitAmount > 0 ? spent / budget.limitAmount : 0
        if ratio >= 1.0 { return .appExpense }
        if ratio >= 0.8 { return .orange }
        return .appAccent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(budget.category)
                    .font(.headline)
                Spacer()
                Text("\(CurrencyFormat.string(for: spent)) / \(CurrencyFormat.string(for: budget.limitAmount))")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
            }
            ProgressView(value: progress)
                .tint(progressColor)
        }
        .floatingCardStyle()
    }
}

#Preview {
    NavigationStack {
        List {
            Section("Presupuestos") {
                BudgetsView()
            }
        }
    }
    .modelContainer(for: [Transaction.self, Budget.self], inMemory: true)
}
