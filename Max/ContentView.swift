import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Transaction> { !$0.isRemoved }, sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @Query(filter: #Predicate<Budget> { !$0.isRemoved }) private var budgets: [Budget]
    @Query(filter: #Predicate<Account> { !$0.isRemoved }, sort: \Account.name) private var accounts: [Account]
    @State private var accountFilter: Account?
    @State private var showingAddAccount = false
    @Query(filter: #Predicate<CardTransaction> { !$0.isRemoved }) private var cardTransactions: [CardTransaction]
    var onNavigate: (MainTabView.AppTab) -> Void = { _ in }
    @State private var showingAddView = false
    @State private var addType: TransactionType = .expense
    @State private var editingTransaction: Transaction?
    @AppStorage("hideBalance") private var hideBalance = false

    @State private var searchText = ""
    @State private var categoryFilter: String?
    @State private var typeFilter: TransactionType?
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
        totalIncome - totalExpense + accounts.reduce(0) { $0 + $1.initialBalance }
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

        if let accountFilter {
            result = result.filter { $0.account === accountFilter }
        }

        if let typeFilter {
            result = result.filter { $0.type == typeFilter }
        }

        if let categoryFilter {
            result = result.filter { $0.category == categoryFilter }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.category.localizedCaseInsensitiveContains(searchText) ||
                $0.note.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    private var extraFilterCount: Int {
        (typeFilter == nil ? 0 : 1) + (categoryFilter == nil ? 0 : 1)
    }

    private var isFiltering: Bool {
        dateFilter != .all || extraFilterCount > 0 || accountFilter != nil
    }

    private var availableCategories: [String] {
        Array(Set(transactions.map(\.category))).sorted()
    }

    // MARK: - Insight de ritmo de gasto

    private var spendingInsight: (title: String, message: String, icon: String, tint: Color)? {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: .now)
        guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: .now) else { return nil }
        let lm = calendar.component(.month, from: lastMonth)
        let ly = calendar.component(.year, from: lastMonth)

        let current = currentMonthTransactions
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
        let previous = transactions
            .filter {
                $0.type == .expense &&
                calendar.component(.month, from: $0.date) == lm &&
                calendar.component(.year, from: $0.date) == ly &&
                calendar.component(.day, from: $0.date) <= day
            }
            .reduce(0) { $0 + $1.amount }

        guard previous > 0, current > 0 else { return nil }
        let change = (current - previous) / previous
        let percent = Int((abs(change) * 100).rounded())
        guard percent >= 1 else {
            return ("Mismo ritmo que el mes pasado", "Tus gastos van casi iguales a esta altura del mes.", "equal.circle.fill", .appBlue)
        }
        if change < 0 {
            return ("Buen ritmo este mes", "Llevas \(percent)% menos gastos que el mes pasado a esta altura.", "sparkles", .appAccent)
        }
        return ("Ojo con el gasto", "Llevas \(percent)% más gastos que el mes pasado a esta altura.", "exclamationmark.triangle.fill", .appOrange)
    }

    @ViewBuilder
    private var insightCard: some View {
        if let insight = spendingInsight {
            HStack(spacing: 12) {
                Image(systemName: insight.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(insight.tint)
                    .frame(width: 40, height: 40)
                    .background(insight.tint.opacity(0.18), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.appTextPrimary)
                    Text(insight.message)
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(insight.tint.opacity(0.08)), in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        }
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

                Section {
                    quickActions
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Spacing.xs, leading: Spacing.l, bottom: Spacing.s, trailing: Spacing.l))

                Section {
                    accountsStrip
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: Spacing.s, trailing: 0))

                if spendingInsight != nil {
                    Section {
                        insightCard
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: Spacing.l, bottom: Spacing.s, trailing: Spacing.l))
                }

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
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color.appTextPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    filterMenu
                }
            }
            .sheet(isPresented: $showingAddView) {
                AddTransactionView(initialType: addType)
            }
            .sheet(item: $editingTransaction) { transaction in
                AddTransactionView(transactionToEdit: transaction)
            }
            .onChange(of: transactions) {
                WidgetDataStore.update(income: totalIncome, expense: totalExpense, balance: balance)
                updateBudgetWidgets()
            }
            .onChange(of: budgets) { updateBudgetWidgets() }
            .onChange(of: cardTransactions) { updateBudgetWidgets() }
            .onAppear {
                WidgetDataStore.update(income: totalIncome, expense: totalExpense, balance: balance)
                updateBudgetWidgets()
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

    // MARK: - Datos para los widgets de presupuesto

    private func updateBudgetWidgets() {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: .now)
        let year = calendar.component(.year, from: .now)
        let monthBudgets = budgets.filter { $0.month == month && $0.year == year }
        let total = monthBudgets.reduce(0) { $0 + $1.limitAmount }
        let categories = Set(monthBudgets.map(\.category))
        let spent = currentMonthTransactions
            .filter { $0.type == .expense && categories.contains($0.category) }
            .reduce(0) { $0 + $1.amount }

        let daysInMonth = calendar.range(of: .day, in: .month, for: .now)?.count ?? 30
        let daysLeft = max(1, daysInMonth - calendar.component(.day, from: .now) + 1)
        let allowance = max(0, total - spent) / Double(daysLeft)

        let cashToday = transactions
            .filter { $0.type == .expense && calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.amount }
        let cardToday = cardTransactions
            .filter { $0.type == .purchase && calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.amount }

        WidgetDataStore.updateBudget(total: total, spent: spent, spentToday: cashToday + cardToday, dailyAllowance: allowance)
        SpendingActivityManager.update(spentToday: cashToday + cardToday, dailyAllowance: allowance)
    }

    // MARK: - Cuentas

    @ViewBuilder
    private var accountsStrip: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text("Cuentas")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                NavigationLink {
                    AccountsView()
                } label: {
                    Text(accounts.isEmpty ? "Crear" : "Administrar")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.appAccent)
                }
            }
            .padding(.horizontal, Spacing.l)

            if accounts.isEmpty {
                Button {
                    showingAddAccount = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "building.columns.fill")
                            .foregroundStyle(Color.appBlue)
                        Text("Separa tu saldo por banco, ahorros y efectivo")
                            .font(.footnote)
                            .foregroundStyle(Color.appTextSecondary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "plus")
                            .foregroundStyle(Color.appAccent)
                    }
                    .padding(Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, Spacing.l)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.s) {
                        ForEach(accounts) { account in
                            accountCard(account)
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                }
            }
        }
        .sheet(isPresented: $showingAddAccount) { AddAccountView() }
    }

    private func accountCard(_ account: Account) -> some View {
        let selected = accountFilter === account
        let tint: Color = account.kind == .cash ? .appAccent : (account.kind == .bank ? .appBlue : .appPurple)
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                accountFilter = selected ? nil : account
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: account.kind.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(account.name)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)
                }
                Text(hideBalance ? "••••" : CurrencyFormat.string(for: account.balance, decimals: 0))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(account.balance >= 0 ? Color.appTextPrimary : Color.appExpense)
                    .lineLimit(1)
            }
            .padding(Spacing.m)
            .frame(width: 150, alignment: .leading)
            .glassEffect(.regular.tint(selected ? tint.opacity(0.25) : .clear).interactive(), in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                        .strokeBorder(tint.opacity(0.8), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Acciones rápidas

    private var quickActions: some View {
        HStack {
            quickAction(title: "Gasto", icon: "arrow.up.right", tint: .appExpense) {
                addType = .expense
                showingAddView = true
            }
            quickAction(title: "Ingreso", icon: "arrow.down.left", tint: .appIncome) {
                addType = .income
                showingAddView = true
            }
            quickAction(title: "Presupuesto", icon: "chart.pie.fill", tint: .appOrange) {
                onNavigate(.planificacion)
            }
            quickAction(title: "Análisis", icon: "chart.bar.fill", tint: .appBlue) {
                onNavigate(.analisis)
            }
        }
    }

    private func quickAction(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 56, height: 56)
                    .glassEffect(.regular.tint(tint.opacity(0.18)).interactive(), in: Circle())
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.appTextPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: showingAddView)
    }

    // MARK: - Filtro

    private var filterMenu: some View {
        Menu {
            Section("Periodo") {
                Button { dateFilter = .all } label: { Label("Todos", systemImage: dateFilter == .all ? "checkmark" : "") }
                Button { dateFilter = .thisMonth } label: { Label("Este mes", systemImage: dateFilter == .thisMonth ? "checkmark" : "") }
                Button { dateFilter = .last3Months } label: { Label("Últimos 3 meses", systemImage: dateFilter == .last3Months ? "checkmark" : "") }
                Button { showingCustomRange = true } label: { Label("Rango personalizado…", systemImage: dateFilter == .custom ? "checkmark" : "") }
            }

            Menu {
                Picker("Tipo", selection: $typeFilter) {
                    Text("Todos").tag(TransactionType?.none)
                    ForEach(TransactionType.allCases, id: \.self) { Text($0.rawValue).tag(TransactionType?.some($0)) }
                }
            } label: {
                Label("Tipo", systemImage: "arrow.up.arrow.down")
            }

            Menu {
                Picker("Categoría", selection: $categoryFilter) {
                    Text("Todas").tag(String?.none)
                    ForEach(availableCategories, id: \.self) { Text($0).tag(String?.some($0)) }
                }
            } label: {
                Label("Categoría", systemImage: "tag")
            }

            if isFiltering {
                Button(role: .destructive) {
                    dateFilter = .all
                    typeFilter = nil
                    categoryFilter = nil
                    accountFilter = nil
                } label: {
                    Label("Quitar filtros", systemImage: "xmark.circle")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.footnote)
                    .foregroundStyle(Color.appAccent)
                Text(extraFilterCount > 0 ? "\(filterTitle) · \(extraFilterCount)" : filterTitle)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.appTextPrimary)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.appTextSecondary)
            }

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
        transaction.isRemoved = true
        transaction.updatedAt = .now
        transaction.needsSync = true
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
