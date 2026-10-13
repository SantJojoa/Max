//
//  MaxWidgetsControl.swift
//  MaxWidgets
//
//  Botón para Centro de control / pantalla de bloqueo que abre Max directo en "Nueva transacción".
//

import AppIntents
import SwiftUI
import WidgetKit

struct MaxWidgetsControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.santiagojojoa.Max.QuickAddControl") {
            ControlWidgetButton(action: QuickAddIntent()) {
                Label("Nuevo gasto", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Nuevo gasto")
        .description("Abre Max para registrar un movimiento en un toque.")
    }
}
