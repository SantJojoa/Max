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
    @State private var installments: Int = 1

    @Query(filter: #Predicate<Category> { !$0.isRemoved }, sort: \Category.name) private var allCategories: [Category]
    private var purchaseCategories: [String] {
        var seen = Set<String>()
        var names = allCategories.filter { $0.scope == .card || $0.scope == .expense }.map(\.name).filter { seen.insert($0.lowercased()).inserted }
        if !category.isEmpty && !names.contains(category) { names.append(category) }
        return names
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
                .listRowBackground(Color.appCardBackground)

                if type == .purchase {
                    Picker("Categoría", selection: $category) {
                        Text("Selecciona").tag("")
                        ForEach(purchaseCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .listRowBackground(Color.appCardBackground)
                }

                if type == .purchase {
                    Stepper(value: $installments, in: 1...120) {
                        HStack {
                            Text("Cuotas")
                            Spacer()
                            Text(installments == 1 ? "1 pago" : "\(installments) cuotas")
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                    .listRowBackground(Color.appCardBackground)
                }

                DatePicker("Fecha", selection: $date, displayedComponents: .date)
                .listRowBackground(Color.appCardBackground)

                TextField("Nota (opcional)", text: $note)
                .listRowBackground(Color.appCardBackground)
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
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
                    installments = max(transaction.installments, 1)
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
            transaction.installments = type == .purchase ? installments : 1
            transaction.updatedAt = .now
            transaction.needsSync = true
        } else {
            let transaction = CardTransaction(amount: amount, type: type, category: finalCategory, date: date, note: note, card: card)
            transaction.installments = type == .purchase ? installments : 1
            modelContext.insert(transaction)
        }
        dismiss()
    }
}

#Preview {
    AddCardTransactionView(card: CreditCard(name: "Visa", creditLimit: 1000000, closingDay: 15, monthlyInterestRate: 2.0, managementFee: 15000), type: .purchase)
        .modelContainer(for: CardTransaction.self, inMemory: true)
}
