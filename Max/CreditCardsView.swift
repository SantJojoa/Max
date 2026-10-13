import SwiftUI
import SwiftData

struct CreditCardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CreditCard> { !$0.isRemoved }) private var cards: [CreditCard]
    @State private var showingAddCard = false
    @State private var editingCard: CreditCard?

    private func usedCupo(for card: CreditCard) -> Double {
        let activeTransactions = card.transactions.filter { !$0.isRemoved }
        let purchases = activeTransactions.filter { $0.type == .purchase }.reduce(0) { $0 + $1.amount }
        let payments = activeTransactions.filter { $0.type == .payment }.reduce(0) { $0 + $1.amount }
        return purchases - payments
    }

    private func progressColor(for percentage: Double) -> Color {
        if percentage >= 0.9 { return .appExpense }
        if percentage >= 0.7 { return .appOrange }
        return .appAccent
    }

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    ContentUnavailableView(
                        "Sin tarjetas",
                        systemImage: "creditcard",
                        description: Text("Toca + para agregar tu primera tarjeta de crédito.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: -112) {
                            ForEach(Array(cards.enumerated()), id: \.element.persistentModelID) { index, card in
                                NavigationLink(destination: CardDetailView(card: card)) {
                                    cardRow(card)
                                }
                                .buttonStyle(.plain)
                                .zIndex(Double(index))
                                .contextMenu {
                                    Button {
                                        editingCard = card
                                    } label: {
                                        Label("Editar", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        delete(card)
                                    } label: {
                                        Label("Eliminar", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.l)
                        .padding(.top, Spacing.s)
                        .padding(.bottom, Spacing.xxl)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .background { AppBackground() }
            .task(id: cards.map { "\($0.name)|\($0.closingDay)|\($0.paymentDay)" }.joined(separator: ";")) {
                NotificationManager.shared.scheduleCardReminders(cards)
            }
            .navigationTitle("Tarjetas")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink {
                        CardPurchasesView()
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                    .accessibilityLabel("Historial de compras con tarjeta")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddCard = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCard) {
                AddCreditCardView()
            }
            .sheet(item: $editingCard) { card in
                AddCreditCardView(cardToEdit: card)
            }
        }
    }

    private static let gradients: [[Color]] = [
        [Color(red: 0.08, green: 0.08, blue: 0.09), Color(red: 0.16, green: 0.16, blue: 0.19)],
        [Color(red: 0.12, green: 0.14, blue: 0.20), Color(red: 0.25, green: 0.20, blue: 0.30)],
        [Color(red: 0.02, green: 0.15, blue: 0.07), Color(red: 0.08, green: 0.36, blue: 0.20)],
        [Color(red: 0.04, green: 0.12, blue: 0.28), Color(red: 0.05, green: 0.30, blue: 0.55)]
    ]

    @ViewBuilder
    private func cardRow(_ card: CreditCard) -> some View {
        let used = usedCupo(for: card)
        let available = card.creditLimit - used
        let percentage = card.creditLimit > 0 ? min(max(used / card.creditLimit, 0), 1) : 0
        let index = abs(card.name.hashValue) % Self.gradients.count

        VStack(alignment: .leading, spacing: Spacing.l) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Crédito")
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(card.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Image(systemName: "wave.3.right")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Disponible")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Text(CurrencyFormat.string(for: available))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            VStack(spacing: 6) {
                CapsuleProgress(value: percentage, tint: progressColor(for: percentage), height: 6)
                    .environment(\.colorScheme, .dark)
                HStack {
                    Text("Usado \(percentage, format: .percent.precision(.fractionLength(0)))")
                    Spacer()
                    Text("Límite \(CurrencyFormat.string(for: card.creditLimit))")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(Spacing.l)
        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .background(
            LinearGradient(colors: Self.gradients[index], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.xlarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.xlarge, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
    }

    private func delete(_ card: CreditCard) {
        card.isRemoved = true
        card.updatedAt = .now
        card.needsSync = true
        for transaction in card.transactions {
            transaction.isRemoved = true
            transaction.updatedAt = .now
            transaction.needsSync = true
        }
    }
}

#Preview {
    CreditCardsView()
        .modelContainer(for: [CreditCard.self, CardTransaction.self], inMemory: true)
}
