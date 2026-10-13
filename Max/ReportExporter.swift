import SwiftUI
import UIKit

/// Un movimiento ya normalizado para exportar (efectivo o tarjeta).
struct ReportRow {
    let date: Date
    let kind: String      // Ingreso, Gasto, Compra, Pago
    let source: String    // Efectivo o nombre de la tarjeta
    let category: String
    let note: String
    let amount: Double
    let isPositive: Bool  // suma al balance (ingreso o pago)
}

struct ReportSnapshot {
    let periodTitle: String
    let rows: [ReportRow]

    var income: Double { rows.filter { $0.kind == "Ingreso" }.reduce(0) { $0 + $1.amount } }
    var expense: Double { rows.filter { $0.kind == "Gasto" }.reduce(0) { $0 + $1.amount } }
    var cardPurchases: Double { rows.filter { $0.kind == "Compra" }.reduce(0) { $0 + $1.amount } }
    var cardPayments: Double { rows.filter { $0.kind == "Pago" }.reduce(0) { $0 + $1.amount } }
    var balance: Double { income - expense }
    var savingsPercent: Double { income > 0 ? balance / income * 100 : 0 }

    /// Gastos (efectivo + compras con tarjeta) agrupados por categoría.
    var spendingByCategory: [(category: String, total: Double)] {
        let spending = rows.filter { $0.kind == "Gasto" || $0.kind == "Compra" }
        return Dictionary(grouping: spending, by: { $0.category.isEmpty ? "Sin categoría" : $0.category })
            .map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }
}

enum ReportExporter {
    private static func fileName(_ snapshot: ReportSnapshot, ext: String) -> String {
        let safe = snapshot.periodTitle
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: " ", with: "-")
        return "Max-Reporte-\(safe).\(ext)"
    }

    private static func tempURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(name)
    }

    private static func plainNumber(_ value: Double) -> String {
        let currency = CurrencySettings.shared.currency
        return String(format: "%.\(currency.decimalDigits)f", value)
    }

    // MARK: - CSV

    static func csv(for snapshot: ReportSnapshot) throws -> URL {
        func esc(_ text: String) -> String {
            let needsQuotes = text.contains(",") || text.contains("\"") || text.contains("\n")
            let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
            return needsQuotes ? "\"\(escaped)\"" : escaped
        }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        var lines = ["Fecha,Tipo,Origen,Categoría,Nota,Monto"]
        for row in snapshot.rows.sorted(by: { $0.date < $1.date }) {
            let signed = row.isPositive ? row.amount : -row.amount
            lines.append([
                dayFormatter.string(from: row.date),
                row.kind,
                row.source,
                row.category,
                row.note,
                plainNumber(signed)
            ].map(esc).joined(separator: ","))
        }
        lines.append("")
        lines.append("Resumen,\(esc(snapshot.periodTitle))")
        lines.append("Ingresos,,,,,\(plainNumber(snapshot.income))")
        lines.append("Gastos,,,,,\(plainNumber(snapshot.expense))")
        lines.append("Balance,,,,,\(plainNumber(snapshot.balance))")
        lines.append("Compras con tarjeta,,,,,\(plainNumber(snapshot.cardPurchases))")
        lines.append("Pagos de tarjeta,,,,,\(plainNumber(snapshot.cardPayments))")

        // BOM para que Excel abra bien los acentos.
        let content = "\u{FEFF}" + lines.joined(separator: "\n")
        let url = tempURL(fileName(snapshot, ext: "csv"))
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: - PDF

    static func pdf(for snapshot: ReportSnapshot) throws -> URL {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 40
        let contentWidth = pageRect.width - margin * 2
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let navy = UIColor(red: 0.04, green: 0.07, blue: 0.14, alpha: 1)
        let green = UIColor(red: 0.20, green: 0.70, blue: 0.30, alpha: 1)
        let red = UIColor(red: 0.88, green: 0.22, blue: 0.19, alpha: 1)
        let gray = UIColor(white: 0.45, alpha: 1)

        func attrs(_ size: CGFloat, _ weight: UIFont.Weight = .regular, _ color: UIColor = .black, align: NSTextAlignment = .left) -> [NSAttributedString.Key: Any] {
            let style = NSMutableParagraphStyle()
            style.alignment = align
            style.lineBreakMode = .byTruncatingTail
            return [
                .font: UIFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: color,
                .paragraphStyle: style
            ]
        }

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "dd/MM/yy"

        let data = renderer.pdfData { context in
            var y: CGFloat = 0

            func newPage() {
                context.beginPage()
                y = margin
            }

            func ensureSpace(_ height: CGFloat) {
                if y + height > pageRect.height - margin { newPage() }
            }

            func text(_ string: String, x: CGFloat, width: CGFloat, attributes: [NSAttributedString.Key: Any], height: CGFloat = 16) {
                (string as NSString).draw(in: CGRect(x: x, y: y, width: width, height: height), withAttributes: attributes)
            }

            newPage()

            // Encabezado
            let header = CGRect(x: 0, y: 0, width: pageRect.width, height: 96)
            navy.setFill()
            UIRectFill(header)
            ("Max" as NSString).draw(at: CGPoint(x: margin, y: 28), withAttributes: attrs(26, .heavy, .white))
            ("Reporte financiero · \(snapshot.periodTitle)" as NSString)
                .draw(at: CGPoint(x: margin, y: 62), withAttributes: attrs(13, .medium, UIColor(white: 0.8, alpha: 1)))
            y = 120

            // Resumen
            ("Resumen" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attrs(15, .bold))
            y += 26
            let summary: [(String, String, UIColor)] = [
                ("Ingresos", CurrencyFormat.string(for: snapshot.income), green),
                ("Gastos", CurrencyFormat.string(for: snapshot.expense), red),
                ("Balance", CurrencyFormat.string(for: snapshot.balance), snapshot.balance >= 0 ? green : red),
                ("% Ahorrado", String(format: "%.1f%%", snapshot.savingsPercent), .black),
                ("Compras con tarjeta", CurrencyFormat.string(for: snapshot.cardPurchases), .black),
                ("Pagos de tarjeta", CurrencyFormat.string(for: snapshot.cardPayments), .black)
            ]
            for item in summary {
                text(item.0, x: margin, width: 250, attributes: attrs(12, .regular, gray))
                text(item.1, x: margin + 250, width: contentWidth - 250, attributes: attrs(12, .semibold, item.2, align: .right))
                y += 20
            }
            y += 14

            // Gastos por categoría
            let categories = snapshot.spendingByCategory
            if !categories.isEmpty {
                ensureSpace(60)
                ("Gastos por categoría" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attrs(15, .bold))
                y += 26
                let total = categories.reduce(0) { $0 + $1.total }
                for item in categories.prefix(10) {
                    ensureSpace(26)
                    let share = total > 0 ? item.total / total : 0
                    text(item.category, x: margin, width: 150, attributes: attrs(12))
                    // barra
                    UIColor(white: 0.9, alpha: 1).setFill()
                    UIBezierPath(roundedRect: CGRect(x: margin + 160, y: y + 3, width: 170, height: 8), cornerRadius: 4).fill()
                    green.setFill()
                    UIBezierPath(roundedRect: CGRect(x: margin + 160, y: y + 3, width: max(6, 170 * share), height: 8), cornerRadius: 4).fill()
                    text(String(format: "%.0f%%", share * 100), x: margin + 340, width: 40, attributes: attrs(11, .regular, gray, align: .right))
                    text(CurrencyFormat.string(for: item.total), x: margin + 385, width: contentWidth - 385, attributes: attrs(12, .semibold, .black, align: .right))
                    y += 22
                }
                y += 14
            }

            // Movimientos
            ensureSpace(60)
            ("Movimientos (\(snapshot.rows.count))" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: attrs(15, .bold))
            y += 26

            func drawTableHeader() {
                UIColor(white: 0.93, alpha: 1).setFill()
                UIRectFill(CGRect(x: margin, y: y - 3, width: contentWidth, height: 20))
                text("Fecha", x: margin + 6, width: 60, attributes: attrs(10, .bold, gray))
                text("Tipo", x: margin + 70, width: 55, attributes: attrs(10, .bold, gray))
                text("Categoría / nota", x: margin + 130, width: 250, attributes: attrs(10, .bold, gray))
                text("Monto", x: margin + 390, width: contentWidth - 396, attributes: attrs(10, .bold, gray, align: .right))
                y += 22
            }
            drawTableHeader()

            if snapshot.rows.isEmpty {
                text("Sin movimientos en este periodo.", x: margin + 6, width: contentWidth, attributes: attrs(12, .regular, gray))
            }

            for row in snapshot.rows.sorted(by: { $0.date > $1.date }) {
                if y + 22 > pageRect.height - margin {
                    newPage()
                    drawTableHeader()
                }
                let detail = row.note.isEmpty ? row.category : "\(row.category) · \(row.note)"
                text(dayFormatter.string(from: row.date), x: margin + 6, width: 60, attributes: attrs(11))
                text(row.kind, x: margin + 70, width: 55, attributes: attrs(11, .medium, gray))
                text(detail, x: margin + 130, width: 250, attributes: attrs(11))
                let sign = row.isPositive ? "+" : "-"
                text("\(sign)\(CurrencyFormat.string(for: row.amount))", x: margin + 390, width: contentWidth - 396,
                     attributes: attrs(11, .semibold, row.isPositive ? green : .black, align: .right))
                y += 20
                UIColor(white: 0.93, alpha: 1).setFill()
                UIRectFill(CGRect(x: margin, y: y - 3, width: contentWidth, height: 0.5))
            }

            // Pie
            let footer = "Generado con Max · \(Date.now.formatted(date: .abbreviated, time: .shortened))"
            (footer as NSString).draw(at: CGPoint(x: margin, y: pageRect.height - 28), withAttributes: attrs(9, .regular, gray))
        }

        let url = tempURL(fileName(snapshot, ext: "pdf"))
        try data.write(to: url, options: .atomic)
        return url
    }
}

// MARK: - Hoja de compartir

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
