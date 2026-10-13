import SwiftUI
import SwiftData

struct PlanningView: View {
    private enum Segment: String, CaseIterable {
        case budgets = "Presupuestos"
        case goals = "Metas"
        case recurring = "Gastos fijos"
    }

    @State private var segment: Segment = .budgets

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Sección", selection: $segment) {
                        ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }

                Section {
                    switch segment {
                    case .budgets: BudgetsView()
                    case .goals: SavingsGoalsView()
                    case .recurring: RecurringExpensesView()
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .animation(.snappy(duration: 0.2), value: segment)
            .navigationTitle("Planificación")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    PlanningView()
        .modelContainer(for: [Transaction.self, Budget.self, SavingsGoal.self, RecurringExpense.self, Category.self], inMemory: true)
}
