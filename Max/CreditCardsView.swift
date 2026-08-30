//
//  CreditCardsView.swift
//  Max
//
//  Created by Santiago Jojoa on 29/08/26.
//

import SwiftUI
import SwiftData

struct CreditCardsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var cards: [CreditCard]
    @State private var showingAddCard = false
    @State private var editingCard: CreditCard?

    private func usedCupo(for card: CreditCard) -> Double {
        let purchases = card.transactions.filter { $0.type == .purchase }.reduce(0) { $0 + $1.amount }
        let payments = card.transactions.filter { $0.type == .payment }.reduce(0) { $0 + $1.amount }
        return purchases - payments
    }

    var body: some View {
        NavigationStack {
            List {
                if cards.isEmpty {
                    ContentUnavailableView(
                        "Sin tarjetas",
                        systemImage: "creditcard",
                        description: Text("Toca + para agregar tu primera tarjeta de crédito.")
                    )
                } else {
                    ForEach(cards) { card in
                        NavigationLink(destination: CardDetailView(card: card)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(card.name)
                                    .font(.headline)

                                let used = usedCupo(for: card)
                                let available = card.creditLimit - used

                                HStack {
                                    Text("Disponible")
                                    Spacer()
                                    Text(available, format: .currency(code: "COP"))
                                        .foregroundStyle(available >= 0 ? .green : .red)
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                ProgressView(value: min(max(used / card.creditLimit, 0), 1))
                                    .tint(used / card.creditLimit >= 0.9 ? .red : .blue)
                            }
                            .padding(.vertical, 4)
                        }
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
            }
            .navigationTitle("Tarjetas")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddCard = true
                    } label: {
                        Label("Agregar", systemImage: "plus")
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

    private func deleteCards(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(cards[index])
        }
    }
}

#Preview {
    CreditCardsView()
        .modelContainer(for: [CreditCard.self, CardTransaction.self], inMemory: true)
}
