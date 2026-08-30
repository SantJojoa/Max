import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var showingAddView = false
    @State private var editingTransaction: Transaction?

    private var totalIncome: Double {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpense: Double {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var balance: Double {
        totalIncome - totalExpense
    }

    private var expensesByCategory: [(category: String, total: Double)] {
        let expenses = transactions.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses, by: { $0.category })
        return grouped
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Resumen") {
                    HStack {
                        Text("Balance")
                            .font(.headline)
                        Spacer()
                        Text(balance, format: .currency(code: "COP"))
                            .font(.headline)
                            .foregroundStyle(balance >= 0 ? .green : .red)
                    }
                    HStack {
                        Text("Ingresos")
                        Spacer()
                        Text(totalIncome, format: .currency(code: "COP"))
                            .foregroundStyle(.green)
                    }
                    HStack {
                        Text("Gastos")
                        Spacer()
                        Text(totalExpense, format: .currency(code: "COP"))
                            .foregroundStyle(.red)
                    }
                }

                if !expensesByCategory.isEmpty {
                    Section("Gastos por categoría") {
                        ForEach(expensesByCategory, id: \.category) { item in
                            HStack {
                                Text(item.category)
                                Spacer()
                                Text(item.total, format: .currency(code: "COP"))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Movimientos") {
                    ForEach(transactions) { transaction in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(transaction.category)
                                    .font(.headline)
                                Text(transaction.date, format: .dateTime.day().month().year())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(transaction.amount, format: .currency(code: "COP"))
                                .foregroundStyle(transaction.type == .income ? .green : .red)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingTransaction = transaction
                        }
                    }
                    .onDelete(perform: deleteTransactions)
                }
            }
            .navigationTitle("Mis Finanzas")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddView = true
                    } label: {
                        Label("Agregar", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddView) {
                AddTransactionView()
            }
            .sheet(item: $editingTransaction) { transaction in
                AddTransactionView(transactionToEdit: transaction)
            }
        }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(transactions[index])
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
