import Foundation

@Observable
final class CurrencySettings {
    static let shared = CurrencySettings()

    private static let suiteName = "group.com.santiago.max"
    private static let currencyKey = "selectedCurrency"
    private static let hasChosenKey = "hasChosenCurrency"

    private let defaults = UserDefaults(suiteName: CurrencySettings.suiteName) ?? .standard

    private init() {
        if let saved = defaults.string(forKey: Self.currencyKey), let match = AppCurrency(rawValue: saved) {
            currency = match
        } else {
            currency = .cop
        }
        hasChosenCurrency = defaults.bool(forKey: Self.hasChosenKey)
    }

    var currency: AppCurrency {
        didSet {
            defaults.set(currency.rawValue, forKey: Self.currencyKey)
        }
    }

    var hasChosenCurrency: Bool {
        didSet {
            defaults.set(hasChosenCurrency, forKey: Self.hasChosenKey)
        }
    }

    func choose(_ currency: AppCurrency) {
        self.currency = currency
        hasChosenCurrency = true
    }
}
