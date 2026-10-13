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
                        .font(.system(size: 36))
                        .foregroundStyle(Color.appAccent)
                        .frame(width: 80, height: 80)
                        .glassEffect(.regular.tint(Color.appAccent.opacity(0.15)), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .padding(.top, 24)

                    Text("¿En qué moneda quieres usar Max?")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.appTextPrimary)
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
                                        .font(.system(.body, design: .rounded, weight: .semibold))
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
                        .listRowBackground(selected == currency ? Color.appAccent.opacity(0.15) : Color.appCardBackground)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)

                Button {
                    settings.choose(selected)
                } label: {
                    Text("Continuar")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding()
            }
            .background { AppBackground() }
            .navigationBarBackButtonHidden(true)
        }
    }
}

#Preview {
    CurrencyOnboardingView()
}
