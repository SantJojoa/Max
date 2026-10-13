import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var connectivityMonitor = ConnectivityMonitor.shared

    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Resumen", systemImage: "list.bullet")
                }

            CreditCardsView()
                .tabItem {
                    Label("Tarjetas", systemImage: "creditcard")
                }

            PlanningView()
                .tabItem {
                    Label("Planificación", systemImage: "chart.pie")
                }

            AnalysisView()
                .tabItem {
                    Label("Análisis", systemImage: "chart.bar.doc.horizontal")
                }
        }
        .tint(Color.appAccent)
        .task {
            seedDefaultCategoriesIfNeeded()
            RecurringExpenseManager.generateIfNeeded(context: modelContext)
            print("📱 App abierta, disparando sync inicial")
            await SyncManager.shared.syncAll(context: modelContext)
            connectivityMonitor.onReconnect = {
                print("📶 Reconectado, disparando sync")
                
                Task {
                    await SyncManager.shared.syncAll(context: modelContext)
                }
            }
        }
    }

    private func seedDefaultCategoriesIfNeeded() {
        let existingCount = (try? modelContext.fetchCount(FetchDescriptor<Category>())) ?? 0
        guard existingCount == 0 else { return }

        let expenseDefaults = ["Comida", "Transporte", "Vivienda", "Entretenimiento", "Salud", "Otros"]
        let incomeDefaults = ["Salario", "Freelance", "Regalo", "Otros"]
        let cardDefaults = ["Comida", "Transporte", "Compras", "Entretenimiento", "Salud", "Suscripciones", "Otros"]

        for name in expenseDefaults {
            modelContext.insert(Category(name: name, scope: .expense))
        }
        for name in incomeDefaults {
            modelContext.insert(Category(name: name, scope: .income))
        }
        for name in cardDefaults {
            modelContext.insert(Category(name: name, scope: .card))
        }

        try? modelContext.save()
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Transaction.self, Budget.self, CreditCard.self, CardTransaction.self, Category.self], inMemory: true)
}
