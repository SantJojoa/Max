//
//  AddCreditCardView.swift
//  Max
//
//  Created by Santiago Jojoa on 29/08/26.
//

import SwiftUI
import SwiftData

struct AddCreditCardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var cardToEdit: CreditCard?

    @State private var name: String = ""
    @State private var creditLimitText: String = ""
    @State private var closingDayText: String = ""
    @State private var interestRateText: String = ""
    @State private var managementFeeText: String = ""

    private var isEditing: Bool { cardToEdit != nil }

    private var isValid: Bool {
        guard !name.isEmpty else { return false }
        guard let limit = Double(creditLimitText), limit > 0 else { return false }
        guard let day = Int(closingDayText), day >= 1, day <= 31 else { return false }
        guard Double(interestRateText) != nil else { return false }
        guard Double(managementFeeText) != nil else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos de la tarjeta") {
                    TextField("Nombre (ej. Bancolombia Visa)", text: $name)

                    TextField("Cupo total", text: $creditLimitText)
                        .keyboardType(.decimalPad)

                    TextField("Día de corte (1-31)", text: $closingDayText)
                        .keyboardType(.numberPad)

                    TextField("Tasa de interés mensual (%)", text: $interestRateText)
                        .keyboardType(.decimalPad)

                    TextField("Cuota de manejo", text: $managementFeeText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle(isEditing ? "Editar tarjeta" : "Nueva tarjeta")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(!isValid)
                }
            }
            .onAppear {
                if let card = cardToEdit {
                    name = card.name
                    creditLimitText = String(Int(card.creditLimit))
                    closingDayText = String(card.closingDay)
                    interestRateText = String(card.monthlyInterestRate)
                    managementFeeText = String(Int(card.managementFee))
                }
            }
        }
    }

    private func save() {
        guard let limit = Double(creditLimitText),
              let day = Int(closingDayText),
              let rate = Double(interestRateText),
              let fee = Double(managementFeeText) else { return }

        if let card = cardToEdit {
            card.name = name
            card.creditLimit = limit
            card.closingDay = day
            card.monthlyInterestRate = rate
            card.managementFee = fee
        } else {
            let card = CreditCard(name: name, creditLimit: limit, closingDay: day, monthlyInterestRate: rate, managementFee: fee)
            modelContext.insert(card)
        }
        dismiss()
    }
}

#Preview {
    AddCreditCardView()
        .modelContainer(for: CreditCard.self, inMemory: true)
}
