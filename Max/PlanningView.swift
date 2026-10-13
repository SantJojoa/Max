import SwiftUI
import SwiftData

struct PlanningView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    BudgetsView()
                } header: {
                    sectionHeader(title: "Presupuestos", icon: "chart.pie.fill", tint: .orange)
                }

                Section {
                    SavingsGoalsView()
                } header: {
                    sectionHeader(title: "Metas de ahorro", icon: "target", tint: .blue)
                }

                Section {
                    RecurringExpensesView()
                } header: {
                    sectionHeader(title: "Gastos fijos", icon: "repeat", tint: .purple)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Planificación")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    @ViewBuilder
    private func sectionHeader(title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: Spacing.s) {
            IconBadge(systemImage: icon, tint: tint, size: 24)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.appTextPrimary)
        }
        .textCase(nil)
        .padding(.top, Spacing.s)
        .padding(.bottom, Spacing.xs)
    }
}

#Preview {
    PlanningView()
        .modelContainer(for: [Transaction.self, Budget.self, SavingsGoal.self, RecurringExpense.self, Category.self], inMemory: true)
}
