import SwiftUI
import SwiftData

/// Historial de compras con tarjeta de crédito: cuántas, cuánto, en cuántas cuotas, etc.
struct CardPurchasesView: View {
    var onlyCard: CreditCard?

    @Query(filter: #Predicate<CardTransaction> { !$0.isRemoved }, sort: \CardTransaction.date, order: .reverse) private var allTransactions: [CardTransaction]
    @Query(filter: #Predicate<CreditCard> { !$0.isRemoved }, sort: \CreditCard.name) private var cards: [CreditCard]

    private enum Period: String, CaseIterable {
        case month = "Mes", threeMonths = "3 meses", year = "Año", all = "Todo"
    }

    @State private var period: Period = .all
    @State private var cardFilter: CreditCard?
    @State private var onlyInstallments = false

    private var purchases: [CardTransaction] {
        let calendar = Calendar.current
        return allTransactions.filter { transaction in
            guard transaction.type == .purchase else { return false }
            if let onlyCard, transaction.card !== onlyCard { return false }
            if let cardFilter, transaction.card !== cardFilter { return false }
            if onlyInstallments && transaction.installments <= 1 { return false }
            switch period {
            case .all: return true
            case .month: return calendar.isDate(transaction.date, equalTo: .now, toGranularity: .month)
            case .threeMonths:
                guard let cutoff = calendar.date(byAdding: .month, value: -3, to: .now) else { return true }
                return transaction.date >= cutoff
            case .year: return calendar.isDate(transaction.date, equalTo: .now, toGranularity: .year)
            }
        }
    }

    private var total: Double { purchases.reduce(0) { $0 + $1.amount } }
    private var installmentPurchases: [CardTransaction] { purchases.filter { $0.installments > 1 } }
    private var activePlans: [CardTransaction] { purchases.filter(\.isActiveInstallmentPlan) }
    private var monthlyCommitment: Double { activePlans.reduce(0) { $0 + $1.installmentValue } }
    private var average: Double { purchases.isEmpty ? 0 : total / Double(purchases.count) }

    private var months: [(month: Date, items: [CardTransaction])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: purchases) { calendar.date(from: calendar.dateComponents([.year, .month], from: $0.date)) ?? $0.date }
        return groups.map { (month: $0.key, items: $0.value.sorted { $0.date > $1.date }) }.sorted { $0.month > $1.month }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.l) {
                filters
                summary

                if purchases.isEmpty {
                    ContentUnavailableView(
                        "Sin compras",
                        systemImage: "creditcard",
                        description: Text("Aquí verás tus compras con tarjeta, con sus cuotas y valores.")
                    )
                    .padding(.top, Spacing.xl)
                } else {
                    ForEach(months, id: \.month) { group in
                        monthSection(group.month, group.items)
                    }
                    Text("Las cuotas pagadas son una estimación según los meses transcurridos desde la compra y no incluyen intereses.")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.l)
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.s)
        }
        .scrollIndicators(.hidden)
        .background { AppBackground() }
        .navigationTitle(onlyCard?.name ?? "Compras con tarjeta")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Filtros

    private var filters: some View {
        VStack(spacing: Spacing.s) {
            Picker("Periodo", selection: $period) {
                ForEach(Period.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.s) {
                    chip(title: "Solo en cuotas", icon: "calendar.badge.clock", selected: onlyInstallments) {
                        onlyInstallments.toggle()
                    }
                    if onlyCard == nil {
                        chip(title: "Todas", icon: "creditcard", selected: cardFilter == nil) { cardFilter = nil }
                        ForEach(cards) { card in
                            chip(title: card.name, icon: nil, selected: cardFilter === card) {
                                cardFilter = cardFilter === card ? nil : card
                            }
                        }
                    }
                }
            }
        }
    }

    private func chip(title: String, icon: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { action() }
        } label: {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).font(.caption) }
                Text(title).font(.footnote.weight(.semibold))
            }
            .foregroundStyle(selected ? Color.black : Color.appTextPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(selected ? Color.appAccent : Color.appCardBackground, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Resumen

    private var summary: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total comprado")
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(Color.appTextSecondary)
                Text(CurrencyFormat.string(for: total))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.appTextPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                stat(icon: "cart.fill", tint: .appBlue, title: "Compras", value: "\(purchases.count)")
                stat(icon: "calendar.badge.clock", tint: .appPurple, title: "En cuotas", value: "\(installmentPurchases.count)")
                stat(icon: "banknote", tint: .appOrange, title: "Cuotas por mes", value: CurrencyFormat.string(for: monthlyCommitment, decimals: 0), caption: "\(activePlans.count) plan\(activePlans.count == 1 ? "" : "es") activo\(activePlans.count == 1 ? "" : "s")")
                stat(icon: "chart.bar.fill", tint: .appAccent, title: "Promedio", value: CurrencyFormat.string(for: average, decimals: 0))
            }
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(Color.appBlue.opacity(0.10)), in: RoundedRectangle(cornerRadius: Radius.xlarge, style: .continuous))
    }

    private func stat(icon: String, tint: Color, title: String, value: String, caption: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
            }
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.appTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }

    // MARK: - Lista

    private func monthSection(_ month: Date, _ items: [CardTransaction]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack {
                Text(month.formatted(.dateTime.month(.wide).year()).capitalized)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                Text("\(items.count) · \(CurrencyFormat.string(for: items.reduce(0) { $0 + $1.amount }, decimals: 0))")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    purchaseRow(item)
                    if item.id != items.last?.id {
                        Divider().overlay(Color.appHairline).padding(.leading, 64)
                    }
                }
            }
            .background(Color.appCardBackground, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        }
    }

    private func purchaseRow(_ item: CardTransaction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                CategoryIcon(name: item.category)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.note.isEmpty ? item.category : item.note)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)
                    Text("\(item.card?.name ?? "Tarjeta") · \(item.date.formatted(.dateTime.day().month(.abbreviated)))")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyFormat.string(for: item.amount, decimals: 0))
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.appTextPrimary)
                    if item.installments > 1 {
                        Text("\(item.installments)x \(CurrencyFormat.string(for: item.installmentValue, decimals: 0))")
                            .font(.caption2.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(Color.appBlue)
                    } else {
                        Text("1 pago")
                            .font(.caption2)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
            }

            if item.installments > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    CapsuleProgress(value: Double(item.installmentsElapsed) / Double(item.installments), tint: item.installmentsRemaining == 0 ? .appAccent : .appBlue, height: 5)
                    Text(item.installmentsRemaining == 0
                         ? "Cuotas completadas"
                         : "Quedan \(item.installmentsRemaining) de \(item.installments) cuotas · \(CurrencyFormat.string(for: item.installmentValue * Double(item.installmentsRemaining), decimals: 0)) por pagar")
                        .font(.caption2)
                        .foregroundStyle(Color.appTextSecondary)
                }
                .padding(.leading, 52)
            }
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, 10)
    }
}
