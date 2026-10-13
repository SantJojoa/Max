//
//  SettingsView.swift
//  Max
//
//  Created by Santiago Jojoa on 29/08/26.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isSigningOut = false
    @State private var syncManager = SyncManager.shared

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                        .frame(width: 64, height: 64)
                        .glassEffect(.regular.tint(Color.appAccent.opacity(0.15)), in: Circle())

                    Button {
                        Task {
                            await SyncManager.shared.syncAll(context: modelContext)
                        }
                    } label: {
                        if syncManager.isSyncing {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Sincronizar ahora")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(syncManager.isSyncing)

                    if let error = syncManager.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.appExpense)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.appCardBackground)

            Section {
                NavigationLink {
                    CategoriesView()
                } label: {
                    settingsRow(title: "Gestionar categorías", icon: "tag.fill", tint: .appOrange)
                }
                NavigationLink {
                    CurrencySettingsView()
                } label: {
                    settingsRow(title: "Moneda", icon: "banknote.fill", tint: .appAccent)
                }
            }
            .listRowBackground(Color.appCardBackground)

            Section {
                settingsRow(
                    title: "Bloqueo con Face ID / Touch ID",
                    icon: "lock.fill",
                    tint: .gray,
                    trailing: "Activado"
                )
            } header: {
                Text("Seguridad")
            }
            .listRowBackground(Color.appCardBackground)

            Section {
                Button(role: .destructive) {
                    Task {
                        isSigningOut = true
                        try? await AuthManager.shared.signOut()
                        isSigningOut = false
                    }
                } label: {
                    HStack {
                        Spacer()
                        if isSigningOut {
                            ProgressView()
                        } else {
                            Text("Cerrar sesión")
                                .foregroundStyle(Color.appExpense)
                        }
                        Spacer()
                    }
                }
            }
            .listRowBackground(Color.appCardBackground)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .navigationTitle("Cuenta")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func settingsRow(title: String, icon: String, tint: Color, trailing: String? = nil) -> some View {
        HStack(spacing: Spacing.m) {
            IconBadge(systemImage: icon, tint: tint)
            Text(title)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(Color.appTextPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.subheadline)
                    .foregroundStyle(Color.appTextSecondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
