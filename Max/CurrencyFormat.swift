import Foundation

enum CurrencyFormat {
    /// Formatea un monto con el símbolo de la moneda elegida, punto como separador de miles/millones
    /// y coma como separador decimal (ej. "$ 1.234.567,89").
    static func string(for amount: Double, currency: AppCurrency? = nil, decimals: Int? = nil) -> String {
        let currency = currency ?? CurrencySettings.shared.currency
        let digits = decimals ?? currency.decimalDigits

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits

        let numberString = formatter.string(from: NSNumber(value: amount)) ?? "0"
        return "\(currency.symbol) \(numberString)"
    }
}
