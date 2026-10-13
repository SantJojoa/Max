import SwiftUI
import SwiftData

struct AddFundsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let goal: SavingsGoal

    private enum FundsMode: String, CaseIterable {
        case add = "Agregar"
        case withdraw = "Retirar"
    }

    @State private var mode: FundsMode = .add
    @State private var amount: Double = 0

    private var isValid: Bool { amount > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tipo", selection: $mode) {
                        ForEach(FundsMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    AmountField(value: $amount)
                } footer: {
                    Text("Ahorrado actualmente: \(CurrencyFormat.string(for: goal.savedAmount))")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .tint(Color.appAccent)
            .navigationTitle(goal.name)
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
        }
    }

    private func save() {
        if mode == .add {
            goal.savedAmount += amount
        } else {
            goal.savedAmount = max(0, goal.savedAmount - amount)
        }
        goal.updatedAt = .now
        goal.needsSync = true
        dismiss()
    }
}

#Preview {
    AddFundsView(goal: SavingsGoal(name: "Viaje", targetAmount: 3000000))
        .modelContainer(for: SavingsGoal.self, inMemory: true)
}
