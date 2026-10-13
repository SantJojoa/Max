import LocalAuthentication

enum BiometricAuth {
    static func authenticate() async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // El dispositivo no tiene Face ID/Touch ID/código configurado: dejamos pasar.
            return true
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Desbloquea Max para ver tus finanzas"
            )
        } catch {
            return false
        }
    }
}
