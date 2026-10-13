import SwiftUI
import SwiftData

struct AnalysisView: View {
    private enum Section: String, CaseIterable {
        case reports = "Reportes"
        case charts = "Gráficas"
    }

    @State private var selection: Section = .reports

    var body: some View {
        NavigationStack {
            Group {
                if selection == .reports {
                    ReportsView()
                } else {
                    ChartsView()
                }
            }
            .background { AppBackground() }
            .navigationTitle("Análisis")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    sectionButton(.reports, icon: "doc.text.fill", label: "Reportes")
                    sectionButton(.charts, icon: "chart.pie.fill", label: "Gráficas")
                }
            }
        }
    }

    private func sectionButton(_ section: Section, icon: String, label: String) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { selection = section }
        } label: {
            Image(systemName: icon)
                .foregroundStyle(selection == section ? Color.appAccent : Color.appTextSecondary)
        }
        .accessibilityLabel(label)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview {
    AnalysisView()
        .modelContainer(for: [Transaction.self, CreditCard.self, CardTransaction.self], inMemory: true)
}
