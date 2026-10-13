import SwiftUI

/// Pantalla para cambiar la moneda desde Cuenta, en cualquier momento.
struct CurrencySettingsView: View {
    @State private var settings = CurrencySettings.shared

    var body: some View {
        List {
            Section {
                ForEach(AppCurrency.allCases) { currency in
                    Button {
                        settings.choose(currency)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(currency.displayName)
                                    .foregroundStyle(Color.appTextPrimary)
                                Text("\(currency.code) · \(currency.symbol)")
                                    .font(.caption)
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                            Spacer()
                            if settings.currency == currency {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.appAccent)
                            }
                        }
                    }
                }
            } footer: {
                Text("Este cambio afecta cómo se muestran y se escriben los montos en toda la app.")
            }
            .listRowBackground(Color.appCardBackground)
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Moneda")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        CurrencySettingsView()
    }
}
