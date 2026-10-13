import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var categoryToEdit: Category?
    var defaultScope: CategoryScope = .expense

    @State private var name: String = ""
    @State private var scope: CategoryScope = .expense
    @State private var emoji: String = ""

    private static let suggestions = ["🍔","🍕","☕️","🛒","🚗","⛽️","🚌","🏠","💡","📱","🎮","🎬","🎵","✈️","🏖️","💊","🏥","🏋️","👕","🛍️","🎁","💰","💻","📚","🎓","🐶","👶","🔧","💇","🍺","🧾","⭐️"]

    private var isEditing: Bool { categoryToEdit != nil }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nombre", text: $name)
                .listRowBackground(Color.appCardBackground)

                Section {
                    HStack(spacing: 12) {
                        CategoryPreview(name: name, emoji: emoji)
                        TextField("Escribe o pega un emoji", text: $emoji)
                            .onChange(of: emoji) { _, newValue in
                                if newValue.count > 1 { emoji = String(newValue.suffix(1)) }
                            }
                        if !emoji.isEmpty {
                            Button {
                                emoji = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Color.appTextSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(Self.suggestions, id: \.self) { item in
                            Button {
                                emoji = item
                            } label: {
                                Text(item)
                                    .font(.system(size: 26))
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                    .background(emoji == item ? Color.appAccent.opacity(0.25) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Emoji (opcional)")
                } footer: {
                    Text("Sin emoji se usa el ícono automático de la categoría.")
                }
                .listRowBackground(Color.appCardBackground)

                Picker("Tipo", selection: $scope) {
                    ForEach(CategoryScope.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .listRowBackground(Color.appCardBackground)
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .tint(Color.appAccent)
            .navigationTitle(isEditing ? "Editar categoría" : "Nueva categoría")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(!isValid)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let category = categoryToEdit {
                    name = category.name
                    scope = category.scope
                    emoji = category.emoji ?? CategoryStyle.emoji(for: category.name) ?? ""
                } else {
                    scope = defaultScope
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        CategoryStyle.setEmoji(emoji.isEmpty ? nil : emoji, for: trimmed, replacing: categoryToEdit?.name)
        if let category = categoryToEdit {
            category.name = trimmed
            category.scope = scope
            category.emoji = emoji.isEmpty ? nil : emoji
            category.updatedAt = .now
            category.needsSync = true
        } else {
            let category = Category(name: trimmed, scope: scope)
            category.emoji = emoji.isEmpty ? nil : emoji
            modelContext.insert(category)
        }
        dismiss()
    }
}

private struct CategoryPreview: View {
    let name: String
    let emoji: String

    var body: some View {
        let tint = CategoryStyle.color(for: name)
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(tint.opacity(0.18))
            .frame(width: 44, height: 44)
            .overlay {
                if emoji.isEmpty {
                    Image(systemName: CategoryStyle.symbol(for: name))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(tint)
                } else {
                    Text(emoji).font(.system(size: 24))
                }
            }
    }
}

#Preview {
    AddCategoryView()
        .modelContainer(for: Category.self, inMemory: true)
}
