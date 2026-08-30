import SwiftUI
import SwiftData
import Charts

struct ChartsView: View {
    @Query private var transactions: [Transaction]
    @Query private var cards: [CreditCard]

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
        let purchases = card.transactions.filter { $0.type == .purchase }.reduce(0) { $0 + $1.amount }
        let payments = card.transactions.filter { $0.type == .payment }.reduce(0) { $0 + $1.amount }
        return purchases - payments
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
            $0.type == .purchase && calendar.component(.year, from: $0.date) == currentYear
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading) {
                        Text("Gastos por categoría (este mes)")
                            .font(.headline)
                            .padding(.horizontal)

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
                            .padding(.horizontal)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Ingresos vs. Gastos (últimos 6 meses)")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart(last6MonthsTotals) { item in
                            BarMark(
                                x: .value("Mes", item.monthLabel),
                                y: .value("Total", item.total)
                            )
                            .foregroundStyle(by: .value("Tipo", item.type.rawValue))
                            .position(by: .value("Tipo", item.type.rawValue))
                        }
                        .frame(height: 220)
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading) {
                        Text("Gastos con tarjeta por categoría (este mes)")
                            .font(.headline)
                            .padding(.horizontal)

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
                            .padding(.horizontal)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Uso de cupo por tarjeta")
                            .font(.headline)
                            .padding(.horizontal)

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
                                            (Text(used, format: .currency(code: "COP"))
                                                + Text(" / ")
                                                + Text(card.creditLimit, format: .currency(code: "COP")))
                                        }
                                        .font(.caption)

                                        ProgressView(value: ratio)
                                            .tint(ratio >= 0.9 ? .red : .blue)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Tendencia de balance mensual (\(String(currentYear)))")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart(monthlyBalanceTrend) { item in
                            LineMark(
                                x: .value("Mes", item.monthLabel),
                                y: .value("Balance", item.value)
                            )
                            .interpolationMethod(.catmullRom)
                            PointMark(
                                x: .value("Mes", item.monthLabel),
                                y: .value("Balance", item.value)
                            )
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading) {
                        Text("Top 5 categorías de gasto (\(String(currentYear)))")
                            .font(.headline)
                            .padding(.horizontal)

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
                            .padding(.horizontal)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Tendencia de ahorro mensual % (\(String(currentYear)))")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart(monthlySavingsTrend) { item in
                            LineMark(
                                x: .value("Mes", item.monthLabel),
                                y: .value("% Ahorro", item.value)
                            )
                            .interpolationMethod(.catmullRom)
                            PointMark(
                                x: .value("Mes", item.monthLabel),
                                y: .value("% Ahorro", item.value)
                            )
                        }
                        .frame(height: 200)
                        .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Resumen del año \(String(currentYear))")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 8) {
                            HStack {
                                Text("Ingresos")
                                Spacer()
                                Text(yearIncome, format: .currency(code: "COP"))
                                    .foregroundStyle(.green)
                            }
                            HStack {
                                Text("Gastos")
                                Spacer()
                                Text(yearExpense, format: .currency(code: "COP"))
                                    .foregroundStyle(.red)
                            }
                            HStack {
                                Text("Balance")
                                    .font(.headline)
                                Spacer()
                                Text(yearBalance, format: .currency(code: "COP"))
                                    .font(.headline)
                                    .foregroundStyle(yearBalance >= 0 ? .green : .red)
                            }
                            HStack {
                                Text("% Ahorro")
                                Spacer()
                                (Text(yearSavingsPercentage, format: .number.precision(.fractionLength(1))) + Text("%"))
                            }
                            .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Gráficas")
        }
    }
}

#Preview {
    ChartsView()
        .modelContainer(for: [Transaction.self, CreditCard.self, CardTransaction.self], inMemory: true)
}
