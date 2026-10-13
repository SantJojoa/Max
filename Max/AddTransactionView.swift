import SwiftUI
import SwiftData
import PhotosUI

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
    @Query(filter: #Predicate<CreditCard> { !$0.isRemoved }, sort: \CreditCard.name) private var cards: [CreditCard]

    @Query(filter: #Predicate<CardTransaction> { !$0.isRemoved }) private var cardTransactions: [CardTransaction]
    @Query(filter: #Predicate<Account> { !$0.isRemoved }, sort: \Account.name) private var accounts: [Account]
    @State private var selectedAccount: Account?
    @AppStorage("lastAccountName") private var lastAccountName = ""
    @State private var categoryChosenManually = false

    private enum PaymentMethod { case cash, card }
    @State private var method: PaymentMethod = .cash
    @State private var selectedCard: CreditCard?

    @State private var receiptData: Data?
    @State private var showingScanner = false
    @State private var photoItem: PhotosPickerItem?
    @State private var isReadingReceipt = false
    @State private var receiptMessage: String?
    @Query private var allTransactions: [Transaction]
    @Query(filter: #Predicate<Category> { !$0.isRemoved }, sort: \Category.name) private var allCategories: [Category]

    private var currentCategories: [String] {
        let scope: CategoryScope = type == .expense ? .expense : .income
        return allCategories.filter { $0.scope == scope }.map { $0.name }
    }

    private var isValid: Bool {
        guard amount > 0 else { return false }
        if method == .card && !isEditing && selectedCard == nil { return false }
        return !category.isEmpty
    }

    private var isEditing: Bool { transactionToEdit != nil }

    private var currency: AppCurrency { CurrencySettings.shared.currency }

    private var samples: [CategorySuggester.Sample] {
        let cash = allTransactions.filter { !$0.isRemoved }.map {
            CategorySuggester.Sample(note: $0.note, category: $0.category, isIncome: $0.type == .income, amount: $0.amount, date: $0.date, card: nil)
        }
        let card = cardTransactions.filter { $0.type == .purchase }.map {
            CategorySuggester.Sample(note: $0.note, category: $0.category, isIncome: false, amount: $0.amount, date: $0.date, card: $0.card)
        }
        return cash + card
    }

    private var frequentItems: [CategorySuggester.Frequent] {
        guard !isEditing, digits.isEmpty, note.isEmpty else { return [] }
        return CategorySuggester.frequent(samples: samples)
    }

    private func applyAutoCategory() {
        guard !isEditing, !categoryChosenManually else { return }
        if let suggestion = CategorySuggester.suggest(note: note, isIncome: type == .income, samples: samples, available: currentCategories) {
            if category != suggestion {
                withAnimation(.snappy(duration: 0.2)) { category = suggestion }
            }
        }
    }

    private func apply(_ item: CategorySuggester.Frequent) {
        categoryChosenManually = true
        type = item.isIncome ? .income : .expense
        note = item.note
        digits = AmountField.Coordinator.digits(from: item.amount, currency: currency)
        if currentCategories.contains(item.category) { category = item.category }
        if let card = item.card, cards.contains(where: { $0 === card }) {
            method = .card
            selectedCard = card
        } else {
            method = .cash
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

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
                VStack(spacing: Spacing.s) {
                    controlsRow

                    if showsMethodSelector && method == .card {
                        cardChips
                    } else if !accounts.isEmpty {
                        accountChips
                    }

                    if !frequentItems.isEmpty {
                        suggestionsRow
                    }

                    amountDisplay

                    categoryCarousel

                    detailsCard

                    keypad
                }
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.s)
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
                .padding(.top, Spacing.s)
                .padding(.bottom, Spacing.xs)
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
                if transactionToEdit == nil {
                    type = initialType
                    selectedAccount = accounts.first { $0.name == lastAccountName } ?? accounts.first
                }
                if let transaction = transactionToEdit {
                    digits = AmountField.Coordinator.digits(from: transaction.amount, currency: currency)
                    type = transaction.type
                    category = transaction.category
                    date = transaction.date
                    note = transaction.note
                    receiptData = transaction.receiptData
                    selectedAccount = transaction.account
                }
            }
            .sheet(isPresented: $showingScanner) {
                DocumentScanner { image in
                    showingScanner = false
                    Task { await handleReceipt(image) }
                } onCancel: {
                    showingScanner = false
                }
                .ignoresSafeArea()
            }
            .onChange(of: note) { applyAutoCategory() }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        await handleReceipt(image)
                    }
                    photoItem = nil
                }
            }
            .onChange(of: type) {
                if !currentCategories.contains(category) {
                    category = ""
                }
                if type == .income { method = .cash }
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
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.appTextSecondary)
                Text(amountText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(digits.isEmpty ? Color.appTextSecondary : (type == .income ? Color.appIncome : Color.appTextPrimary))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
            .animation(.snappy(duration: 0.15), value: digits)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Categorías

    private var categoryCarousel: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.m) {
                    ForEach(currentCategories, id: \.self) { name in
                        let selected = category == name
                        let tint = CategoryStyle.color(for: name)
                        Button {
                            categoryChosenManually = true
                            withAnimation(.snappy(duration: 0.2)) { category = name }
                        } label: {
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(selected ? tint.opacity(0.25) : Color.appCardBackground)
                                    .frame(width: 50, height: 50)
                                    .overlay {
                                        CategoryGlyph(name: name, size: 23)
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(selected ? tint.opacity(0.7) : Color.primary.opacity(0.06), lineWidth: selected ? 1.5 : 0.5)
                                    }
                                Text(name)
                                    .font(.caption.weight(selected ? .semibold : .regular))
                                    .foregroundStyle(selected ? Color.appTextPrimary : Color.appTextSecondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 60)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Spacing.l)
            }
        }
    }

    // MARK: - Tipo (solo íconos)

    private var controlsRow: some View {
        HStack(spacing: Spacing.s) {
            typeButton(.expense, icon: "arrow.up.right", tint: .appExpense, label: "Gasto")
            typeButton(.income, icon: "arrow.down.left", tint: .appIncome, label: "Ingreso")

            if showsMethodSelector {
                Rectangle()
                    .fill(Color.appHairline)
                    .frame(width: 1, height: 26)
                    .padding(.horizontal, 2)
                methodButton(.cash, icon: "banknote.fill", label: "Efectivo")
                methodButton(.card, icon: "creditcard.fill", label: "Tarjeta")
            }
        }
        .padding(.horizontal, Spacing.l)
    }

    private func typeButton(_ value: TransactionType, icon: String, tint: Color, label: String) -> some View {
        let selected = type == value
        return Button {
            withAnimation(.snappy(duration: 0.2)) { type = value }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(selected ? Color.white : tint)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(selected ? tint : tint.opacity(0.15), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .sensoryFeedback(.selection, trigger: type)
    }

    // MARK: - Cuenta

    private var accountChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(accounts) { account in
                    let isSelected = selectedAccount === account
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            selectedAccount = isSelected ? nil : account
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: account.kind.icon)
                                .font(.system(size: 12, weight: .semibold))
                            Text(account.name)
                                .font(.footnote.weight(.semibold))
                        }
                        .foregroundStyle(isSelected ? Color.black : Color.appTextPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isSelected ? Color.appAccent : Color.appCardBackground, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.l)
        }
    }

    // MARK: - Frecuentes

    private var suggestionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                Image(systemName: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(Color.appOrange)
                ForEach(frequentItems) { item in
                    Button {
                        apply(item)
                    } label: {
                        HStack(spacing: 6) {
                            CategoryGlyph(name: item.category, size: 14)
                            Text(item.note)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.appTextPrimary)
                                .lineLimit(1)
                            Text(CurrencyFormat.string(for: item.amount, decimals: 0))
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(Color.appTextSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.appCardBackground, in: Capsule())
                        .overlay { Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5) }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.l)
        }
    }

    // MARK: - Método de pago (solo íconos)

    private var showsMethodSelector: Bool {
        type == .expense && !isEditing && !cards.isEmpty
    }

    private var cardChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.s) {
                ForEach(cards) { card in
                    let isSelected = selectedCard === card
                    Button {
                        withAnimation(.snappy(duration: 0.2)) { selectedCard = card }
                    } label: {
                        Text(card.name)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.black : Color.appTextPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.appAccent : Color.appCardBackground, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.l)
        }
    }

    private func methodButton(_ value: PaymentMethod, icon: String, label: String) -> some View {
        let selected = method == value
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                method = value
                if value == .card && selectedCard == nil { selectedCard = cards.first }
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(selected ? Color.black : Color.appTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(selected ? Color.appAccent : Color.appCardBackground, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .sensoryFeedback(.selection, trigger: method)
    }

    // MARK: - Recibo

    private var receiptControls: some View {
        HStack(spacing: 2) {
            if isReadingReceipt {
                ProgressView()
                    .frame(width: 40, height: 32)
            } else if let receiptData, let image = UIImage(data: receiptData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                Button {
                    self.receiptData = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.appTextSecondary)
                        .frame(width: 30, height: 32)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    showingScanner = true
                } label: {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 20))
                        .frame(width: 38, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.appAccent)
                .accessibilityLabel("Escanear recibo")

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Image(systemName: "photo")
                        .font(.system(size: 19))
                        .frame(width: 38, height: 32)
                }
                .foregroundStyle(Color.appAccent)
                .accessibilityLabel("Elegir foto del recibo")
            }
        }
    }

    @MainActor
    private func handleReceipt(_ image: UIImage) async {
        isReadingReceipt = true
        receiptData = ReceiptReader.compressed(image)
        let info = await ReceiptReader.read(image, decimals: currency.decimalDigits)

        if amount == 0, let value = info.amount {
            digits = AmountField.Coordinator.digits(from: value, currency: currency)
        }
        if note.isEmpty, let merchant = info.merchant {
            note = merchant
        }
        isReadingReceipt = false
        UINotificationFeedbackGenerator().notificationOccurred(info.amount == nil ? .warning : .success)
    }

    // MARK: - Detalles

    private var detailsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(width: 24)
                TextField("Concepto o nota (opcional)", text: $note)
                receiptControls
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, 6)

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
            .padding(.vertical, 3)

        }
        .background(Color.appCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .padding(.horizontal, Spacing.l)
    }

    // MARK: - Teclado numérico

    private var keypad: some View {
        let keys: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["00", "0", "⌫"]]
        return VStack(spacing: 8) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 8) {
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
                                        .font(.system(size: 22, weight: .medium, design: .rounded))
                                }
                            }
                            .foregroundStyle(Color.appTextPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
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
        if method == .card, !isEditing, type == .expense, let card = selectedCard {
            let purchase = CardTransaction(amount: amount, type: .purchase, category: category, date: date, note: note, card: card)
            modelContext.insert(purchase)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
            return
        }

        if let transaction = transactionToEdit {
            transaction.amount = amount
            transaction.type = type
            transaction.category = category
            transaction.account = selectedAccount
            transaction.date = date
            transaction.note = note
            if transaction.receiptData != receiptData {
                transaction.receiptData = receiptData
                transaction.receiptNeedsUpload = true
            }
            transaction.updatedAt = .now
            transaction.needsSync = true
        } else {
            let transaction = Transaction(amount: amount, type: type, category: category, date: date, note: note)
            transaction.receiptData = receiptData
            transaction.receiptNeedsUpload = receiptData != nil
            transaction.account = selectedAccount
            modelContext.insert(transaction)
            if let selectedAccount { lastAccountName = selectedAccount.name }
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
