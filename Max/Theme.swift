//
//  Theme.swift
//  Max
//
//  Created by Santiago Jojoa on 30/08/26.
//

import SwiftUI

// MARK: - Colores

extension Color {
    /// Color que cambia entre claro y oscuro (el diseño es "dark first").
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }

    static let appAccent = dynamic(light: 0x34C759, dark: 0x34C759)
    static let appBackground = dynamic(light: 0xF2F2F7, dark: 0x0A1224)
    static let appCardBackground = dynamic(light: 0xFFFFFF, dark: 0x131D36)
    /// Superficie sobre una tarjeta (pills, campos, teclas).
    static let appElevated = dynamic(light: 0xF2F2F7, dark: 0x1D2A4A)
    static let appElevatedHigh = dynamic(light: 0xE5E5EA, dark: 0x2A3B64)
    static let appTextPrimary = dynamic(light: 0x0B1020, dark: 0xF4F7FF)
    static let appTextSecondary = dynamic(light: 0x5F6B85, dark: 0x9CAACB)
    static let appIncome = dynamic(light: 0x34C759, dark: 0x34C759)
    static let appExpense = dynamic(light: 0xFF3B30, dark: 0xFF453A)
    static let appBlue = dynamic(light: 0x007AFF, dark: 0x0A84FF)
    static let appOrange = dynamic(light: 0xFF9500, dark: 0xFF9F0A)
    static let appPurple = dynamic(light: 0xAF52DE, dark: 0xBF5AF2)
    static let appPink = dynamic(light: 0xFF2D55, dark: 0xFF375F)
    static let appHairline = dynamic(light: 0xD1D5E0, dark: 0x2A3A5E)
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
    static let small: CGFloat = 12
    static let medium: CGFloat = 16
    static let large: CGFloat = 20
    static let xlarge: CGFloat = 24
}

// MARK: - Estilo de "tarjeta" para agrupar contenido

struct CardBackground: ViewModifier {
    var elevated: Bool = false

    func body(content: Content) -> some View {
        if elevated {
            content
                .padding()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        } else {
            content
                .padding()
                .background(Color.appCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                }
        }
    }
}

/// Fondo de pantalla: azul noche con manchas de color suaves para que el cristal "líquido" tenga qué refractar.
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Color.appBackground
            if scheme == .dark {
                Circle()
                    .fill(Color.appBlue.opacity(0.35))
                    .frame(width: 320, height: 320)
                    .blur(radius: 90)
                    .offset(x: 140, y: -260)
                Circle()
                    .fill(Color.appAccent.opacity(0.18))
                    .frame(width: 280, height: 280)
                    .blur(radius: 90)
                    .offset(x: -170, y: -90)
                Circle()
                    .fill(Color.appPurple.opacity(0.18))
                    .frame(width: 300, height: 300)
                    .blur(radius: 100)
                    .offset(x: 150, y: 300)
            }
        }
        .ignoresSafeArea()
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


// MARK: - Estilo visual por categoría (ícono SF Symbol + color)

enum CategoryStyle {
    static func symbol(for name: String) -> String {
        switch name.lowercased() {
        case "comida", "alimentación", "alimentacion": return "fork.knife"
        case "transporte": return "car.fill"
        case "vivienda", "hogar": return "house.fill"
        case "entretenimiento", "ocio": return "gamecontroller.fill"
        case "salud": return "cross.case.fill"
        case "compras": return "bag.fill"
        case "suscripciones": return "repeat"
        case "salario": return "banknote.fill"
        case "freelance": return "laptopcomputer"
        case "regalo": return "gift.fill"
        case "otros": return "ellipsis"
        default: return "tag.fill"
        }
    }

    static func color(for name: String) -> Color {
        switch name.lowercased() {
        case "comida", "alimentación", "alimentacion": return .appOrange
        case "transporte": return .appBlue
        case "vivienda", "hogar": return .appPurple
        case "entretenimiento", "ocio": return .appPink
        case "salud": return .appAccent
        case "compras": return .appPink
        case "suscripciones": return .appBlue
        case "salario": return .appAccent
        case "freelance": return .appBlue
        case "regalo": return .appOrange
        default: return .appTextSecondary
        }
    }
}

/// Cuadro redondeado translúcido con el ícono de una categoría.
struct CategoryIcon: View {
    let name: String
    var size: CGFloat = 40

    var body: some View {
        let tint = CategoryStyle.color(for: name)
        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(tint.opacity(0.18))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: CategoryStyle.symbol(for: name))
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(tint)
            }
    }
}

// MARK: - Barra de progreso redondeada (estilo Fitness)

struct CapsuleProgress: View {
    var value: Double
    var tint: Color = .appAccent
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.appElevated)
                Capsule()
                    .fill(tint)
                    .frame(width: max(height, geo.size.width * CGFloat(min(max(value, 0), 1))))
            }
        }
        .frame(height: height)
    }
}
