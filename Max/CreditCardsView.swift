import SwiftUI
import SwiftData

struct CreditCardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CreditCard> { !$0.isDeleted }) private var cards: [CreditCard]
    @State private var showingAddCard = false
    @State private var editingCard: CreditCard?

    private func usedCupo(for card: CreditCard) -> Double {
        let activeTransactions = card.transactions.filter { !$0.isDeleted }
        let purchases = activeTransactions.filter { $0.type == .purchase }.reduce(0) { $0 + $1.amount }
        let payments = activeTransactions.filter { $0.type == .payment }.reduce(0) { $0 + $1.amount }
        return purchases - payments
    }

    private func progressColor(for percentage: Double) -> Color {
        if percentage >= 0.9 { return .appExpense }
        if percentage >= 0.7 { return .orange }
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
                    List {
                        ForEach(cards) { card in
                            NavigationLink(destination: CardDetailView(card: card)) {
                                cardRow(card)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .swipeActions(edge: .leading) {
                                Button {
                                    editingCard = card
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: deleteCards)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Tarjetas")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddCard = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.appAccent)
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

    @ViewBuilder
    private func cardRow(_ card: CreditCard) -> some View {
        let used = usedCupo(for: card)
        let available = card.creditLimit - used
        let percentage = card.creditLimit > 0 ? min(max(used / card.creditLimit, 0), 1) : 0

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: Spacing.s) {
                IconBadge(systemImage: "creditcard.fill", tint: .appAccent, size: 26)
                Text(card.name)
                    .font(.headline)
                Spacer()
            }

            HStack {
                Text("Disponible")
                    .font(.caption)
                    .foregroundStyle(Color.appTextSecondary)
                Spacer()
                Text(CurrencyFormat.string(for: available))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(available >= 0 ? Color.appIncome : Color.appExpense)
            }

            ProgressView(value: percentage)
                .tint(progressColor(for: percentage))
        }
        .floatingCardStyle()
    }

    private func deleteCards(at offsets: IndexSet) {
        for index in offsets {
            let card = cards[index]
            card.isDeleted = true
            card.updatedAt = .now
            card.needsSync = true
            for transaction in card.transactions {
                transaction.isDeleted = true
                transaction.updatedAt = .now
                transaction.needsSync = true
            }
        }
    }
}

#Preview {
    CreditCardsView()
        .modelContainer(for: [CreditCard.self, CardTransaction.self], inMemory: true)
}
