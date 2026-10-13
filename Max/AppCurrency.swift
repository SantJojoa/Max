import Foundation

enum AppCurrency: String, CaseIterable, Codable, Identifiable {
    case cop, usd, eur, mxn, ars, clp, pen, brl

    var id: String { rawValue }

    var code: String {
        switch self {
        case .cop: return "COP"
        case .usd: return "USD"
        case .eur: return "EUR"
        case .mxn: return "MXN"
        case .ars: return "ARS"
        case .clp: return "CLP"
        case .pen: return "PEN"
        case .brl: return "BRL"
        }
    }

    var symbol: String {
        switch self {
        case .cop: return "$"
        case .usd: return "US$"
        case .eur: return "€"
        case .mxn: return "MX$"
        case .ars: return "AR$"
        case .clp: return "CL$"
        case .pen: return "S/"
        case .brl: return "R$"
        }
    }

    var displayName: String {
        switch self {
        case .cop: return "Peso colombiano"
        case .usd: return "Dólar estadounidense"
        case .eur: return "Euro"
        case .mxn: return "Peso mexicano"
        case .ars: return "Peso argentino"
        case .clp: return "Peso chileno"
        case .pen: return "Sol peruano"
        case .brl: return "Real brasileño"
        }
    }

    /// Cantidad de decimales que se muestran normalmente para esta moneda.
    var decimalDigits: Int {
        switch self {
        case .cop, .clp:
            return 0
        default:
            return 2
        }
    }
}
