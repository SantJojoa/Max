import SwiftUI
import SwiftData

/// Contenido de la sección "Gastos fijos" dentro de `PlanningView`.
/// No es dueño de su propio `List`/`NavigationStack`: sus filas se insertan
/// directamente en la `Section` del `List` que lo contiene.
struct RecurringExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<RecurringExpense> { !$0.isDeleted }, sort: \RecurringExpense.dayOfMonth) private var items: [RecurringExpense]
    @State private var showingAdd = false
    @State private var editingItem: RecurringExpense?

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

    @ViewBuilder
    private func itemRow(_ item: RecurringExpense) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill((item.type == .income ? Color.appIncome : Color.appExpense).opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: item.type == .income ? "arrow.down.circle.fill" : "repeat.circle.fill")
                    .foregroundStyle(item.type == .income ? Color.appIncome : Color.appExpense)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)
                Text("\(item.category) · Día \(item.dayOfMonth)")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                if !item.isActive {
                    Text("Inactivo")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.appTextSecondary)
                }
            }

            Spacer()

            Text(CurrencyFormat.string(for: item.amount))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.type == .income ? Color.appIncome : Color.appExpense)
        }
        .floatingCardStyle()
        .opacity(item.isActive ? 1.0 : 0.5)
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = items[index]
            item.isDeleted = true
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
