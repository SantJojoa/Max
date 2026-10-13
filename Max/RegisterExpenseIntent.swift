import AppIntents
import SwiftData
import Foundation

struct RegisterExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Expense"
    static var description = IntentDescription("Logs a cash expense in Max.")

    @Parameter(title: "Amount", requestValueDialog: "How much did you spend?")
    var amount: Double

    @Parameter(title: "Note", default: "", requestValueDialog: "What was it for?")
    var note: String

    static var parameterSummary: some ParameterSummary {
        Summary("Log an expense of \(\.$amount) for \(\.$note)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = SharedModelContainer.container.mainContext
        let transaction = Transaction(amount: amount, type: .expense, category: "Otros", date: .now, note: note)
        context.insert(transaction)
        try context.save()

        let amountText = CurrencyFormat.string(for: amount)

        if note.isEmpty {
            return .result(dialog: "Done, I logged an expense of \(amountText).")
        } else {
            return .result(dialog: "Done, I logged an expense of \(amountText) for \(note).")
        }
    }
}
