import SwiftUI

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 44, weight: .semibold))
                            .foregroundStyle(Color.appAccent)
                            .frame(width: 88, height: 88)
                            .glassEffect(.regular.tint(Color.appAccent.opacity(0.15)), in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                        Text("Max")
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.appTextPrimary)

                        Text("Controla tus finanzas sin complicarte")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
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
                    .padding(24)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Radius.xlarge, style: .continuous))
                    .padding(.horizontal, 20)
                }
            }
        }
        .fontDesign(.rounded)
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
