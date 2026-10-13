import SwiftUI
import SwiftData
import Charts

struct ChartsView: View {
    @Query(filter: #Predicate<Transaction> { !$0.isDeleted }) private var transactions: [Transaction]
    @Query(filter: #Predicate<CreditCard> { !$0.isDeleted }) private var cards: [CreditCard]
    
    private let calendar = Calendar.current

    private var currentMonth: Int { calendar.component(.month, from: .now) }
    private var currentYear: Int { calendar.component(.year, from: .now) }

    private func shortMonthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_CO")
        return formatter.shortMonthSymbols[month - 1].capitalized
    }

    private struct CategoryTotal: Identifiable {
        let id = UUID()
        let category: String
        let total: Double
    }

    private var expensesByCategory: [CategoryTotal] {
        let expenses = transactions.filter {
            $0.type == .expense &&
            calendar.component(.month, from: $0.date) == currentMonth &&
            calendar.component(.year, from: $0.date) == currentYear
        }
        let grouped = Dictionary(grouping: expenses, by: { $0.category })
        return grouped
            .map { CategoryTotal(category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    private var cardExpensesByCategory: [CategoryTotal] {
        let purchases = cards
            .flatMap { $0.transactions }
            .filter {
                !$0.isDeleted &&
                $0.type == .purchase &&
                calendar.component(.month, from: $0.date) == currentMonth &&
                calendar.component(.year, from: $0.date) == currentYear
            }
        let grouped = Dictionary(grouping: purchases, by: { $0.category })
        return grouped
            .map { CategoryTotal(category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    private struct MonthTotal: Identifiable {
        let id = UUID()
        let monthLabel: String
        let type: TransactionType
        let total: Double
    }

    private var last6MonthsTotals: [MonthTotal] {
        var result: [MonthTotal] = []

        for offset in stride(from: 5, through: 0, by: -1) {
            guard let monthDate = calendar.date(byAdding: .month, value: -offset, to: .now) else { continue }
            let month = calendar.component(.month, from: monthDate)
            let year = calendar.component(.year, from: monthDate)

            let monthTransactions = transactions.filter {
                calendar.component(.month, from: $0.date) == month &&
                calendar.component(.year, from: $0.date) == year
            }

            let income = monthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
            let expense = monthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
            let label = shortMonthName(month)

            result.append(MonthTotal(monthLabel: label, type: .income, total: income))
            result.append(MonthTotal(monthLabel: label, type: .expense, total: expense))
        }
        return result
    }

    private func usedCupo(for card: CreditCard) -> Double {
        let activeTransactions = card.transactions.filter { !$0.isDeleted }
        let purchases = activeTransactions.filter { $0.type == .purchase }.reduce(0) { $0 + $1.amount }
        let payments = activeTransactions.filter { $0.type == .payment }.reduce(0) { $0 + $1.amount }
        return purchases - payments
    }

    private func cupoProgressColor(_ ratio: Double) -> Color {
        if ratio >= 0.9 { return .appExpense }
        if ratio >= 0.7 { return .orange }
        return .appAccent
    }

    // MARK: - Nuevas gráficas

    private struct MonthValue: Identifiable {
        let id = UUID()
        let monthLabel: String
        let value: Double
    }

    private func cashTotals(month: Int, year: Int) -> (income: Double, expense: Double) {
        let items = transactions.filter {
            calendar.component(.month, from: $0.date) == month &&
            calendar.component(.year, from: $0.date) == year
        }
        let income = items.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expense = items.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        return (income, expense)
    }

    private var monthlyBalanceTrend: [MonthValue] {
        (1...12).map { month in
            let totals = cashTotals(month: month, year: currentYear)
            return MonthValue(monthLabel: shortMonthName(month), value: totals.income - totals.expense)
        }
    }

    private var monthlySavingsTrend: [MonthValue] {
        (1...12).map { month in
            let totals = cashTotals(month: month, year: currentYear)
            let savings = totals.income > 0 ? ((totals.income - totals.expense) / totals.income) * 100 : 0
            return MonthValue(monthLabel: shortMonthName(month), value: savings)
        }
    }

    private var topCategories: [CategoryTotal] {
        let cashExpenses = transactions.filter {
            $0.type == .expense && calendar.component(.year, from: $0.date) == currentYear
        }
        let cardPurchases = cards.flatMap { $0.transactions }.filter {
            !$0.isDeleted && $0.type == .purchase && calendar.component(.year, from: $0.date) == currentYear
        }

        var totals: [String: Double] = [:]
        for t in cashExpenses { totals[t.category, default: 0] += t.amount }
        for t in cardPurchases { totals[t.category, default: 0] += t.amount }

        return totals
            .map { CategoryTotal(category: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
            .prefix(5)
            .map { $0 }
    }

    private var yearIncome: Double {
        transactions.filter {
            $0.type == .income && calendar.component(.year, from: $0.date) == currentYear
        }.reduce(0) { $0 + $1.amount }
    }

    private var yearExpense: Double {
        transactions.filter {
            $0.type == .expense && calendar.component(.year, from: $0.date) == currentYear
        }.reduce(0) { $0 + $1.amount }
    }

    private var yearBalance: Double { yearIncome - yearExpense }

    private var yearSavingsPercentage: Double {
        guard yearIncome > 0 else { return 0 }
        return (yearBalance / yearIncome) * 100
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                chartCard(title: "Gastos por categoría (este mes)") {
                    if expensesByCategory.isEmpty {
                        ContentUnavailableView(
                            "Sin gastos este mes",
                            systemImage: "chart.pie",
                            description: Text("Agrega gastos para ver el desglose aquí.")
                        )
                        .frame(height: 200)
                    } else {
                        Chart(expensesByCategory) { item in
                            SectorMark(
                                angle: .value("Total", item.total),
                                innerRadius: .ratio(0.6),
                                angularInset: 1.5
                            )
                            .foregroundStyle(by: .value("Categoría", item.category))
                            .cornerRadius(4)
                        }
                        .frame(height: 260)
                    }
                }

                chartCard(title: "Ingresos vs. Gastos (últimos 6 meses)") {
                    Chart(last6MonthsTotals) { item in
                        BarMark(
                            x: .value("Mes", item.monthLabel),
                            y: .value("Total", item.total)
                        )
                        .foregroundStyle(by: .value("Tipo", item.type.rawValue))
                        .position(by: .value("Tipo", item.type.rawValue))
                    }
                    .frame(height: 220)
                }

                chartCard(title: "Gastos con tarjeta por categoría (este mes)") {
                    if cardExpensesByCategory.isEmpty {
                        ContentUnavailableView(
                            "Sin compras con tarjeta este mes",
                            systemImage: "creditcard",
                            description: Text("Registra compras en tus tarjetas para ver el desglose aquí.")
                        )
                        .frame(height: 200)
                    } else {
                        Chart(cardExpensesByCategory) { item in
                            SectorMark(
                                angle: .value("Total", item.total),
                                innerRadius: .ratio(0.6),
                                angularInset: 1.5
                            )
                            .foregroundStyle(by: .value("Categoría", item.category))
                            .cornerRadius(4)
                        }
                        .frame(height: 260)
                    }
                }

                chartCard(title: "Uso de cupo por tarjeta") {
                    if cards.isEmpty {
                        ContentUnavailableView(
                            "Sin tarjetas",
                            systemImage: "creditcard",
                            description: Text("Agrega una tarjeta para ver su uso de cupo aquí.")
                        )
                        .frame(height: 150)
                    } else {
                        VStack(spacing: 16) {
                            ForEach(cards) { card in
                                let used = usedCupo(for: card)
                                let ratio = card.creditLimit > 0 ? min(max(used / card.creditLimit, 0), 1) : 0

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(card.name)
                                            .font(.subheadline)
                                        Spacer()
                                        Text("\(CurrencyFormat.string(for: used)) / \(CurrencyFormat.string(for: card.creditLimit))")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(Color.appTextSecondary)

                                    ProgressView(value: ratio)
                                        .tint(cupoProgressColor(ratio))
                                }
                            }
                        }
                    }
                }

                chartCard(title: "Tendencia de balance mensual (\(String(currentYear)))") {
                    Chart(monthlyBalanceTrend) { item in
                        LineMark(
                            x: .value("Mes", item.monthLabel),
                            y: .value("Balance", item.value)
                        )
                        .foregroundStyle(Color.appAccent)
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("Mes", item.monthLabel),
                            y: .value("Balance", item.value)
                        )
                        .foregroundStyle(Color.appAccent)
                    }
                    .frame(height: 200)
                }

                chartCard(title: "Top 5 categorías de gasto (\(String(currentYear)))") {
                    if topCategories.isEmpty {
                        ContentUnavailableView(
                            "Sin datos todavía",
                            systemImage: "list.number",
                            description: Text("Agrega gastos o compras con tarjeta para ver el ranking aquí.")
                        )
                        .frame(height: 150)
                    } else {
                        Chart(topCategories) { item in
                            BarMark(
                                x: .value("Total", item.total),
                                y: .value("Categoría", item.category)
                            )
                            .foregroundStyle(by: .value("Categoría", item.category))
                        }
                        .frame(height: CGFloat(topCategories.count * 40 + 20))
                    }
                }

                chartCard(title: "Tendencia de ahorro mensual % (\(String(currentYear)))") {
                    Chart(monthlySavingsTrend) { item in
                        LineMark(
                            x: .value("Mes", item.monthLabel),
                            y: .value("% Ahorro", item.value)
                        )
                        .foregroundStyle(Color.appAccent)
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("Mes", item.monthLabel),
                            y: .value("% Ahorro", item.value)
                        )
                        .foregroundStyle(Color.appAccent)
                    }
                    .frame(height: 200)
                }

                chartCard(title: "Resumen del año \(String(currentYear))") {
                    VStack(spacing: 10) {
                        HStack {
                            Text("Ingresos")
                            Spacer()
                            Text(CurrencyFormat.string(for: yearIncome))
                                .foregroundStyle(Color.appIncome)
                        }
                        HStack {
                            Text("Gastos")
                            Spacer()
                            Text(CurrencyFormat.string(for: yearExpense))
                                .foregroundStyle(Color.appExpense)
                        }
                        HStack {
                            Text("Balance")
                                .font(.headline)
                            Spacer()
                            Text(CurrencyFormat.string(for: yearBalance))
                                .font(.headline)
                                .foregroundStyle(yearBalance >= 0 ? Color.appIncome : Color.appExpense)
                        }
                        HStack {
                            Text("% Ahorro")
                            Spacer()
                            (Text(yearSavingsPercentage, format: .number.precision(.fractionLength(1))) + Text("%"))
                        }
                        .foregroundStyle(Color.appTextSecondary)
                    }
                }
            }
            .padding(.vertical)
            .padding(.horizontal)
        }
        .background(Color.appBackground)
    }

    @ViewBuilder
    private func chartCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .floatingCardStyle()
    }
}

#Preview {
    NavigationStack {
        ChartsView()
            .navigationTitle("Gráficas")
    }
    .modelContainer(for: [Transaction.self, CreditCard.self, CardTransaction.self], inMemory: true)
}
