import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Category> { !$0.isDeleted }, sort: \Category.name) private var categories: [Category]
    @State private var showingAdd = false
    @State private var editingCategory: Category?
    @State private var selectedScope: CategoryScope = .expense

    private var filteredCategories: [Category] {
        categories.filter { $0.scope == selectedScope }
    }

    var body: some View {
        List {
            Section {
                Picker("Tipo", selection: $selectedScope) {
                    ForEach(CategoryScope.allCases, id: \.self) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                if filteredCategories.isEmpty {
                    Text("Sin categorías. Toca + para agregar una.")
                        .foregroundStyle(Color.appTextSecondary)
                } else {
                    ForEach(filteredCategories) { category in
                        Text(category.name)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingCategory = category
                            }
                    }
                    .onDelete(perform: deleteCategories)
                }
            }
            .listRowBackground(Color.appCardBackground)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background { AppBackground() }
        .tint(Color.appAccent)
        .navigationTitle("Categorías")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddCategoryView(defaultScope: selectedScope)
        }
        .sheet(item: $editingCategory) { category in
            AddCategoryView(categoryToEdit: category)
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            let category = filteredCategories[index]
            category.isDeleted = true
            category.updatedAt = .now
            category.needsSync = true
        }
    }
}

#Preview {
    NavigationStack {
        CategoriesView()
    }
    .modelContainer(for: Category.self, inMemory: true)
}
