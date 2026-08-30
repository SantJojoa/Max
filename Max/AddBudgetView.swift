import SwiftUI
import SwiftData

struct AddBudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var budgetToEdit: Budget?

    @State private var category: String = ""
    @State private var limitText: String = ""

    private let categories = ["Comida", "Transporte", "Vivienda", "Entretenimiento", "Salud", "Otros"]

    private var currentMonth: Int { Calendar.current.component(.month, from: .now) }
    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

    private var isValid: Bool {
        guard let limit = Double(limitText), limit > 0 else { return false }
        return !category.isEmpty
    }

    private var isEditing: Bool { budgetToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Categoría", selection: $category) {
                    Text("Selecciona").tag("")
                    ForEach(categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }

                TextField("Límite mensual", text: $limitText)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle(isEditing ? "Editar presupuesto" : "Nuevo presupuesto")
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
                if let budget = budgetToEdit {
                    category = budget.category
                    limitText = budget.limitAmount == budget.limitAmount.rounded()
                        ? String(Int(budget.limitAmount))
                        : String(budget.limitAmount)
                }
            }
        }
    }

    private func save() {
        guard let limit = Double(limitText) else { return }

        if let budget = budgetToEdit {
            budget.category = category
            budget.limitAmount = limit
        } else {
            let budget = Budget(category: category, limitAmount: limit, month: currentMonth, year: currentYear)
            modelContext.insert(budget)
        }
        dismiss()
    }
}

#Preview {
    AddBudgetView()
        .modelContainer(for: Budget.self, inMemory: true)
}
