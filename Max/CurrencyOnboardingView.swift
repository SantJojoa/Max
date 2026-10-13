import SwiftUI

/// Pantalla que se muestra una sola vez, la primera vez que el usuario entra a la app,
/// para elegir en qué moneda quiere ver y registrar sus montos.
struct CurrencyOnboardingView: View {
    @State private var settings = CurrencySettings.shared
    @State private var selected: AppCurrency = .cop

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Image(systemName: "banknote.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.appAccent)
                        .padding(.top, 24)

                    Text("¿En qué moneda quieres usar Max?")
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text("Puedes cambiarla luego cuando quieras desde Cuenta.")
                        .font(.subheadline)
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 24)

                List {
                    ForEach(AppCurrency.allCases) { currency in
                        Button {
                            selected = currency
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
                                if selected == currency {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.appAccent)
                                }
                            }
                        }
                        .listRowBackground(Color.appCardBackground)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                Button {
                    settings.choose(selected)
                } label: {
                    Text("Continuar")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding()
            }
            .background(Color.appBackground)
            .navigationBarBackButtonHidden(true)
        }
    }
}

#Preview {
    CurrencyOnboardingView()
}
