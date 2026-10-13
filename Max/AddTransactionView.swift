import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var transactionToEdit: Transaction?
    var initialType: TransactionType = .expense

    @State private var digits: String = ""
    @State private var type: TransactionType = .expense
    @State private var category: String = ""
    @State private var date: Date = .now
    @State private var note: String = ""

    @Query private var budgets: [Budget]
    @Query private var allTransactions: [Transaction]
    @Query(filter: #Predicate<Category> { !$0.isDeleted }, sort: \Category.name) private var allCategories: [Category]

    private var currentCategories: [String] {
        let scope: CategoryScope = type == .expense ? .expense : .income
        return allCategories.filter { $0.scope == scope }.map { $0.name }
    }

    private var isValid: Bool {
        guard amount > 0 else { return false }
        return !category.isEmpty
    }

    private var isEditing: Bool { transactionToEdit != nil }

    private var currency: AppCurrency { CurrencySettings.shared.currency }

    private var amount: Double {
        AmountField.Coordinator.numericValue(fromDigits: digits, currency: currency)
    }

    private var amountText: String {
        let formatted = AmountField.Coordinator.formattedString(fromDigits: digits, currency: currency)
        if !formatted.isEmpty { return formatted }
        return currency.decimalDigits == 0 ? "0" : "0," + String(repeating: "0", count: currency.decimalDigits)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.m) {
                    Picker("Tipo", selection: $type) {
                        ForEach(TransactionType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Spacing.l)

                    amountDisplay

                    categoryCarousel

                    detailsCard

                    keypad
                }
                .padding(.bottom, Spacing.l)
            }
            .scrollIndicators(.hidden)
            .background { AppBackground() }
            .safeAreaInset(edge: .bottom) {
                Button {
                    save()
                } label: {
                    Label(saveLabel, systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(PrimaryButtonStyle(isDisabled: !isValid))
                .disabled(!isValid)
                .padding(.horizontal, Spacing.l)
                .padding(.vertical, Spacing.s)
                .background(.bar)
            }
            .tint(Color.appAccent)
            .navigationTitle(isEditing ? "Editar transacción" : "Nueva transacción")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .onAppear {
                if transactionToEdit == nil { type = initialType }
                if let transaction = transactionToEdit {
                    digits = AmountField.Coordinator.digits(from: transaction.amount, currency: currency)
                    type = transaction.type
                    category = transaction.category
                    date = transaction.date
                    note = transaction.note
                }
            }
            .onChange(of: type) {
                if !currentCategories.contains(category) {
                    category = ""
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var saveLabel: String {
        isEditing ? "Guardar cambios" : (type == .expense ? "Guardar gasto" : "Registrar ingreso")
    }

    // MARK: - Monto

    private var amountDisplay: some View {
        VStack(spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(currency.symbol)
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                Text(amountText)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(digits.isEmpty ? Color.appTextSecondary : Color.appTextPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
            .animation(.snappy(duration: 0.15), value: digits)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.m)
    }

    // MARK: - Categorías

    private var categoryCarousel: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Categoría")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.appTextSecondary)
                .padding(.horizontal, Spacing.l)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.m) {
                    ForEach(currentCategories, id: \.self) { name in
                        let selected = category == name
                        let tint = CategoryStyle.color(for: name)
                        Button {
                            withAnimation(.snappy(duration: 0.2)) { category = name }
                        } label: {
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(selected ? tint.opacity(0.25) : Color.appCardBackground)
                                    .frame(width: 58, height: 58)
                                    .overlay {
                                        Image(systemName: CategoryStyle.symbol(for: name))
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundStyle(tint)
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(selected ? tint.opacity(0.7) : Color.primary.opacity(0.06), lineWidth: selected ? 1.5 : 0.5)
                                    }
                                Text(name)
                                    .font(.caption.weight(selected ? .semibold : .regular))
                                    .foregroundStyle(selected ? Color.appTextPrimary : Color.appTextSecondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 66)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.l)
            }
        }
    }

    // MARK: - Detalles

    private var detailsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(width: 24)
                TextField("Concepto o nota (opcional)", text: $note)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, 12)

            Divider().padding(.leading, 52)

            HStack(spacing: 12) {
                Image(systemName: "calendar")
                    .foregroundStyle(Color.appBlue)
                    .frame(width: 24)
                Text("Fecha")
                Spacer()
                DatePicker("Fecha", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, 8)
        }
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .padding(.horizontal, Spacing.l)
    }

    // MARK: - Teclado numérico

    private var keypad: some View {
        let keys: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["00", "0", "⌫"]]
        return VStack(spacing: Spacing.s) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: Spacing.s) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            press(key)
                        } label: {
                            Group {
                                if key == "⌫" {
                                    Image(systemName: "delete.left")
                                        .font(.title3)
                                } else {
                                    Text(key)
                                        .font(.system(size: 24, weight: .medium, design: .rounded))
                                }
                            }
                            .foregroundStyle(Color.appTextPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.appCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .sensoryFeedback(.selection, trigger: digits)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.l)
    }

    private func press(_ key: String) {
        if key == "⌫" {
            digits = String(digits.dropLast())
        } else if digits.count + key.count <= 12 {
            if digits.isEmpty && key.allSatisfy({ $0 == "0" }) { return }
            digits += key
        }
    }

    private func save() {
        if let transaction = transactionToEdit {
            transaction.amount = amount
            transaction.type = type
            transaction.category = category
            transaction.date = date
            transaction.note = note
            transaction.updatedAt = .now
            transaction.needsSync = true
        } else {
            let transaction = Transaction(amount: amount, type: type, category: category, date: date, note: note)
            modelContext.insert(transaction)
        }

        if type == .expense {
            checkBudgetAndNotify(category: category, amount: amount)
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private func checkBudgetAndNotify(category: String, amount: Double) {
        let month = Calendar.current.component(.month, from: date)
        let year = Calendar.current.component(.year, from: date)

        guard let budget = budgets.first(where: {
            $0.category == category && $0.month == month && $0.year == year
        }) else { return }

        // Sumamos los gastos de esa categoría/mes SIN contar la transacción actual (para no duplicarla si se está editando),
        // y le sumamos el monto actual manualmente.
        let spentExcludingThis = allTransactions
            .filter { $0 !== transactionToEdit }
            .filter {
                $0.type == .expense &&
                $0.category == category &&
                Calendar.current.component(.month, from: $0.date) == month &&
                Calendar.current.component(.year, from: $0.date) == year
            }
            .reduce(0) { $0 + $1.amount }

        let totalSpent = spentExcludingThis + amount
        let ratio = totalSpent / budget.limitAmount

        if ratio >= 1.0 {
            NotificationManager.shared.sendBudgetAlert(category: category, exceeded: true)
        } else if ratio >= 0.8 {
            NotificationManager.shared.sendBudgetAlert(category: category, exceeded: false)
        }
    }
}

#Preview {
    AddTransactionView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
