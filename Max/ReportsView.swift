import SwiftUI
import SwiftData

struct ReportsView: View {
    @Query private var transactions: [Transaction]
    @Query private var cards: [CreditCard]

    private enum PeriodMode: String, CaseIterable {
        case year = "Año completo"
        case month = "Mes específico"
    }

    private enum DataMode: String, CaseIterable {
        case cash = "Efectivo"
        case card = "Tarjetas"
    }

    @State private var mode: PeriodMode = .year
    @State private var dataMode: DataMode = .cash
    @State private var selectedYear: Int = Calendar.current.component(.year, from: .now)
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: .now)

    private let calendar = Calendar.current

    private var availableYears: [Int] {
        let currentYear = calendar.component(.year, from: .now)
        return Array((currentYear - 4)...currentYear).reversed()
    }

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_CO")
        return formatter.monthSymbols[month - 1].capitalized
    }

    private func shortMonthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_CO")
        return formatter.shortMonthSymbols[month - 1].capitalized
    }

    private var periodMonth: Int? {
        mode == .month ? selectedMonth : nil
    }

    private func cashTransactions(year: Int, month: Int?) -> [Transaction] {
        transactions.filter { transaction in
            let tYear = calendar.component(.year, from: transaction.date)
            guard tYear == year else { return false }
            if let month {
                return calendar.component(.month, from: transaction.date) == month
            }
            return true
        }
    }

    private func cardTransactionsInPeriod(year: Int, month: Int?) -> [CardTransaction] {
        cards.flatMap { $0.transactions }.filter { transaction in
            let tYear = calendar.component(.year, from: transaction.date)
            guard tYear == year else { return false }
            if let month {
                return calendar.component(.month, from: transaction.date) == month
            }
            return true
        }
    }

    private var cashIncome: Double {
        cashTransactions(year: selectedYear, month: periodMonth)
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    private var cashExpense: Double {
        cashTransactions(year: selectedYear, month: periodMonth)
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    private var cashBalance: Double {
        cashIncome - cashExpense
    }

    private var savingsPercentage: Double {
        guard cashIncome > 0 else { return 0 }
        return (cashBalance / cashIncome) * 100
    }

    private var cardPurchases: Double {
        cardTransactionsInPeriod(year: selectedYear, month: periodMonth)
            .filter { $0.type == .purchase }
            .reduce(0) { $0 + $1.amount }
    }

    private var cardPayments: Double {
        cardTransactionsInPeriod(year: selectedYear, month: periodMonth)
            .filter { $0.type == .payment }
            .reduce(0) { $0 + $1.amount }
    }

    private var cardNet: Double {
        cardPurchases - cardPayments
    }

    // MARK: - Datos para la tabla mensual

    private func monthlyCash(month: Int) -> (income: Double, expense: Double) {
        let items = cashTransactions(year: selectedYear, month: month)
        let income = items.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
        let expense = items.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
        return (income, expense)
    }

    private func monthlyCard(month: Int) -> (purchases: Double, payments: Double) {
        let items = cardTransactionsInPeriod(year: selectedYear, month: month)
        let purchases = items.filter { $0.type == .purchase }.reduce(0) { $0 + $1.amount }
        let payments = items.filter { $0.type == .payment }.reduce(0) { $0 + $1.amount }
        return (purchases, payments)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Periodo", selection: $mode) {
                        ForEach(PeriodMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Año", selection: $selectedYear) {
                        ForEach(availableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }

                    if mode == .month {
                        Picker("Mes", selection: $selectedMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(monthName(month)).tag(month)
                            }
                        }
                    }
                }

                Section {
                    Picker("Datos", selection: $dataMode) {
                        ForEach(DataMode.allCases, id: \.self) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if dataMode == .cash {
                    Section("Efectivo") {
                        HStack {
                            Text("Ingresos")
                            Spacer()
                            Text(cashIncome, format: .currency(code: "COP"))
                                .foregroundStyle(.green)
                        }
                        HStack {
                            Text("Gastos")
                            Spacer()
                            Text(cashExpense, format: .currency(code: "COP"))
                                .foregroundStyle(.red)
                        }
                        HStack {
                            Text("Balance")
                                .font(.headline)
                            Spacer()
                            Text(cashBalance, format: .currency(code: "COP"))
                                .font(.headline)
                                .foregroundStyle(cashBalance >= 0 ? .green : .red)
                        }
                        HStack {
                            Text("% Ahorrado")
                            Spacer()
                            Text(savingsPercentage, format: .number.precision(.fractionLength(1)))
                                + Text("%")
                        }
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Tarjetas de crédito") {
                        HStack {
                            Text("Compras")
                            Spacer()
                            Text(cardPurchases, format: .currency(code: "COP"))
                                .foregroundStyle(.red)
                        }
                        HStack {
                            Text("Pagos")
                            Spacer()
                            Text(cardPayments, format: .currency(code: "COP"))
                                .foregroundStyle(.green)
                        }
                        HStack {
                            Text("Neto del periodo")
                                .font(.headline)
                            Spacer()
                            Text(cardNet, format: .currency(code: "COP"))
                                .font(.headline)
                                .foregroundStyle(cardNet <= 0 ? .green : .red)
                        }
                    }
                }

                Section("Detalle mes a mes — \(String(selectedYear))") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        if dataMode == .cash {
                            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                                GridRow {
                                    Text("Mes").bold()
                                    Text("Ingresos").bold()
                                    Text("Gastos").bold()
                                    Text("Balance").bold()
                                    Text("% Ahorro").bold()
                                }
                                .font(.caption)

                                Divider().gridCellColumns(5)

                                ForEach(1...12, id: \.self) { month in
                                    let data = monthlyCash(month: month)
                                    let balance = data.income - data.expense
                                    let savings = data.income > 0 ? (balance / data.income) * 100 : 0

                                    GridRow {
                                        Text(shortMonthName(month))
                                        Text(data.income, format: .currency(code: "COP").precision(.fractionLength(0)))
                                        Text(data.expense, format: .currency(code: "COP").precision(.fractionLength(0)))
                                        Text(balance, format: .currency(code: "COP").precision(.fractionLength(0)))
                                            .foregroundStyle(balance >= 0 ? .green : .red)
                                        Text(savings, format: .number.precision(.fractionLength(0))) + Text("%")
                                    }
                                    .font(.caption2)
                                }
                            }
                        } else {
                            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                                GridRow {
                                    Text("Mes").bold()
                                    Text("Compras").bold()
                                    Text("Pagos").bold()
                                    Text("Neto").bold()
                                }
                                .font(.caption)

                                Divider().gridCellColumns(4)

                                ForEach(1...12, id: \.self) { month in
                                    let data = monthlyCard(month: month)
                                    let net = data.purchases - data.payments

                                    GridRow {
                                        Text(shortMonthName(month))
                                        Text(data.purchases, format: .currency(code: "COP").precision(.fractionLength(0)))
                                        Text(data.payments, format: .currency(code: "COP").precision(.fractionLength(0)))
                                        Text(net, format: .currency(code: "COP").precision(.fractionLength(0)))
                                            .foregroundStyle(net <= 0 ? .green : .red)
                                    }
                                    .font(.caption2)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reportes")
        }
    }
}

#Preview {
    ReportsView()
        .modelContainer(for: [Transaction.self, CreditCard.self, CardTransaction.self], inMemory: true)
}
