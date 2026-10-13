import SwiftUI

struct AppLockView: View {
    var onUnlock: () -> Void

    @State private var isAuthenticating = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 24) {
                Image(systemName: "faceid")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 96, height: 96)
                    .glassEffect(.regular.tint(Color.appAccent.opacity(0.15)), in: Circle())

                Text("Max está bloqueada")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.appTextPrimary)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.appExpense)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    Task { await attemptUnlock() }
                } label: {
                    if isAuthenticating {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Desbloquear")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isAuthenticating)
                .padding(.horizontal, 40)
            }
        }
        .task {
            await attemptUnlock()
        }
    }

    private func attemptUnlock() async {
        isAuthenticating = true
        errorMessage = nil
        let success = await BiometricAuth.authenticate()
        isAuthenticating = false
        if success {
            onUnlock()
        } else {
            errorMessage = "No se pudo verificar tu identidad. Intenta de nuevo."
        }
    }
}

#Preview {
    AppLockView(onUnlock: {})
}
