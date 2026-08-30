import SwiftUI
import SwiftData
struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Movimientos", systemImage: "list.bullet")
                }

            CreditCardsView()
                .tabItem {
                    Label("Tarjetas", systemImage: "creditcard")
                }

            BudgetsView()
                .tabItem {
                    Label("Presupuestos", systemImage: "chart.pie")
                }
            ReportsView()
                .tabItem{
                    Label("Reportes", systemImage: "doc.text")
                }

            ChartsView()
                .tabItem {
                    Label("Gráficas", systemImage: "chart.bar")
                }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Transaction.self, Budget.self, CreditCard.self, CardTransaction.self], inMemory: true)
}
