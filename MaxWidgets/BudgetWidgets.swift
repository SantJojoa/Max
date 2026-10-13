//
//  BudgetWidgets.swift
//  MaxWidgets
//
//  Widgets de presupuesto restante y gasto del día.
//

import WidgetKit
import SwiftUI

private let budgetSuite = "group.com.santiago.max"

struct BudgetEntry: TimelineEntry {
    let date: Date
    let total: Double
    let spent: Double
    let spentToday: Double
    let dailyAllowance: Double

    var remaining: Double { max(0, total - spent) }
    var ratio: Double { total > 0 ? min(spent / total, 1) : 0 }
}

struct BudgetProvider: TimelineProvider {
    private func snapshot() -> BudgetEntry {
        let defaults = UserDefaults(suiteName: budgetSuite)
        return BudgetEntry(
            date: .now,
            total: defaults?.double(forKey: "widget_budget_total") ?? 0,
            spent: defaults?.double(forKey: "widget_budget_spent") ?? 0,
            spentToday: defaults?.double(forKey: "widget_spent_today") ?? 0,
            dailyAllowance: defaults?.double(forKey: "widget_daily_allowance") ?? 0
        )
    }

    func placeholder(in context: Context) -> BudgetEntry {
        BudgetEntry(date: .now, total: 0, spent: 0, spentToday: 0, dailyAllowance: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> ()) {
        completion(snapshot())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> ()) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [snapshot()], policy: .after(next)))
    }
}

private extension Color {
    static let bwGreen = Color(red: 0.204, green: 0.78, blue: 0.349)
    static let bwOrange = Color(red: 1.0, green: 0.62, blue: 0.04)
    static let bwRed = Color(red: 1.0, green: 0.27, blue: 0.227)
    static let bwMuted = Color(red: 0.61, green: 0.67, blue: 0.80)
}

private struct WidgetBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(red: 0.07, green: 0.12, blue: 0.24), Color(red: 0.04, green: 0.07, blue: 0.14)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Presupuesto restante

struct BudgetRemainingView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BudgetEntry

    private var tint: Color {
        entry.ratio >= 1 ? .bwRed : (entry.ratio >= 0.8 ? .bwOrange : .bwGreen)
    }

    var body: some View {
        if family == .accessoryCircular {
            Gauge(value: entry.ratio) {
                Image(systemName: "chart.pie.fill")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        } else if entry.total == 0 {
            VStack(spacing: 6) {
                Image(systemName: "chart.pie")
                    .font(.title2)
                    .foregroundStyle(Color.bwMuted)
                Text("Crea un presupuesto en Max")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.bwMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(tint.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: entry.ratio)
                        .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(entry.ratio, format: .percent.precision(.fractionLength(0)))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: family == .systemSmall ? 62 : 76, height: family == .systemSmall ? 62 : 76)

                VStack(alignment: .leading, spacing: 3) {
                    Text("QUEDAN")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(Color.bwMuted)
                    Text(CurrencyFormat.string(for: entry.remaining, decimals: 0))
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("\(CurrencyFormat.string(for: entry.dailyAllowance, decimals: 0)) al día")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(tint)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(family == .systemSmall ? 4 : 8)
        }
    }
}

struct BudgetRemainingWidget: Widget {
    let kind = "BudgetRemainingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetProvider()) { entry in
            BudgetRemainingView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("Presupuesto restante")
        .description("Cuánto te queda del presupuesto del mes y cuánto puedes gastar al día.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

// MARK: - Gasto del día

struct TodaySpendingView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BudgetEntry

    private var overAllowance: Bool {
        entry.dailyAllowance > 0 && entry.spentToday > entry.dailyAllowance
    }

    private var ratio: Double {
        entry.dailyAllowance > 0 ? min(entry.spentToday / entry.dailyAllowance, 1) : 0
    }

    var body: some View {
        if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 2) {
                Text("Gasto de hoy")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(CurrencyFormat.string(for: entry.spentToday, decimals: 0))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if entry.dailyAllowance > 0 {
                    Gauge(value: ratio) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("HOY")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(Color.bwMuted)
                Text(CurrencyFormat.string(for: entry.spentToday, decimals: 0))
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(overAllowance ? Color.bwRed : .white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                Spacer(minLength: 2)

                if entry.dailyAllowance > 0 {
                    ProgressView(value: ratio)
                        .tint(overAllowance ? Color.bwRed : Color.bwGreen)
                    Text(overAllowance
                         ? "Pasaste tu límite diario"
                         : "De \(CurrencyFormat.string(for: entry.dailyAllowance, decimals: 0)) disponibles")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(Color.bwMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                } else {
                    Text(entry.spentToday == 0 ? "Sin gastos hoy" : "Gastado hoy")
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(Color.bwMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        }
    }
}

struct TodaySpendingWidget: Widget {
    let kind = "TodaySpendingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetProvider()) { entry in
            TodaySpendingView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("Gasto de hoy")
        .description("Cuánto has gastado hoy frente a tu límite diario.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}
