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
    @State private var creditLimit: Double = 0
    @State private var closingDayText: String = ""
    @State private var interestRateText: String = ""
    @State private var managementFee: Double = 0

    private var isEditing: Bool { cardToEdit != nil }

    private var isValid: Bool {
        guard !name.isEmpty else { return false }
        guard creditLimit > 0 else { return false }
        guard let day = Int(closingDayText), day >= 1, day <= 31 else { return false }
        guard Double(interestRateText) != nil else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Datos de la tarjeta") {
                    TextField("Nombre (ej. Bancolombia Visa)", text: $name)

                    AmountField(placeholder: "Cupo total", value: $creditLimit)

                    TextField("Día de corte (1-31)", text: $closingDayText)
                        .keyboardType(.numberPad)

                    TextField("Tasa de interés mensual (%)", text: $interestRateText)
                        .keyboardType(.decimalPad)

                    AmountField(placeholder: "Cuota de manejo", value: $managementFee)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .tint(Color.appAccent)
            .navigationTitle(isEditing ? "Editar tarjeta" : "Nueva tarjeta")
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
                if let card = cardToEdit {
                    name = card.name
                    creditLimit = card.creditLimit
                    closingDayText = String(card.closingDay)
                    interestRateText = String(card.monthlyInterestRate)
                    managementFee = card.managementFee
                }
            }
        }
    }

    private func save() {
        guard let day = Int(closingDayText),
              let rate = Double(interestRateText) else { return }

        if let card = cardToEdit {
            card.name = name
            card.creditLimit = creditLimit
            card.closingDay = day
            card.monthlyInterestRate = rate
            card.managementFee = managementFee
            card.updatedAt = .now
            card.needsSync = true
        } else {
            let card = CreditCard(name: name, creditLimit: creditLimit, closingDay: day, monthlyInterestRate: rate, managementFee: managementFee)
            modelContext.insert(card)
        }
        dismiss()
    }
}

#Preview {
    AddCreditCardView()
        .modelContainer(for: CreditCard.self, inMemory: true)
}
