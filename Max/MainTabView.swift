import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var connectivityMonitor = ConnectivityMonitor.shared
    @State private var selection: AppTab = .resumen
    @State private var showingQuickAdd = false

    enum AppTab: Hashable {
        case resumen, tarjetas, planificacion, analisis
    }

    private func tabButton(_ tab: AppTab, title: String, icon: String) -> some View {
        let selected = selection == tab
        return Button {
            withAnimation(.snappy(duration: 0.2)) { selection = tab }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .symbolVariant(selected ? .fill : .none)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(selected ? Color.appAccent : Color.appTextSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            tabButton(.resumen, title: "Resumen", icon: "list.bullet")
            tabButton(.tarjetas, title: "Tarjetas", icon: "creditcard")

            Button {
                showingQuickAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 54, height: 54)
                    .glassEffect(.regular.tint(Color.appAccent).interactive(), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
            .accessibilityLabel("Nueva transacción")
            .sensoryFeedback(.impact(weight: .light), trigger: showingQuickAdd)

            tabButton(.planificacion, title: "Planificación", icon: "chart.pie")
            tabButton(.analisis, title: "Análisis", icon: "chart.bar")
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: Capsule())
        .padding(.horizontal, Spacing.l)
        .padding(.bottom, Spacing.xs)
    }

    var body: some View {
        TabView(selection: $selection) {
            ContentView(onNavigate: { tab in
                withAnimation(.snappy(duration: 0.2)) { selection = tab }
            })
                .tag(AppTab.resumen)
                .toolbar(.hidden, for: .tabBar)

            CreditCardsView()
                .tag(AppTab.tarjetas)
                .toolbar(.hidden, for: .tabBar)

            PlanningView()
                .tag(AppTab.planificacion)
                .toolbar(.hidden, for: .tabBar)

            AnalysisView()
                .tag(AppTab.analisis)
                .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            floatingTabBar
        }
        .sheet(isPresented: $showingQuickAdd) {
            AddTransactionView()
        }
        .tint(Color.appAccent)
        .fontDesign(.rounded)
        .task {
            RecurringExpenseManager.generateIfNeeded(context: modelContext)
            print("📱 App abierta, disparando sync inicial")
            await SyncManager.shared.syncAll(context: modelContext)
            CategoryMaintenance.run(context: modelContext, syncSucceeded: SyncManager.shared.lastError == nil && !SyncManager.shared.isSyncing)
            connectivityMonitor.onReconnect = {
                print("📶 Reconectado, disparando sync")
                
                Task {
                    await SyncManager.shared.syncAll(context: modelContext)
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Transaction.self, Budget.self, CreditCard.self, CardTransaction.self, Category.self], inMemory: true)
}
