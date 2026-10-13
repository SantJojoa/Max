import SwiftUI
import SwiftData

struct CardDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let card: CreditCard

    @State private var showingAddPurchase = false
    @State private var showingAddPayment = false
    @State private var editingTransaction: CardTransaction?

    private var sortedTransactions: [CardTransaction] {
        card.transactions.filter { !$0.isDeleted }.sorted { $0.date > $1.date }
    }

    private var usedCupo: Double {
        let activeTransactions = card.transactions.filter { !$0.isDeleted }
        let purchases = activeTransactions.filter { $0.type == .purchase }.reduce(0) { $0 + $1.amount }
        let payments = activeTransactions.filter { $0.type == .payment }.reduce(0) { $0 + $1.amount }
        return purchases - payments
    }

    private var availableCupo: Double {
        card.creditLimit - usedCupo
    }

    private var usageRatio: Double {
        guard card.creditLimit > 0 else { return 0 }
        return min(max(usedCupo / card.creditLimit, 0), 1)
    }

    private var progressColor: Color {
        if usageRatio >= 0.9 { return .appExpense }
        if usageRatio >= 0.7 { return .orange }
        return .appAccent
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Usado")
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                            Text(CurrencyFormat.string(for: usedCupo))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.appExpense)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Disponible")
                                .font(.caption)
                                .foregroundStyle(Color.appTextSecondary)
                            Text(CurrencyFormat.string(for: availableCupo))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.appIncome)
                        }
                    }

                    ProgressView(value: usageRatio)
                        .tint(progressColor)
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.appCardBackground)

            Section("Detalles") {
                detailRow(title: "Día de corte", value: "\(card.closingDay)")
                detailRow(title: "Tasa de interés mensual", value: card.monthlyInterestRate.formatted(.number.precision(.fractionLength(1))) + "%")
                detailRow(title: "Cuota de manejo", value: CurrencyFormat.string(for: card.managementFee))
            }
            .listRowBackground(Color.appCardBackground)

            Section("Movimientos") {
                if sortedTransactions.isEmpty {
                    Text("Todavía no hay movimientos en esta tarjeta.")
                        .foregroundStyle(Color.appTextSecondary)
                } else {
                    ForEach(sortedTransactions) { transaction in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill((transaction.type == .payment ? Color.appIncome : Color.appExpense).opacity(0.15))
                                    .frame(width: 36, height: 36)
                                Image(systemName: transaction.type == .payment ? "arrow.down" : "cart.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(transaction.type == .payment ? Color.appIncome : Color.appExpense)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(transaction.type == .purchase ? transaction.category : "Pago")
                                    .font(.headline)
                                Text(transaction.date, format: .dateTime.day().month().year())
                                    .font(.caption)
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                            Spacer()
                            Text(CurrencyFormat.string(for: transaction.amount))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(transaction.type == .payment ? Color.appIncome : Color.appExpense)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingTransaction = transaction
                        }
                    }
                    .onDelete(perform: deleteTransactions)
                }
            }
            .listRowBackground(Color.appCardBackground)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingAddPurchase = true
                    } label: {
                        Label("Registrar compra", systemImage: "cart")
                    }
                    Button {
                        showingAddPayment = true
                    } label: {
                        Label("Registrar pago", systemImage: "creditcard.and.123")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
        .sheet(isPresented: $showingAddPurchase) {
            AddCardTransactionView(card: card, type: .purchase)
        }
        .sheet(isPresented: $showingAddPayment) {
            AddCardTransactionView(card: card, type: .payment)
        }
        .sheet(item: $editingTransaction) { transaction in
            AddCardTransactionView(card: card, type: transaction.type, transactionToEdit: transaction)
        }
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            let transaction = sortedTransactions[index]
            transaction.isDeleted = true
            transaction.updatedAt = .now
            transaction.needsSync = true
        }
    }
}

#Preview {
    NavigationStack {
        CardDetailView(card: CreditCard(name: "Visa", creditLimit: 1000000, closingDay: 15, monthlyInterestRate: 2.0, managementFee: 15000))
    }
    .modelContainer(for: [CreditCard.self, CardTransaction.self], inMemory: true)
}
