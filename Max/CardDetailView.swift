//
//  CardDetailView.swift
//  Max
//
//  Created by Santiago Jojoa on 29/08/26.
//

import SwiftUI
import SwiftData

struct CardDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let card: CreditCard

    @State private var showingAddPurchase = false
    @State private var showingAddPayment = false
    @State private var editingTransaction: CardTransaction?

    private var sortedTransactions: [CardTransaction] {
        card.transactions.sorted { $0.date > $1.date }
    }

    private var usedCupo: Double {
        let purchases = card.transactions.filter { $0.type == .purchase }.reduce(0) { $0 + $1.amount }
        let payments = card.transactions.filter { $0.type == .payment }.reduce(0) { $0 + $1.amount }
        return purchases - payments
    }

    private var availableCupo: Double {
        card.creditLimit - usedCupo
    }

    private var usageRatio: Double {
        guard card.creditLimit > 0 else { return 0 }
        return min(max(usedCupo / card.creditLimit, 0), 1)
    }

    var body: some View {
        List {
            Section("Cupo") {
                HStack {
                    Text("Usado")
                    Spacer()
                    Text(usedCupo, format: .currency(code: "COP"))
                        .foregroundStyle(.red)
                }
                HStack {
                    Text("Disponible")
                    Spacer()
                    Text(availableCupo, format: .currency(code: "COP"))
                        .foregroundStyle(.green)
                }
                ProgressView(value: usageRatio)
                    .tint(usageRatio >= 0.9 ? .red : .blue)

                HStack {
                    Text("Día de corte")
                    Spacer()
                    Text("\(card.closingDay)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Tasa de interés mensual")
                    Spacer()
                    (Text(card.monthlyInterestRate, format: .number.precision(.fractionLength(1))) + Text("%"))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Cuota de manejo")
                    Spacer()
                    Text(card.managementFee, format: .currency(code: "COP"))
                        .foregroundStyle(.secondary)
                }
            }

            Section("Movimientos") {
                if sortedTransactions.isEmpty {
                    Text("Todavía no hay movimientos en esta tarjeta.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedTransactions) { transaction in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(transaction.type == .purchase ? transaction.category : "Pago")
                                    .font(.headline)
                                Text(transaction.date, format: .dateTime.day().month().year())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(transaction.amount, format: .currency(code: "COP"))
                                .foregroundStyle(transaction.type == .payment ? .green : .red)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingTransaction = transaction
                        }
                    }
                    .onDelete(perform: deleteTransactions)
                }
            }
        }
        .navigationTitle(card.name)
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
                    Label("Agregar", systemImage: "plus")
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

    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedTransactions[index])
        }
    }
}

#Preview {
    NavigationStack {
        CardDetailView(card: CreditCard(name: "Visa", creditLimit: 1000000, closingDay: 15, monthlyInterestRate: 2.0, managementFee: 15000))
    }
    .modelContainer(for: [CreditCard.self, CardTransaction.self], inMemory: true)
}
