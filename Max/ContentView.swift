import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Transaction> { !$0.isDeleted }, sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var showingAddView = false
    @State private var editingTransaction: Transaction?
    @State private var selectedType: TransactionType = .expense

    @State private var searchText = ""
    @State private var dateFilter: DateFilter = .all
    @State private var showingCustomRange = false
    @State private var customStart: Date = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var customEnd: Date = .now

    private enum DateFilter: Equatable {
        case all
        case thisMonth
        case last3Months
        case custom
    }

    private var totalIncome: Double {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var totalExpense: Double {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var balance: Double {
        totalIncome - totalExpense
    }

    private var currentMonthTransactions: [Transaction] {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: .now)
        let year = calendar.component(.year, from: .now)
        return transactions.filter {
            calendar.component(.month, from: $0.date) == month &&
            calendar.component(.year, from: $0.date) == year
        }
    }

    private func categoryBreakdown(for type: TransactionType) -> [(category: String, total: Double)] {
        let items = currentMonthTransactions.filter { $0.type == type }
        let grouped = Dictionary(grouping: items, by: { $0.category })
        return grouped
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
            .prefix(4)
            .map { $0 }
    }

    private func categoryEmoji(_ category: String) -> String {
        switch category.lowercased() {
        case "comida": return "🍔"
        case "transporte": return "🚗"
        case "vivienda": return "🏠"
        case "entretenimiento": return "🎮"
        case "salud": return "💊"
        case "compras": return "🛍️"
        case "suscripciones": return "🔁"
        case "salario": return "💰"
        case "freelance": return "💻"
        case "regalo": return "🎁"
        case "otros": return "🔖"
        default: return "🏷️"
        }
    }

    private var filteredTransactions: [Transaction] {
        var result = transactions
        let calendar = Calendar.current

        switch dateFilter {
        case .all:
            break
        case .thisMonth:
            let month = calendar.component(.month, from: .now)
            let year = calendar.component(.year, from: .now)
            result = result.filter {
                calendar.component(.month, from: $0.date) == month &&
                calendar.component(.year, from: $0.date) == year
            }
        case .last3Months:
            if let cutoff = calendar.date(byAdding: .month, value: -3, to: .now) {
                result = result.filter { $0.date >= cutoff }
            }
        case .custom:
            result = result.filter { $0.date >= customStart && $0.date <= customEnd }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.category.localizedCaseInsensitiveContains(searchText) ||
                $0.note.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    private var isFiltering: Bool {
        dateFilter != .all
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: Spacing.l) {
                        VStack(spacing: 4) {
                            Text("Total")
                                .font(.subheadline)
                                .foregroundStyle(Color.appTextSecondary)
                            Text(CurrencyFormat.string(for: balance))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(balance >= 0 ? Color.appIncome : Color.appExpense)
                        }

                        HStack(spacing: Spacing.s) {
                            typeSwitchPill(type: .expense, title: "Gastos", amount: totalExpense, color: .appExpense, icon: "minus.circle.fill")
                            typeSwitchPill(type: .income, title: "Ingresos", amount: totalIncome, color: .appIncome, icon: "plus.circle.fill")
                        }

                        VStack(alignment: .leading, spacing: Spacing.m) {
                            Text(selectedType == .income ? "Ingresos por categoría (este mes)" : "Gastos por categoría (este mes)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.appTextPrimary)

                            categoryBarChart()
                        }
                        .padding(Spacing.m)
                        .background(Color.appCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.s)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())

                Section {
                    if filteredTransactions.isEmpty {
                        Text(searchText.isEmpty ? "No hay movimientos en este rango." : "Sin resultados para \"\(searchText)\".")
                            .foregroundStyle(Color.appTextSecondary)
                    } else {
                        ForEach(filteredTransactions) { transaction in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill((transaction.type == .income ? Color.appIncome : Color.appExpense).opacity(0.15))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: transaction.type == .income ? "arrow.down" : "arrow.up")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(transaction.type == .income ? Color.appIncome : Color.appExpense)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(transaction.category)
                                        .font(.headline)
                                    Text(transaction.date, format: .dateTime.day().month().year())
                                        .font(.caption)
                                        .foregroundStyle(Color.appTextSecondary)
                                }
                                Spacer()
                                Text(CurrencyFormat.string(for: transaction.amount))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(transaction.type == .income ? Color.appIncome : Color.appExpense)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingTransaction = transaction
                            }
                        }
                        .onDelete(perform: deleteTransactions)
                    }
                } header: {
                    Text(isFiltering ? "Movimientos (filtrado)" : "Movimientos")
                }
                .listRowBackground(Color.appCardBackground)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar por categoría o nota")
            .navigationTitle("Resumen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.title2)
                            .foregroundStyle(Color.appAccent)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            dateFilter = .all
                        } label: {
                            HStack {
                                Text("Todos")
                                if dateFilter == .all { Image(systemName: "checkmark") }
                            }
                        }
                        Button {
                            dateFilter = .thisMonth
                        } label: {
                            HStack {
                                Text("Este mes")
                                if dateFilter == .thisMonth { Image(systemName: "checkmark") }
                            }
                        }
                        Button {
                            dateFilter = .last3Months
                        } label: {
                            HStack {
                                Text("Últimos 3 meses")
                                if dateFilter == .last3Months { Image(systemName: "checkmark") }
                            }
                        }
                        Button {
                            showingCustomRange = true
                        } label: {
                            HStack {
                                Text("Rango personalizado…")
                                if dateFilter == .custom { Image(systemName: "checkmark") }
                            }
                        }
                    } label: {
                        Image(systemName: isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundStyle(Color.appAccent)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddView = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .sheet(isPresented: $showingAddView) {
                AddTransactionView()
            }
            .sheet(item: $editingTransaction) { transaction in
                AddTransactionView(transactionToEdit: transaction)
            }
            .onChange(of: transactions) {
                WidgetDataStore.update(income: totalIncome, expense: totalExpense, balance: balance)
            }
            .onAppear {
                WidgetDataStore.update(income: totalIncome, expense: totalExpense, balance: balance)
            }
            .sheet(isPresented: $showingCustomRange) {
                NavigationStack {
                    Form {
                        DatePicker("Desde", selection: $customStart, displayedComponents: .date)
                        DatePicker("Hasta", selection: $customEnd, displayedComponents: .date)
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color.appBackground)
                    .tint(Color.appAccent)
                    .navigationTitle("Rango personalizado")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancelar") { showingCustomRange = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Aplicar") {
                                dateFilter = .custom
                                showingCustomRange = false
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    @ViewBuilder
    private func typeSwitchPill(type: TransactionType, title: String, amount: Double, color: Color, icon: String) -> some View {
        let isSelected = selectedType == type

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedType = type
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                    Text(CurrencyFormat.string(for: amount))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)
                }
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(isSelected ? 0.18 : 0.08))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                    .strokeBorder(color.opacity(isSelected ? 0.6 : 0), lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func categoryBarChart() -> some View {
        let items = categoryBreakdown(for: selectedType)
        let barColor: Color = selectedType == .income ? .appIncome : .appExpense

        if items.isEmpty {
            Text(selectedType == .income ? "Sin ingresos este mes." : "Sin gastos este mes.")
                .font(.footnote)
                .foregroundStyle(Color.appTextSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, Spacing.l)
        } else {
            let maxTotal = items.map(\.total).max() ?? 1

            HStack(alignment: .bottom, spacing: Spacing.m) {
                ForEach(items, id: \.category) { item in
                    VStack(spacing: Spacing.xs) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(barColor.opacity(0.85))
                            .frame(height: max(24, 100 * CGFloat(item.total / maxTotal)))

                        Text(categoryEmoji(item.category))
                            .font(.system(size: 18))

                        Text(item.category)
                            .font(.caption2)
                            .foregroundStyle(Color.appTextSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(CurrencyFormat.string(for: item.total, decimals: 0))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.appTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 170, alignment: .bottom)
        }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            let transaction = filteredTransactions[index]
            transaction.isDeleted = true
            transaction.updatedAt = .now
            transaction.needsSync = true
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
