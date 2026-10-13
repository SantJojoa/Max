//
//  MaxWidgets.swift
//  MaxWidgets
//
//  Created by Santiago Jojoa on 30/08/26.
//

import WidgetKit
import SwiftUI
import AppIntents

private let widgetSuiteName = "group.com.santiago.max"

struct BalanceEntry: TimelineEntry {
    let date: Date
    let income: Double
    let expense: Double
    let balance: Double
}

struct Provider: TimelineProvider {
    private func currentSnapshot() -> BalanceEntry {
        let defaults = UserDefaults(suiteName: widgetSuiteName)
        let income = defaults?.double(forKey: "widget_income") ?? 0
        let expense = defaults?.double(forKey: "widget_expense") ?? 0
        let balance = defaults?.double(forKey: "widget_balance") ?? 0
        return BalanceEntry(date: .now, income: income, expense: expense, balance: balance)
    }

    func placeholder(in context: Context) -> BalanceEntry {
        BalanceEntry(date: .now, income: 0, expense: 0, balance: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (BalanceEntry) -> ()) {
        completion(currentSnapshot())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BalanceEntry>) -> ()) {
        let entry = currentSnapshot()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

private extension Color {
    static let widgetGreen = Color(red: 0.204, green: 0.78, blue: 0.349)
    static let widgetRed = Color(red: 1.0, green: 0.27, blue: 0.227)
    static let widgetMuted = Color(red: 0.61, green: 0.67, blue: 0.80)
}

struct MaxWidgetsEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BALANCE")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(Color.widgetMuted)

                    Text(CurrencyFormat.string(for: entry.balance))
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(entry.balance >= 0 ? Color.white : Color.widgetRed)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }

                Spacer()

                Button(intent: QuickAddIntent()) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 32, height: 32)
                        .background(Color.widgetGreen, in: Circle())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 4)

            HStack(spacing: 4) {
                Image(systemName: "arrow.down.left.circle.fill")
                Text(CurrencyFormat.string(for: entry.income, decimals: 0))
            }
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundStyle(Color.widgetGreen)
            .lineLimit(1)
            .minimumScaleFactor(0.6)

            HStack(spacing: 4) {
                Image(systemName: "arrow.up.right.circle.fill")
                Text(CurrencyFormat.string(for: entry.expense, decimals: 0))
            }
            .font(.system(.caption2, design: .rounded, weight: .semibold))
            .foregroundStyle(Color.widgetRed)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MaxWidgets: Widget {
    let kind: String = "MaxWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MaxWidgetsEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(red: 0.07, green: 0.12, blue: 0.24), Color(red: 0.04, green: 0.07, blue: 0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Balance de Max")
        .description("Muestra tu balance, ingresos y gastos actuales.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    MaxWidgets()
} timeline: {
    BalanceEntry(date: .now, income: 2000000, expense: 1200000, balance: 800000)
}
