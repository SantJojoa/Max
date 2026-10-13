import SwiftUI
import SwiftData

struct AddSavingsGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var goalToEdit: SavingsGoal?

    @State private var name: String = ""
    @State private var target: Double = 0

    private var isEditing: Bool { goalToEdit != nil }
    private var isValid: Bool {
        guard target > 0 else { return false }
        return !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre (ej. Viaje, Fondo de emergencia)", text: $name)
                .listRowBackground(Color.appCardBackground)

                AmountField(placeholder: "Monto objetivo", value: $target)
                .listRowBackground(Color.appCardBackground)
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .tint(Color.appAccent)
            .navigationTitle(isEditing ? "Editar meta" : "Nueva meta")
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
                if let goal = goalToEdit {
                    name = goal.name
                    target = goal.targetAmount
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        if let goal = goalToEdit {
            goal.name = trimmedName
            goal.targetAmount = target
            goal.updatedAt = .now
            goal.needsSync = true
        } else {
            let goal = SavingsGoal(name: trimmedName, targetAmount: target)
            modelContext.insert(goal)
        }
        dismiss()
    }
}

#Preview {
    AddSavingsGoalView()
        .modelContainer(for: SavingsGoal.self, inMemory: true)
}
