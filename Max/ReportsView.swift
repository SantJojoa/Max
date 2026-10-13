import SwiftUI
import SwiftData

struct ReportsView: View {
    @Query(filter: #Predicate<Transaction> { !$0.isDeleted }) private var transactions: [Transaction]
    @Query(filter: #Predicate<CreditCard> { !$0.isDeleted }) private var cards: [CreditCard]
    
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
    @State private var shareItem: ShareItem?
    @State private var exportError: String?
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
            guard !transaction.isDeleted else { return false }
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

    // MARK: - UI

    private var heroIncome: Double { dataMode == .cash ? cashIncome : cardPayments }
    private var heroExpense: Double { dataMode == .cash ? cashExpense : cardPurchases }
    private var heroNet: Double { dataMode == .cash ? cashBalance : -cardNet }

    private var periodTitle: String {
        mode == .year ? String(selectedYear) : "\(monthName(selectedMonth)) \(String(selectedYear))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                filters
                heroCard
                monthlyTable
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
            
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .tint(Color.appAccent)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                sourceMenu
            }
            ToolbarItem(placement: .topBarTrailing) {
                exportMenu
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(url: item.url)
                .presentationDetents([.medium, .large])
        }
        .alert("No se pudo exportar", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    // MARK: - Fuente (Efectivo / Tarjetas) y exportación

    private var sourceMenu: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                dataMode = dataMode == .cash ? .card : .cash
            }
        } label: {
            Image(systemName: dataMode == .cash ? "banknote" : "creditcard")
                .contentTransition(.symbolEffect(.replace))
        }
        .sensoryFeedback(.selection, trigger: dataMode)
        .accessibilityLabel(dataMode == .cash ? "Mostrando efectivo. Cambiar a tarjetas" : "Mostrando tarjetas. Cambiar a efectivo")
    }

    private var exportMenu: some View {
        Menu {
            Button {
                export(.pdf)
            } label: {
                Label("Exportar PDF", systemImage: "doc.richtext")
            }
            Button {
                export(.csv)
            } label: {
                Label("Exportar CSV", systemImage: "tablecells")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel("Exportar reporte")
    }

    private enum ExportFormat { case pdf, csv }

    private func snapshot() -> ReportSnapshot {
        var rows: [ReportRow] = cashTransactions(year: selectedYear, month: periodMonth).map {
            ReportRow(date: $0.date, kind: $0.type.rawValue, source: "Efectivo", category: $0.category, note: $0.note,
                      amount: $0.amount, isPositive: $0.type == .income)
        }
        rows += cardTransactionsInPeriod(year: selectedYear, month: periodMonth).map {
            ReportRow(date: $0.date, kind: $0.type.rawValue, source: $0.card?.name ?? "Tarjeta", category: $0.category, note: $0.note,
                      amount: $0.amount, isPositive: $0.type == .payment)
        }
        return ReportSnapshot(periodTitle: periodTitle, rows: rows)
    }

    private func export(_ format: ExportFormat) {
        do {
            let snap = snapshot()
            let url = format == .pdf ? try ReportExporter.pdf(for: snap) : try ReportExporter.csv(for: snap)
            shareItem = ShareItem(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private var filters: some View {
        VStack(spacing: Spacing.s) {
            HStack(spacing: Spacing.s) {
                Menu {
                    Picker("Periodo", selection: $mode) {
                        ForEach(PeriodMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    filterChip(icon: "calendar", text: mode.rawValue)
                }

                Menu {
                    Picker("Año", selection: $selectedYear) {
                        ForEach(availableYears, id: \.self) { Text(String($0)).tag($0) }
                    }
                } label: {
                    filterChip(icon: "clock.arrow.circlepath", text: String(selectedYear))
                }

                if mode == .month {
                    Menu {
                        Picker("Mes", selection: $selectedMonth) {
                            ForEach(1...12, id: \.self) { Text(monthName($0)).tag($0) }
                        }
                    } label: {
                        filterChip(icon: "calendar.badge.clock", text: monthName(selectedMonth))
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func filterChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(Color.appAccent)
            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.appTextPrimary)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dataMode == .cash ? "Balance · \(periodTitle)" : "Neto tarjetas · \(periodTitle)")
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(Color.appTextSecondary)
                Text(CurrencyFormat.string(for: dataMode == .cash ? cashBalance : cardNet))
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(dataMode == .cash
                                     ? (cashBalance >= 0 ? Color.appIncome : Color.appExpense)
                                     : (cardNet <= 0 ? Color.appIncome : Color.appExpense))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            HStack(spacing: Spacing.s) {
                statTile(title: dataMode == .cash ? "Ingresos" : "Pagos", value: CurrencyFormat.string(for: heroIncome), color: .appIncome, icon: "arrow.down.left")
                statTile(title: dataMode == .cash ? "Gastos" : "Compras", value: CurrencyFormat.string(for: heroExpense), color: .appExpense, icon: "arrow.up.right")
            }

            if dataMode == .cash {
                VStack(spacing: 6) {
                    HStack {
                        Text("Ahorrado")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.appTextSecondary)
                        Spacer()
                        Text("\(savingsPercentage.formatted(.number.precision(.fractionLength(1))))%")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(Color.appTextPrimary)
                    }
                    CapsuleProgress(value: max(savingsPercentage, 0) / 100, tint: .appAccent, height: 8)
                }
            }
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Color.appBlue.opacity(0.10)), in: RoundedRectangle(cornerRadius: Radius.xlarge, style: .continuous))
    }

    private func statTile(title: String, value: String, color: Color, icon: String) -> some View {
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
                Text(value)
                    .font(.subheadline.weight(.bold))
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

    private var monthlyTable: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("Detalle mes a mes · \(String(selectedYear))")
                .font(.headline)
                .foregroundStyle(Color.appTextPrimary)

            VStack(spacing: 0) {
                ForEach(1...12, id: \.self) { month in
                    monthRow(month)
                    if month < 12 { Divider().overlay(Color.appHairline) }
                }
            }
        }
        .padding(Spacing.l)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    @ViewBuilder
    private func monthRow(_ month: Int) -> some View {
        let isCash = dataMode == .cash
        let cash = monthlyCash(month: month)
        let card = monthlyCard(month: month)
        let first = isCash ? cash.income : card.purchases
        let second = isCash ? cash.expense : card.payments
        let net = isCash ? cash.income - cash.expense : card.payments - card.purchases
        let empty = first == 0 && second == 0

        HStack {
            Text(shortMonthName(month))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(empty ? Color.appTextSecondary : Color.appTextPrimary)
                .frame(width: 44, alignment: .leading)
            Spacer()
            if empty {
                Text("—")
                    .foregroundStyle(Color.appTextSecondary)
            } else {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(net >= 0 ? "+" : "-")\(CurrencyFormat.string(for: abs(net), decimals: 0))")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(net >= 0 ? Color.appIncome : Color.appExpense)
                    Text("\(CurrencyFormat.string(for: first, decimals: 0)) · \(CurrencyFormat.string(for: second, decimals: 0))")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    NavigationStack {
        ReportsView()
            .navigationTitle("Reportes")
    }
    .modelContainer(for: [Transaction.self, CreditCard.self, CardTransaction.self], inMemory: true)
}
