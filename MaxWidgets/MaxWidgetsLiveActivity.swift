//
//  MaxWidgetsLiveActivity.swift
//  MaxWidgets
//
//  Live Activity: gasto de hoy frente al límite diario.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct SpendingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SpendingActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color(red: 0.05, green: 0.09, blue: 0.18))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            let tint: Color = state.overLimit ? .red : .green

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Hoy", systemImage: "arrow.up.right")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let allowance = state.allowanceText {
                        Text("de \(allowance)")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.spentText)
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if state.allowanceText != nil {
                        ProgressView(value: state.ratio)
                            .tint(tint)
                    }
                }
            } compactLeading: {
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(tint)
            } compactTrailing: {
                Text(state.spentText)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            } minimal: {
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(tint)
            }
        }
    }
}

private struct LockScreenView: View {
    let state: SpendingActivityAttributes.ContentState

    var body: some View {
        let tint: Color = state.overLimit ? Color(red: 1, green: 0.27, blue: 0.23) : Color(red: 0.2, green: 0.78, blue: 0.35)

        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("GASTO DE HOY")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(Color(red: 0.61, green: 0.67, blue: 0.8))
                Text(state.spentText)
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(state.overLimit ? tint : .white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let allowance = state.allowanceText {
                    Text(state.overLimit ? "Pasaste tu límite de \(allowance)" : "De \(allowance) disponibles al día")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(Color(red: 0.61, green: 0.67, blue: 0.8))
                }
            }
            Spacer(minLength: 0)
            if state.allowanceText != nil {
                ZStack {
                    Circle().stroke(tint.opacity(0.25), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: state.ratio)
                        .stroke(tint, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(state.ratio, format: .percent.precision(.fractionLength(0)))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 56, height: 56)
            }
        }
        .padding(16)
    }
}
