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
                overviewCard
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))

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

    private var totalSpent: Double {
        currentBudgets.reduce(0) { $0 + spent(for: $1.category) }
    }

    private var totalLimit: Double {
        currentBudgets.reduce(0) { $0 + $1.limitAmount }
    }

    private var overviewCard: some View {
        let ratio = totalLimit > 0 ? totalSpent / totalLimit : 0
        let tint: Color = ratio >= 1 ? .appExpense : (ratio >= 0.8 ? .appOrange : .appAccent)
        let daysLeft = max(0, (Calendar.current.range(of: .day, in: .month, for: .now)?.count ?? 30) - Calendar.current.component(.day, from: .now))

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gastado este mes")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                    Text(CurrencyFormat.string(for: totalSpent))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.appTextPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                Spacer()
                Text(ratio, format: .percent.precision(.fractionLength(0)))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.15))
                    .clipShape(Capsule())
            }
            CapsuleProgress(value: ratio, tint: tint, height: 10)
            HStack {
                Text(totalLimit >= totalSpent
                     ? "Restan \(CurrencyFormat.string(for: totalLimit - totalSpent))"
                     : "Excedido por \(CurrencyFormat.string(for: totalSpent - totalLimit))")
                Spacer()
                Text("\(daysLeft) días restantes")
            }
            .font(.caption)
            .foregroundStyle(Color.appTextSecondary)
        }
        .floatingCardStyle()
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

    private var ratio: Double {
        budget.limitAmount > 0 ? spent / budget.limitAmount : 0
    }

    private var progressColor: Color {
        if ratio >= 1.0 { return .appExpense }
        if ratio >= 0.8 { return .appOrange }
        return .appAccent
    }

    private var statusText: String {
        let remaining = budget.limitAmount - spent
        if remaining < 0 { return "Excedido por \(CurrencyFormat.string(for: -remaining))" }
        if ratio >= 0.8 { return "Quedan \(CurrencyFormat.string(for: remaining))" }
        return "Margen disponible"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                CategoryIcon(name: budget.category)
                VStack(alignment: .leading, spacing: 2) {
                    Text(budget.category)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(ratio >= 1 ? Color.appExpense : Color.appTextSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyFormat.string(for: spent))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.appTextPrimary)
                    Text("de \(CurrencyFormat.string(for: budget.limitAmount))")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            CapsuleProgress(value: ratio, tint: progressColor)
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
