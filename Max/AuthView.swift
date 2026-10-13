import SwiftUI

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.appAccent)

                        Text("Max")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color.appTextPrimary)

                        Text("Controla tus finanzas")
                            .font(.subheadline)
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .padding(.top, 60)

                    VStack(spacing: 16) {
                        TextField("Correo electrónico", text: $email)
                            .textFieldStyle(AppTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)

                        SecureField("Contraseña", text: $password)
                            .textFieldStyle(AppTextFieldStyle())

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(Color.appExpense)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text(isSignUp ? "Crear cuenta" : "Iniciar sesión")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle(isDisabled: !canSubmit))
                        .disabled(!canSubmit || isLoading)

                        Button {
                            isSignUp.toggle()
                            errorMessage = nil
                        } label: {
                            Text(isSignUp ? "¿Ya tienes cuenta? Inicia sesión" : "¿No tienes cuenta? Regístrate")
                                .font(.footnote)
                                .foregroundStyle(Color.appAccent)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
    }

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty
    }

    private func submit() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            if isSignUp {
                try await AuthManager.shared.signUp(email: email, password: password)
            } else {
                try await AuthManager.shared.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
