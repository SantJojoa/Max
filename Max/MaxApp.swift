import SwiftUI
import SwiftData

@main
struct MaxApp: App {
    @State private var authManager = AuthManager.shared
    @State private var currencySettings = CurrencySettings.shared
    @State private var isUnlocked = false
    @State private var showQuickAdd = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoading {
                    ProgressView()
                } else if !authManager.isAuthenticated {
                    AuthView()
                } else if !currencySettings.hasChosenCurrency {
                    CurrencyOnboardingView()
                } else if !isUnlocked {
                    AppLockView {
                        isUnlocked = true
                    }
                } else {
                    MainTabView()
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                NotificationManager.shared.requestAuthorization()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    isUnlocked = false
                } else if newPhase == .active {
                    checkQuickAddRequest()
                }
            }
            .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
                if !isAuthenticated {
                    isUnlocked = false
                }
            }
            .onChange(of: isUnlocked) { _, unlocked in
                if unlocked {
                    checkQuickAddRequest()
                }
            }
            .sheet(isPresented: $showQuickAdd) {
                AddTransactionView()
            }
        }
        .modelContainer(SharedModelContainer.container)
    }

    private func checkQuickAddRequest() {
        guard authManager.isAuthenticated, isUnlocked else { return }
        let defaults = UserDefaults(suiteName: "group.com.santiago.max")
        guard defaults?.bool(forKey: "widget_quick_add_requested") == true else { return }
        defaults?.set(false, forKey: "widget_quick_add_requested")
        showQuickAdd = true
    }
}
