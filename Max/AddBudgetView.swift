import SwiftUI
import SwiftData

struct AddBudgetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var budgetToEdit: Budget?

    @State private var category: String = ""
    @State private var limit: Double = 0

    @Query(filter: #Predicate<Category> { !$0.isDeleted }, sort: \Category.name) private var allCategories: [Category]
    private var categories: [String] {
        allCategories.filter { $0.scope == .expense }.map { $0.name }
    }

    private var currentMonth: Int { Calendar.current.component(.month, from: .now) }
    private var currentYear: Int { Calendar.current.component(.year, from: .now) }

    private var isValid: Bool {
        guard limit > 0 else { return false }
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
                .listRowBackground(Color.appCardBackground)

                AmountField(placeholder: "Límite mensual", value: $limit)
                .listRowBackground(Color.appCardBackground)
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .tint(Color.appAccent)
            .navigationTitle(isEditing ? "Editar presupuesto" : "Nuevo presupuesto")
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
                if let budget = budgetToEdit {
                    category = budget.category
                    limit = budget.limitAmount
                }
            }
        }
    }

    private func save() {
        if let budget = budgetToEdit {
            budget.category = category
            budget.limitAmount = limit
            budget.updatedAt = .now
            budget.needsSync = true
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
