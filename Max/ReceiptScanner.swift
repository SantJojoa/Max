import SwiftUI
import UIKit
import Vision
import VisionKit

// MARK: - Cámara de documentos

struct DocumentScanner: UIViewControllerRepresentable {
    var onScan: (UIImage) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        init(parent: DocumentScanner) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            if scan.pageCount > 0 { parent.onScan(scan.imageOfPage(at: 0)) } else { parent.onCancel() }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onCancel()
        }
    }
}

// MARK: - Lectura (OCR) del recibo

struct ReceiptInfo {
    var amount: Double?
    var merchant: String?
}

enum ReceiptReader {
    /// Reduce y comprime la imagen para guardarla con la transacción.
    static func compressed(_ image: UIImage, maxSide: CGFloat = 1600) -> Data? {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.7)
    }

    static func read(_ image: UIImage, decimals: Int) async -> ReceiptInfo {
        guard let cgImage = image.cgImage else { return ReceiptInfo() }
        let lines: [String] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["es-ES", "en-US"]
                request.usesLanguageCorrection = false
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .init(image.imageOrientation), options: [:])
                try? handler.perform([request])
                let results = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: results)
            }
        }
        return parse(lines: lines, decimals: decimals)
    }

    // MARK: Parsing

    static func parse(lines: [String], decimals: Int) -> ReceiptInfo {
        var info = ReceiptInfo()

        // Comercio: primera línea con letras que no sea solo números/fechas.
        info.merchant = lines.first { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let letters = trimmed.filter(\.isLetter).count
            return trimmed.count >= 3 && letters >= 3 && letters * 2 >= trimmed.count
        }?.trimmingCharacters(in: .whitespaces).capitalized

        // Montos
        var totals: [Double] = []
        var all: [Double] = []

        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            let values = amounts(in: line, decimals: decimals)
            all += values

            if lower.contains("total") && !lower.contains("subtotal") && !lower.contains("sub total") {
                var found = values
                if found.isEmpty, index + 1 < lines.count {
                    found = amounts(in: lines[index + 1], decimals: decimals)
                }
                totals += found
            }
        }

        info.amount = totals.max() ?? all.max()
        return info
    }

    private static func amounts(in line: String, decimals: Int) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: "[0-9][0-9.,]*[0-9]|[0-9]") else { return [] }
        let range = NSRange(line.startIndex..., in: line)
        return regex.matches(in: line, range: range).compactMap { match -> Double? in
            guard let r = Range(match.range, in: line) else { return nil }
            let token = String(line[r])
            let hasSeparator = token.contains(".") || token.contains(",")
            // Sin separadores y muy largos: casi seguro un NIT, teléfono o código de barras.
            if !hasSeparator && token.count > 7 { return nil }
            guard let value = normalize(token, decimals: decimals), value > 0, value < 1_000_000_000 else { return nil }
            return value
        }
    }

    private static func normalize(_ token: String, decimals: Int) -> Double? {
        let hasDot = token.contains(".")
        let hasComma = token.contains(",")
        var cleaned = token

        if hasDot && hasComma {
            let lastDot = token.lastIndex(of: ".")!
            let lastComma = token.lastIndex(of: ",")!
            let decimalSep: Character = lastDot > lastComma ? "." : ","
            let thousandSep: Character = decimalSep == "." ? "," : "."
            cleaned = token.replacingOccurrences(of: String(thousandSep), with: "")
            cleaned = cleaned.replacingOccurrences(of: String(decimalSep), with: ".")
        } else if hasDot || hasComma {
            let sep: Character = hasDot ? "." : ","
            let parts = token.split(separator: sep, omittingEmptySubsequences: false)
            if parts.count > 2 {
                cleaned = parts.joined()
            } else if let last = parts.last, last.count == 3 || decimals == 0 && last.count != 2 {
                cleaned = parts.joined()
            } else {
                cleaned = parts.joined(separator: ".")
            }
        }
        return Double(cleaned)
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
