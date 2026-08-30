import SwiftUI
import SwiftData

struct BudgetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var budgets: [Budget]
    @Query private var transactions: [Transaction]
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
        NavigationStack {
            List {
                if currentBudgets.isEmpty {
                    ContentUnavailableView(
                        "Sin presupuestos este mes",
                        systemImage: "chart.pie",
                        description: Text("Toca + para crear tu primer presupuesto mensual.")
                    )
                } else {
                    ForEach(currentBudgets) { budget in
                        BudgetRow(budget: budget, spent: spent(for: budget.category))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingBudget = budget
                            }
                    }
                    .onDelete(perform: deleteBudgets)
                }
            }
            .navigationTitle("Presupuestos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddBudget = true
                    } label: {
                        Label("Agregar", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBudget) {
                AddBudgetView()
            }
            .sheet(item: $editingBudget) { budget in
                AddBudgetView(budgetToEdit: budget)
            }
        }
    }

    private func deleteBudgets(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(currentBudgets[index])
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
        let ratio = spent / budget.limitAmount
        if ratio >= 1.0 { return .red }
        if ratio >= 0.8 { return .orange }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(budget.category)
                    .font(.headline)
                Spacer()
                Text("\(spent, format: .currency(code: "COP")) / \(budget.limitAmount, format: .currency(code: "COP"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(progressColor)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BudgetsView()
        .modelContainer(for: [Transaction.self, Budget.self], inMemory: true)
}
