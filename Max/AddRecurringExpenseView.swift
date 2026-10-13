import SwiftUI
import SwiftData

struct AddRecurringExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var itemToEdit: RecurringExpense?

    @State private var name: String = ""
    @State private var amount: Double = 0
    @State private var type: TransactionType = .expense
    @State private var category: String = ""
    @State private var dayOfMonth: Int = 1
    @State private var isActive: Bool = true

    @Query(filter: #Predicate<Category> { !$0.isRemoved }, sort: \Category.name) private var allCategories: [Category]

    private var currentCategories: [String] {
        let scope: CategoryScope = type == .expense ? .expense : .income
        return allCategories.filter { $0.scope == scope }.map { $0.name }
    }

    private var isEditing: Bool { itemToEdit != nil }
    private var isValid: Bool {
        guard amount > 0 else { return false }
        return !name.trimmingCharacters(in: .whitespaces).isEmpty && !category.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tipo") {
                    Picker("Tipo", selection: $type) {
                        ForEach(TransactionType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.appCardBackground)

                Section("Detalles") {
                    TextField("Nombre (ej. Arriendo, Netflix)", text: $name)

                    AmountField(value: $amount)

                    Picker("Categoría", selection: $category) {
                        Text("Selecciona").tag("")
                        ForEach(currentCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }

                    Picker("Día del mes", selection: $dayOfMonth) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)").tag(day)
                        }
                    }

                    Toggle("Activo", isOn: $isActive)
                }
                .listRowBackground(Color.appCardBackground)
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .tint(Color.appAccent)
            .navigationTitle(isEditing ? "Editar gasto fijo" : "Nuevo gasto fijo")
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
                if let item = itemToEdit {
                    name = item.name
                    amount = item.amount
                    type = item.type
                    category = item.category
                    dayOfMonth = item.dayOfMonth
                    isActive = item.isActive
                }
            }
            .onChange(of: type) {
                if !currentCategories.contains(category) {
                    category = ""
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if let item = itemToEdit {
            item.name = trimmedName
            item.amount = amount
            item.type = type
            item.category = category
            item.dayOfMonth = dayOfMonth
            item.isActive = isActive
            item.updatedAt = .now
            item.needsSync = true
        } else {
            let item = RecurringExpense(name: trimmedName, amount: amount, type: type, category: category, dayOfMonth: dayOfMonth, isActive: isActive)
            modelContext.insert(item)
        }
        dismiss()
    }
}

#Preview {
    AddRecurringExpenseView()
        .modelContainer(for: RecurringExpense.self, inMemory: true)
}
