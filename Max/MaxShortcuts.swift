import AppIntents

struct MaxShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RegisterExpenseIntent(),
            phrases: [
                "Registra un gasto en \(.applicationName)",
                "Registrar gasto en \(.applicationName)",
                "Agregar un gasto en \(.applicationName)",
                "Log an expense in \(.applicationName)",
                "Register an expense in \(.applicationName)",
                "Add an expense in \(.applicationName)"
            ],
            shortTitle: "Log Expense",
            systemImageName: "minus.circle"
        )
    }
}
