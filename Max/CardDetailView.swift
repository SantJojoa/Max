import SwiftUI
import SwiftData

struct CardDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let card: CreditCard

    @State private var showingAddPurchase = false
    @State private var showingAddPayment = false
    @State private var editingTransaction: CardTransaction?

    private var sortedTransactions: [CardTransaction] {
        card.transactions.filter { !$0.isRemoved }.sorted { $0.date > $1.date }
    }

    private var usedCupo: Double {
        let activeTransactions = card.transactions.filter { !$0.isRemoved }
        let purchases = activeTransactions.filter { $0.type == .purchase }.reduce(0) { $0 + $1.amount }
        let payments = activeTransactions.filter { $0.type == .payment }.reduce(0) { $0 + $1.amount }
        return purchases - payments
    }

    private var availableCupo: Double {
        card.creditLimit - usedCupo
    }

    private var usageRatio: Double {
        guard card.creditLimit > 0 else { return 0 }
        return min(max(usedCupo / card.creditLimit, 0), 1)
    }

    private var progressColor: Color {
        if usageRatio >= 0.9 { return .appExpense }
        if usageRatio >= 0.7 { return .appOrange }
        return .appAccent
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Crédito disponible")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                    Text(CurrencyFormat.string(for: availableCupo))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(availableCupo >= 0 ? Color.appTextPrimary : Color.appExpense)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    CapsuleProgress(value: usageRatio, tint: progressColor, height: 10)
                    HStack {
                        Text("Usado \(CurrencyFormat.string(for: usedCupo))")
                        Spacer()
                        Text("Uso \(usageRatio, format: .percent.precision(.fractionLength(0)))")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.appCardBackground)

            Section {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    infoTile(icon: "scissors", tint: .appBlue, title: "Próximo corte", value: dateText(nextDate(forDay: card.closingDay)), caption: daysCaption(nextDate(forDay: card.closingDay)))
                    if card.paymentDay > 0 {
                        infoTile(icon: "calendar.badge.exclamationmark", tint: .appOrange, title: "Fecha límite de pago", value: dateText(nextDate(forDay: card.paymentDay)), caption: daysCaption(nextDate(forDay: card.paymentDay)))
                    }
                    infoTile(icon: "percent", tint: .appExpense, title: "Interés estimado", value: CurrencyFormat.string(for: estimatedInterest, decimals: 0), caption: "si no pagas el total")
                    infoTile(icon: "banknote", tint: .appAccent, title: "Pago mínimo (est.)", value: CurrencyFormat.string(for: estimatedMinimum, decimals: 0), caption: "interés + manejo + 5%")
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

            Section("Detalles") {
                detailRow(title: "Día de corte", value: "\(card.closingDay)")
                detailRow(title: "Tasa de interés mensual", value: card.monthlyInterestRate.formatted(.number.precision(.fractionLength(1))) + "%")
                detailRow(title: "Cuota de manejo", value: CurrencyFormat.string(for: card.managementFee))
            }
            .listRowBackground(Color.appCardBackground)

            Section("Movimientos") {
                if sortedTransactions.isEmpty {
                    Text("Todavía no hay movimientos en esta tarjeta.")
                        .foregroundStyle(Color.appTextSecondary)
                } else {
                    ForEach(sortedTransactions) { transaction in
                        HStack(spacing: 12) {
                            if transaction.type == .payment {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.appIncome.opacity(0.18))
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Image(systemName: "arrow.down.left")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(Color.appIncome)
                                    }
                            } else {
                                CategoryIcon(name: transaction.category)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(transaction.type == .purchase ? transaction.category : "Pago")
                                    .font(.headline)
                                Text(transaction.date, format: .dateTime.day().month().year())
                                    .font(.caption)
                                    .foregroundStyle(Color.appTextSecondary)
                                if transaction.type == .purchase && transaction.installments > 1 {
                                    Text("\(transaction.installments) cuotas de \(CurrencyFormat.string(for: transaction.installmentValue, decimals: 0))")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(Color.appBlue)
                                }
                            }
                            Spacer()
                            Text("\(transaction.type == .payment ? "+" : "-")\(CurrencyFormat.string(for: transaction.amount))")
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(transaction.type == .payment ? Color.appIncome : Color.appTextPrimary)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingTransaction = transaction
                        }
                    }
                    .onDelete(perform: deleteTransactions)
                }
            }
            .listRowBackground(Color.appCardBackground)
        }
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .navigationTitle(card.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    CardPurchasesView(onlyCard: card)
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                }
                .accessibilityLabel("Historial de compras")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingAddPurchase = true
                    } label: {
                        Label("Registrar compra", systemImage: "cart")
                    }
                    Button {
                        showingAddPayment = true
                    } label: {
                        Label("Registrar pago", systemImage: "creditcard.and.123")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPurchase) {
            AddCardTransactionView(card: card, type: .purchase)
        }
        .sheet(isPresented: $showingAddPayment) {
            AddCardTransactionView(card: card, type: .payment)
        }
        .sheet(item: $editingTransaction) { transaction in
            AddCardTransactionView(card: card, type: transaction.type, transactionToEdit: transaction)
        }
    }

    // MARK: - Fechas y estimaciones

    private var estimatedInterest: Double {
        max(0, usedCupo) * card.monthlyInterestRate / 100
    }

    /// Estimación: intereses + cuota de manejo + 5% del saldo usado. Cada banco define su fórmula real.
    private var estimatedMinimum: Double {
        guard usedCupo > 0 else { return 0 }
        return estimatedInterest + card.managementFee + usedCupo * 0.05
    }

    private func nextDate(forDay day: Int) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        for offset in 0...2 {
            guard let month = calendar.date(byAdding: .month, value: offset, to: today) else { continue }
            let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
            var comps = calendar.dateComponents([.year, .month], from: month)
            comps.day = min(day, daysInMonth)
            if let date = calendar.date(from: comps), date >= today { return date }
        }
        return today
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    private func daysCaption(_ date: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: .now), to: date).day ?? 0
        if days == 0 { return "Hoy" }
        return days == 1 ? "Mañana" : "En \(days) días"
    }

    private func infoTile(icon: String, tint: Color, title: String, value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.appTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(Color.appTextSecondary)
        }
        .padding(Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private func deleteTransactions(at offsets: IndexSet) {
        for index in offsets {
            let transaction = sortedTransactions[index]
            transaction.isRemoved = true
            transaction.updatedAt = .now
            transaction.needsSync = true
        }
    }
}

#Preview {
    NavigationStack {
        CardDetailView(card: CreditCard(name: "Visa", creditLimit: 1000000, closingDay: 15, monthlyInterestRate: 2.0, managementFee: 15000))
    }
    .modelContainer(for: [CreditCard.self, CardTransaction.self], inMemory: true)
}
