import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var categoryToEdit: Category?
    var defaultScope: CategoryScope = .expense

    @State private var name: String = ""
    @State private var scope: CategoryScope = .expense

    private var isEditing: Bool { categoryToEdit != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre", text: $name)
                .listRowBackground(Color.appCardBackground)

                Picker("Tipo", selection: $scope) {
                    ForEach(CategoryScope.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .listRowBackground(Color.appCardBackground)
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .tint(Color.appAccent)
            .navigationTitle(isEditing ? "Editar categoría" : "Nueva categoría")
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
                if let category = categoryToEdit {
                    name = category.name
                    scope = category.scope
                } else {
                    scope = defaultScope
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let category = categoryToEdit {
            category.name = trimmed
            category.scope = scope
            category.updatedAt = .now
            category.needsSync = true
        } else {
            let category = Category(name: trimmed, scope: scope)
            modelContext.insert(category)
        }
        dismiss()
    }
}

#Preview {
    AddCategoryView()
        .modelContainer(for: Category.self, inMemory: true)
}
