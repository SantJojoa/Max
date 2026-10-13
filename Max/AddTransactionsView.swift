//
//  AddTransactionsView.swift
//  Max
//
//  Created by Santiago Jojoa on 29/08/26.
//

import SwiftUI
import SwiftData

struct AddCardTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let card: CreditCard
    let type: CardTransactionType
    var transactionToEdit: CardTransaction?

    @State private var amount: Double = 0
    @State private var category: String = ""
    @State private var date: Date = .now
    @State private var note: String = ""

    @Query(filter: #Predicate<Category> { !$0.isDeleted }, sort: \Category.name) private var allCategories: [Category]
    private var purchaseCategories: [String] {
        allCategories.filter { $0.scope == .card }.map { $0.name }
    }

    private var isEditing: Bool { transactionToEdit != nil }

    private var isValid: Bool {
        guard amount > 0 else { return false }
        if type == .purchase { return !category.isEmpty }
        return true
    }

    private var navigationTitleText: String {
        if isEditing {
            return type == .purchase ? "Editar compra" : "Editar pago"
        } else {
            return type == .purchase ? "Nueva compra" : "Nuevo pago"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                AmountField(value: $amount)

                if type == .purchase {
                    Picker("Categoría", selection: $category) {
                        Text("Selecciona").tag("")
                        ForEach(purchaseCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }

                DatePicker("Fecha", selection: $date, displayedComponents: .date)

                TextField("Nota (opcional)", text: $note)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .tint(Color.appAccent)
            .navigationTitle(navigationTitleText)
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
                    category = transaction.category
                    date = transaction.date
                    note = transaction.note
                }
            }
        }
    }

    private func save() {
        let finalCategory = type == .purchase ? category : "Pago"

        if let transaction = transactionToEdit {
            transaction.amount = amount
            transaction.category = finalCategory
            transaction.date = date
            transaction.note = note
            transaction.updatedAt = .now
            transaction.needsSync = true
        } else {
            let transaction = CardTransaction(amount: amount, type: type, category: finalCategory, date: date, note: note, card: card)
            modelContext.insert(transaction)
        }
        dismiss()
    }
}

#Preview {
    AddCardTransactionView(card: CreditCard(name: "Visa", creditLimit: 1000000, closingDay: 15, monthlyInterestRate: 2.0, managementFee: 15000), type: .purchase)
        .modelContainer(for: CardTransaction.self, inMemory: true)
}
