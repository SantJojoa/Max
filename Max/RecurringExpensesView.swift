import SwiftUI
import SwiftData

/// Contenido de la sección "Gastos fijos" dentro de `PlanningView`.
/// No es dueño de su propio `List`/`NavigationStack`: sus filas se insertan
/// directamente en la `Section` del `List` que lo contiene.
struct RecurringExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<RecurringExpense> { !$0.isRemoved }, sort: \RecurringExpense.dayOfMonth) private var items: [RecurringExpense]
    @State private var showingAdd = false
    @State private var editingItem: RecurringExpense?

    private var reminderSignature: String {
        items.map { "\($0.name)|\($0.amount)|\($0.dayOfMonth)|\($0.isActive)" }.joined(separator: ";")
    }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyRow
            } else {
                ForEach(items) { item in
                    itemRow(item)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .swipeActions(edge: .leading) {
                            Button {
                                editingItem = item
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
                .onDelete(perform: deleteItems)
            }

            addRow
        }
        .task(id: reminderSignature) {
            NotificationManager.shared.scheduleRecurringReminders(items)
        }
        .sheet(isPresented: $showingAdd) {
            AddRecurringExpenseView()
        }
        .sheet(item: $editingItem) { item in
            AddRecurringExpenseView(itemToEdit: item)
        }
    }

    private var emptyRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sin gastos fijos")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.appTextPrimary)
            Text("Toca \"Nuevo gasto fijo\" para crear el primero.")
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
            Label("Nuevo gasto fijo", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.appAccent)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func dueText(_ item: RecurringExpense) -> String {
        let calendar = Calendar.current
        let today = calendar.component(.day, from: .now)
        let daysInMonth = calendar.range(of: .day, in: .month, for: .now)?.count ?? 30
        let day = min(item.dayOfMonth, daysInMonth)
        let diff = day - today
        if diff == 0 { return "Vence hoy" }
        if diff > 0 { return "Vence en \(diff) \(diff == 1 ? "día" : "días")" }
        return "Cobro el día \(item.dayOfMonth)"
    }

    @ViewBuilder
    private func itemRow(_ item: RecurringExpense) -> some View {
        HStack(spacing: 12) {
            CategoryIcon(name: item.category)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(item.isActive ? "\(item.category) · \(dueText(item))" : "Inactivo")
                }
                .font(.caption)
                .foregroundStyle(Color.appTextSecondary)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(item.type == .income ? "+" : "")\(CurrencyFormat.string(for: item.amount))")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(item.type == .income ? Color.appIncome : Color.appTextPrimary)
                Text("Mensual")
                    .font(.caption2)
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .floatingCardStyle()
        .opacity(item.isActive ? 1.0 : 0.5)
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = items[index]
            item.isRemoved = true
            item.updatedAt = .now
            item.needsSync = true
        }
    }
}

#Preview {
    NavigationStack {
        List {
            Section("Gastos fijos") {
                RecurringExpensesView()
            }
        }
    }
    .modelContainer(for: RecurringExpense.self, inMemory: true)
}
