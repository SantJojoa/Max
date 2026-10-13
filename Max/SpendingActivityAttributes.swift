import ActivityKit
import Foundation

/// Compartido entre la app y la extensión de widgets (Live Activity del gasto del día).
struct SpendingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var spentText: String
        var allowanceText: String?
        var ratio: Double
        var overLimit: Bool
    }

    var title: String
}
