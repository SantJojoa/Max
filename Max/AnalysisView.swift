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
            VStack(spacing: 0) {
                Picker("Sección", selection: $selection) {
                    ForEach(Section.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, Spacing.s)
                .tint(Color.appAccent)

                Group {
                    if selection == .reports {
                        ReportsView()
                    } else {
                        ChartsView()
                    }
                }
            }
            .background(Color.appBackground)
            .navigationTitle("Análisis")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    AnalysisView()
        .modelContainer(for: [Transaction.self, CreditCard.self, CardTransaction.self], inMemory: true)
}
