//
//  AuthManager.swift
//  Max
//
//  Created by Santiago Jojoa on 29/08/26.
//

import Foundation
import Supabase

@Observable
final class AuthManager {
    static let shared = AuthManager()

    var isAuthenticated = false
    var isLoading = true

    private init() {
        Task {
            await observeAuthChanges()
        }
    }

    @MainActor
    private func observeAuthChanges() async {
        for await (_, session) in supabase.auth.authStateChanges {
            isAuthenticated = session != nil
            isLoading = false
        }
    }

    func signUp(email: String, password: String) async throws {
        try await supabase.auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        try await supabase.auth.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
    }
}
