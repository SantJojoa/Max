//
//  Theme.swift
//  Max
//
//  Created by Santiago Jojoa on 30/08/26.
//

import SwiftUI

// MARK: - Colores

extension Color {
    static let appAccent = Color(.systemGreen)
    static let appBackground = Color(.systemGroupedBackground)
    static let appCardBackground = Color(.secondarySystemGroupedBackground)
    static let appTextPrimary = Color(.label)
    static let appTextSecondary = Color(.secondaryLabel)
    static let appIncome = Color(.systemGreen)
    static let appExpense = Color(.systemRed)
}

// MARK: - Escala de espaciado

enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - Escala de radios

enum Radius {
    static let badge: CGFloat = 8
    static let small: CGFloat = 10
    static let medium: CGFloat = 14
    static let large: CGFloat = 16
}

// MARK: - Estilo de "tarjeta" para agrupar contenido

struct CardBackground: ViewModifier {
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .modifier(SubtleShadow(active: elevated))
    }
}

extension View {
    /// Estilo de tarjeta plano, pensado para filas dentro de listas `.insetGrouped`.
    func cardStyle() -> some View {
        modifier(CardBackground(elevated: false))
    }

    /// Variante con una sombra sutil, para tarjetas "flotantes" sobre el fondo
    /// (pantallas tipo Wallet: Tarjetas, Planificación).
    func floatingCardStyle() -> some View {
        modifier(CardBackground(elevated: true))
    }
}

// MARK: - Sombra sutil (elevación estilo Apple, muy discreta)

struct SubtleShadow: ViewModifier {
    var active: Bool = true

    func body(content: Content) -> some View {
        if active {
            content.shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        } else {
            content
        }
    }
}

extension View {
    func subtleShadow() -> some View {
        modifier(SubtleShadow())
    }
}

// MARK: - Insignia de ícono (cuadro de color redondeado con SF Symbol, estilo Ajustes.app)

struct IconBadge: View {
    let systemImage: String
    var tint: Color = .appAccent
    var size: CGFloat = 29

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.badge, style: .continuous)
            .fill(tint)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.55, weight: .medium))
                    .foregroundStyle(.white)
            }
    }
}

// MARK: - Botón principal (verde, redondeado)

struct PrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isDisabled ? Color.gray.opacity(0.4) : Color.appAccent)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Campo de texto redondeado

struct AppTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(14)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
