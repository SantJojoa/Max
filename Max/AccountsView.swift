import SwiftUI
import SwiftData

/// Administración de cuentas (efectivo, banco, ahorros) con saldo propio.
struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Account> { !$0.isRemoved }, sort: \Account.name) private var accounts: [Account]
    @State private var showingAdd = false
    @State private var editingAccount: Account?

    private var total: Double { accounts.reduce(0) { $0 + $1.balance } }

    var body: some View {
        List {
            if !accounts.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total en cuentas")
                            .font(.footnote.weight(.semibold))
                            .textCase(.uppercase)
                            .tracking(1)
                            .foregroundStyle(Color.appTextSecondary)
                        Text(CurrencyFormat.string(for: total))
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(Color.appTextPrimary)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                    .padding(Spacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular.tint(Color.appBlue.opacity(0.10)), in: RoundedRectangle(cornerRadius: Radius.xlarge, style: .continuous))
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }

            Section {
                if accounts.isEmpty {
                    ContentUnavailableView(
                        "Sin cuentas",
                        systemImage: "building.columns",
                        description: Text("Crea una cuenta para llevar el saldo de tu banco, tus ahorros o tu efectivo por separado.")
                    )
                } else {
                    ForEach(accounts) { account in
                        row(account)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(account)
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                                Button {
                                    editingAccount = account
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            } footer: {
                if !accounts.isEmpty {
                    Text("Al eliminar una cuenta, sus movimientos se conservan pero quedan sin cuenta.")
                        .font(.footnote)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .navigationTitle("Cuentas")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) { AddAccountView() }
        .sheet(item: $editingAccount) { AddAccountView(accountToEdit: $0) }
    }

    private func row(_ account: Account) -> some View {
        Button {
            editingAccount = account
        } label: {
            HStack(spacing: 14) {
                IconBadge(systemImage: account.kind.icon, tint: tint(for: account.kind), size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.appTextPrimary)
                    Text(account.kind.rawValue)
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }
                Spacer()
                Text(CurrencyFormat.string(for: account.balance))
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(account.balance >= 0 ? Color.appTextPrimary : Color.appExpense)
            }
            .floatingCardStyle()
        }
        .buttonStyle(.plain)
    }

    private func tint(for kind: AccountKind) -> Color {
        switch kind {
        case .cash: return .appAccent
        case .bank: return .appBlue
        case .savings: return .appPurple
        }
    }

    private func delete(_ account: Account) {
        account.isRemoved = true
        account.updatedAt = .now
        account.needsSync = true
        for transaction in account.transactions {
            transaction.account = nil
            transaction.updatedAt = .now
            transaction.needsSync = true
        }
    }
}

struct AddAccountView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var accountToEdit: Account?

    @State private var name = ""
    @State private var kind: AccountKind = .bank
    @State private var initialBalance: Double = 0

    private var isEditing: Bool { accountToEdit != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre (ej. Bancolombia, Nequi, Efectivo)", text: $name)
                    .listRowBackground(Color.appCardBackground)

                Section("Tipo") {
                    HStack(spacing: Spacing.s) {
                        ForEach(AccountKind.allCases, id: \.self) { option in
                            let selected = kind == option
                            Button {
                                kind = option
                            } label: {
                                Image(systemName: option.icon)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(selected ? Color.black : Color.appTextSecondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(selected ? Color.appAccent : Color.appElevated, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.rawValue)
                        }
                    }
                }
                .listRowBackground(Color.appCardBackground)

                Section {
                    AmountField(placeholder: "Saldo inicial", value: $initialBalance)
                } footer: {
                    Text("Lo que tienes hoy en esta cuenta. Los movimientos que le asignes lo irán cambiando.")
                }
                .listRowBackground(Color.appCardBackground)
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .tint(Color.appAccent)
            .navigationTitle(isEditing ? "Editar cuenta" : "Nueva cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let account = accountToEdit {
                    name = account.name
                    kind = account.kind
                    initialBalance = account.initialBalance
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let account = accountToEdit {
            account.name = trimmed
            account.kind = kind
            account.initialBalance = initialBalance
            account.updatedAt = .now
            account.needsSync = true
        } else {
            modelContext.insert(Account(name: trimmed, kind: kind, initialBalance: initialBalance))
        }
        dismiss()
    }
}
