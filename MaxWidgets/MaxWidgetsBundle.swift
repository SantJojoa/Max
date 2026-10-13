//
//  MaxWidgetsBundle.swift
//  MaxWidgets
//
//  Created by Santiago Jojoa on 30/08/26.
//

import WidgetKit
import SwiftUI

@main
struct MaxWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MaxWidgets()
        BudgetRemainingWidget()
        TodaySpendingWidget()
        MaxWidgetsControl()
        SpendingLiveActivity()
    }
}
