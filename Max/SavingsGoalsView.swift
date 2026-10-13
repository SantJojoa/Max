import SwiftUI
import SwiftData

/// Contenido de la sección "Metas de ahorro" dentro de `PlanningView`.
/// No es dueño de su propio `List`/`NavigationStack`: sus filas se insertan
/// directamente en la `Section` del `List` que lo contiene.
struct SavingsGoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<SavingsGoal> { !$0.isDeleted }, sort: \SavingsGoal.name) private var goals: [SavingsGoal]
    @State private var showingAdd = false
    @State private var editingGoal: SavingsGoal?
    @State private var fundingGoal: SavingsGoal?

    var body: some View {
        Group {
            if goals.isEmpty {
                emptyRow
            } else {
                ForEach(goals) { goal in
                    goalRow(goal)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .swipeActions(edge: .leading) {
                            Button {
                                editingGoal = goal
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
                .onDelete(perform: deleteGoals)
            }

            addRow
        }
        .sheet(isPresented: $showingAdd) {
            AddSavingsGoalView()
        }
        .sheet(item: $editingGoal) { goal in
            AddSavingsGoalView(goalToEdit: goal)
        }
        .sheet(item: $fundingGoal) { goal in
            AddFundsView(goal: goal)
        }
    }

    private var emptyRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sin metas de ahorro")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.appTextPrimary)
            Text("Toca \"Nueva meta\" para crear la primera.")
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var addRow: some View {
        Button {
            showingAdd = true
        } label: {
            Label("Nueva meta", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appAccent)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private func goalRow(_ goal: SavingsGoal) -> some View {
        let progress = goal.targetAmount > 0 ? min(goal.savedAmount / goal.targetAmount, 1.0) : 0
        let isComplete = goal.savedAmount >= goal.targetAmount && goal.targetAmount > 0
        let tint: Color = isComplete ? .appIncome : .appBlue

        HStack(spacing: Spacing.l) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.18), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Image(systemName: isComplete ? "checkmark" : "target")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                    Text(progress, format: .percent.precision(.fractionLength(0)))
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.appTextPrimary)
                }
            }
            .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)
                Text("\(CurrencyFormat.string(for: goal.savedAmount)) / \(CurrencyFormat.string(for: goal.targetAmount))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Button {
                    fundingGoal = goal
                } label: {
                    Label("Agregar fondos", systemImage: "plus.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appAccent.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .floatingCardStyle()
    }

    private func deleteGoals(at offsets: IndexSet) {
        for index in offsets {
            let goal = goals[index]
            goal.isDeleted = true
            goal.updatedAt = .now
            goal.needsSync = true
        }
    }
}

#Preview {
    NavigationStack {
        List {
            Section("Metas de ahorro") {
                SavingsGoalsView()
            }
        }
    }
    .modelContainer(for: SavingsGoal.self, inMemory: true)
}
