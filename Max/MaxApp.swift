import SwiftUI
import SwiftData

@main
struct MaxApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .onAppear {
                    NotificationManager.shared.requestAuthorization()
                }
        }
        .modelContainer(for: [Transaction.self, Budget.self, CreditCard.self, CardTransaction.self])
    }
}
