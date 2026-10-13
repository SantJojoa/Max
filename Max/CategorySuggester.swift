import Foundation

/// Sugiere categorías y movimientos frecuentes a partir del historial del usuario.
enum CategorySuggester {
    struct Sample {
        let note: String
        let category: String
        let isIncome: Bool
        let amount: Double
        let date: Date
        let card: CreditCard?
    }

    struct Frequent: Identifiable {
        var id: String { "\(isIncome)|\(note)|\(category)" }
        let note: String
        let category: String
        let isIncome: Bool
        let amount: Double
        let card: CreditCard?
    }

    // MARK: - Texto

    static func normalize(_ text: String) -> String {
        text.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "(fijo)", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func tokens(_ text: String) -> Set<String> {
        Set(text.split { !$0.isLetter && !$0.isNumber }.map(String.init).filter { $0.count >= 3 })
    }

    // MARK: - Pistas iniciales (sirven desde el primer día, sin historial)

    private static let hints: [(keywords: [String], categories: [String])] = [
        (["rappi", "restaurante", "mcdonald", "burger", "pizza", "cafe", "almuerzo", "cena", "desayuno", "panaderia", "exito", "carulla", "jumbo", "super", "mercado", "tienda", "domicilio", "starbucks"], ["comida", "alimentacion"]),
        (["uber", "didi", "taxi", "gasolina", "peaje", "parqueadero", "bus", "metro", "transmilenio", "cabify", "indrive"], ["transporte"]),
        (["netflix", "spotify", "disney", "hbo", "prime", "youtube", "icloud", "apple", "suscripcion"], ["suscripciones", "entretenimiento"]),
        (["cine", "juego", "steam", "playstation", "concierto", "bar", "fiesta"], ["entretenimiento", "ocio"]),
        (["arriendo", "alquiler", "administracion", "luz", "agua", "gas", "internet", "energia", "predial"], ["vivienda", "hogar"]),
        (["farmacia", "drogueria", "medico", "doctor", "eps", "dentista", "hospital", "cruz verde"], ["salud"]),
        (["zara", "amazon", "mercadolibre", "ropa", "zapatos", "falabella"], ["compras"]),
        (["nomina", "salario", "sueldo", "pago mensual"], ["salario"]),
        (["freelance", "proyecto", "cliente", "honorarios"], ["freelance"]),
        (["regalo", "cumpleanos"], ["regalo"])
    ]

    // MARK: - Sugerir categoría

    /// Devuelve el nombre exacto de una de `available` o nil si no hay una sugerencia confiable.
    static func suggest(note: String, isIncome: Bool, samples: [Sample], available: [String]) -> String? {
        let query = normalize(note)
        guard query.count >= 3 else { return nil }
        let queryTokens = tokens(query)

        func resolve(_ name: String) -> String? {
            let target = normalize(name)
            return available.first { normalize($0) == target }
        }

        var scores: [String: Double] = [:]
        for sample in samples where sample.isIncome == isIncome {
            let other = normalize(sample.note)
            guard !other.isEmpty else { continue }
            if other == query {
                scores[sample.category, default: 0] += 5
            } else {
                let common = tokens(other).intersection(queryTokens)
                if !common.isEmpty {
                    scores[sample.category, default: 0] += 2 * Double(common.count)
                } else if other.contains(query) || query.contains(other) {
                    scores[sample.category, default: 0] += 1.5
                }
            }
        }

        if let best = scores.max(by: { $0.value < $1.value }), best.value >= 2, let name = resolve(best.key) {
            return name
        }

        // Sin historial parecido: usa las pistas integradas.
        for hint in hints where hint.keywords.contains(where: { query.contains($0) }) {
            for category in hint.categories {
                if let name = resolve(category) { return name }
            }
        }
        return nil
    }

    // MARK: - Frecuentes

    static func frequent(samples: [Sample], limit: Int = 4) -> [Frequent] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -120, to: .now) ?? .distantPast
        let recent = samples.filter { $0.date >= cutoff && !normalize($0.note).isEmpty && !$0.category.isEmpty }

        var groups: [String: [Sample]] = [:]
        for sample in recent {
            groups["\(sample.isIncome)|\(normalize(sample.note))|\(sample.category)", default: []].append(sample)
        }

        return groups.values
            .filter { $0.count >= 2 }
            .map { group -> (Frequent, Int, Date) in
                let latest = group.max { $0.date < $1.date }!
                let item = Frequent(note: latest.note.replacingOccurrences(of: " (fijo)", with: ""),
                                    category: latest.category,
                                    isIncome: latest.isIncome,
                                    amount: latest.amount,
                                    card: latest.card)
                return (item, group.count, latest.date)
            }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.2 > $1.2 }
            .prefix(limit)
            .map(\.0)
    }
}
