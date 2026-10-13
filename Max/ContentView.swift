import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Transaction> { !$0.isDeleted }, sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var showingAddView = false
    @State private var editingTransaction: Transaction?
    @AppStorage("hideBalance") private var hideBalance = false

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

    private var filterTitle: String {
        switch dateFilter {
        case .all: return "Todo"
        case .thisMonth: return "Este mes"
        case .last3Months: return "3 meses"
        case .custom: return "Personalizado"
        }
    }

    private var monthIncome: Double {
        currentMonthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    private var monthExpense: Double {
        currentMonthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    private var groupedTransactions: [(day: Date, items: [Transaction])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredTransactions) { calendar.startOfDay(for: $0.date) }
        return groups
            .map { (day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Hoy" }
        if calendar.isDateInYesterday(day) { return "Ayer" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    heroCard
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Spacing.s, leading: Spacing.l, bottom: Spacing.s, trailing: Spacing.l))

                if filteredTransactions.isEmpty {
                    Section {
                        ContentUnavailableView(
                            searchText.isEmpty ? "Sin movimientos todavía" : "Sin resultados",
                            systemImage: searchText.isEmpty ? "tray" : "magnifyingglass",
                            description: Text(searchText.isEmpty ? "Toca + para registrar tu primer movimiento." : "Nada coincide con \"\(searchText)\".")
                        )
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(groupedTransactions, id: \.day) { group in
                        Section {
                            ForEach(group.items) { transaction in
                                transactionRow(transaction)
                                    .listRowBackground(Rectangle().fill(.ultraThinMaterial).overlay(Color.white.opacity(0.03)))
                                    .listRowSeparatorTint(Color.appHairline)
                                    .listRowInsets(EdgeInsets(top: 0, leading: Spacing.l, bottom: 0, trailing: Spacing.l))
                            }
                            .onDelete { offsets in
                                for index in offsets { delete(group.items[index]) }
                            }
                        } header: {
                            Text(dayTitle(group.day))
                                .font(.footnote.weight(.semibold))
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .foregroundStyle(Color.appTextSecondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Buscar por categoría o nota")
            .navigationTitle("Resumen")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    filterMenu
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
                    .background { AppBackground() }
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

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            HStack {
                Text("Balance total")
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(Color.appTextSecondary)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { hideBalance.toggle() }
                } label: {
                    Image(systemName: hideBalance ? "eye.slash" : "eye")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
            }

            Text(hideBalance ? "••••••" : CurrencyFormat.string(for: balance))
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(LinearGradient(colors: [Color.appTextPrimary, Color.appTextPrimary.opacity(0.75)], startPoint: .top, endPoint: .bottom))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText())

            HStack(spacing: Spacing.s) {
                statPill(title: "Ingresos del mes", amount: monthIncome, color: .appIncome, icon: "arrow.down.left")
                statPill(title: "Gastos del mes", amount: monthExpense, color: .appExpense, icon: "arrow.up.right")
            }
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Color.appBlue.opacity(0.10)), in: RoundedRectangle(cornerRadius: Radius.xlarge, style: .continuous))
    }

    private func statPill(title: String, amount: Double, color: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(color)
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
                Text(hideBalance ? "••••" : CurrencyFormat.string(for: amount))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }

    // MARK: - Filtro

    private var filterMenu: some View {
        Menu {
            Button { dateFilter = .all } label: { Label("Todos", systemImage: dateFilter == .all ? "checkmark" : "") }
            Button { dateFilter = .thisMonth } label: { Label("Este mes", systemImage: dateFilter == .thisMonth ? "checkmark" : "") }
            Button { dateFilter = .last3Months } label: { Label("Últimos 3 meses", systemImage: dateFilter == .last3Months ? "checkmark" : "") }
            Button { showingCustomRange = true } label: { Label("Rango personalizado…", systemImage: dateFilter == .custom ? "checkmark" : "") }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.footnote)
                    .foregroundStyle(Color.appAccent)
                Text(filterTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .glassEffect(.regular.interactive(), in: Capsule())
        }
    }

    // MARK: - Fila

    private func transactionRow(_ transaction: Transaction) -> some View {
        Button {
            editingTransaction = transaction
        } label: {
            HStack(spacing: 12) {
                CategoryIcon(name: transaction.category)

                VStack(alignment: .leading, spacing: 2) {
                    Text(transaction.note.isEmpty ? transaction.category : transaction.note)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)
                    Text("\(transaction.category) · \(transaction.date.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text("\(transaction.type == .income ? "+" : "-")\(CurrencyFormat.string(for: transaction.amount))")
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(transaction.type == .income ? Color.appIncome : Color.appTextPrimary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func delete(_ transaction: Transaction) {
        transaction.isDeleted = true
        transaction.updatedAt = .now
        transaction.needsSync = true
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
