import SwiftUI
import UIKit

/// Campo de texto que formatea el monto EN VIVO mientras el usuario escribe,
/// insertando los puntos de miles/millones y la coma decimal según la moneda elegida
/// (ej. escribir 1500000 va mostrando 1, 15, 150... hasta 1.500.000).
///
/// Se implementa envolviendo un UITextField real (UIViewRepresentable) en vez de un
/// TextField nativo de SwiftUI, porque un TextField de SwiftUI con un Binding<String>
/// transformado no siempre refresca lo que se ve en pantalla mientras se está escribiendo
/// en un dispositivo físico (el valor guardado queda bien, pero el texto visible no se
/// actualiza al tipear). Controlando el UITextField directamente evitamos ese problema.
struct AmountField: UIViewRepresentable {
    var placeholder: String = "Monto"
    @Binding var value: Double

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.keyboardType = .numberPad
        textField.placeholder = placeholder
        textField.borderStyle = .none
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.textColor = .label
        textField.delegate = context.coordinator
        textField.inputAccessoryView = context.coordinator.makeAccessoryToolbar()
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange), for: .editingChanged)

        context.coordinator.digits = Coordinator.digits(from: value, currency: CurrencySettings.shared.currency)
        textField.text = context.coordinator.formattedString()

        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self

        // Mientras el usuario está escribiendo (el campo es first responder), no lo tocamos
        // desde afuera para no pelear con lo que está tipeando.
        guard !uiView.isFirstResponder else { return }

        context.coordinator.digits = Coordinator.digits(from: value, currency: CurrencySettings.shared.currency)
        uiView.text = context.coordinator.formattedString()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AmountField
        var digits: String = ""

        init(parent: AmountField) {
            self.parent = parent
        }

        private var currency: AppCurrency { CurrencySettings.shared.currency }

        @objc func textDidChange(_ textField: UITextField) {
            let raw = textField.text ?? ""
            digits = String(raw.filter { $0.isNumber }.prefix(15))
            parent.value = Self.numericValue(fromDigits: digits, currency: currency)

            textField.text = formattedString()
            let endPosition = textField.endOfDocument
            textField.selectedTextRange = textField.textRange(from: endPosition, to: endPosition)
        }

        func makeAccessoryToolbar() -> UIToolbar {
            let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
            let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let done = UIBarButtonItem(title: "Listo", style: .done, target: self, action: #selector(doneTapped))
            toolbar.items = [flexible, done]
            toolbar.sizeToFit()
            return toolbar
        }

        @objc private func doneTapped() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }

        func formattedString() -> String {
            Self.formattedString(fromDigits: digits, currency: currency)
        }

        static func numericValue(fromDigits digits: String, currency: AppCurrency) -> Double {
            guard let intValue = Int(digits) else { return 0 }
            if currency.decimalDigits == 0 {
                return Double(intValue)
            }
            return Double(intValue) / pow(10, Double(currency.decimalDigits))
        }

        static func digits(from value: Double, currency: AppCurrency) -> String {
            guard value > 0 else { return "" }
            if currency.decimalDigits == 0 {
                return String(Int(value.rounded()))
            }
            let minorUnits = Int((value * pow(10, Double(currency.decimalDigits))).rounded())
            return String(minorUnits)
        }

        static func formattedString(fromDigits digits: String, currency: AppCurrency) -> String {
            guard !digits.isEmpty else { return "" }
            let value = numericValue(fromDigits: digits, currency: currency)

            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.usesGroupingSeparator = true
            formatter.groupingSeparator = "."
            formatter.decimalSeparator = ","
            formatter.minimumFractionDigits = currency.decimalDigits
            formatter.maximumFractionDigits = currency.decimalDigits

            return formatter.string(from: NSNumber(value: value)) ?? ""
        }
    }
}

#Preview {
    @Previewable @State var value: Double = 0
    Form {
        AmountField(value: $value)
    }
}
