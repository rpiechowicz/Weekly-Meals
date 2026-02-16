import SwiftUI

struct AddManualShoppingItemSheet: View {
    typealias SaveAction = (_ name: String, _ amount: Double, _ unit: String, _ department: String?) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var amountText: String = ""
    @State private var unit: String = "szt"
    @State private var department: String = ProductConstants.Department.other
    @State private var localError: String?
    @State private var isSaving = false

    private let onSave: SaveAction

    init(onSave: @escaping SaveAction) {
        self.onSave = onSave
    }

    private static let allowedUnits: [String] = ["szt", "g", "kg", "ml", "l"]
    private static let departments: [String] = [
        ProductConstants.Department.vegetables,
        ProductConstants.Department.fruits,
        ProductConstants.Department.meat,
        ProductConstants.Department.fish,
        ProductConstants.Department.dairy,
        ProductConstants.Department.bakery,
        ProductConstants.Department.grains,
        ProductConstants.Department.canned,
        ProductConstants.Department.spices,
        ProductConstants.Department.oils,
        ProductConstants.Department.alcohols,
        ProductConstants.Department.beverages,
        ProductConstants.Department.snacks,
        ProductConstants.Department.frozen,
        ProductConstants.Department.bakerySweets,
        ProductConstants.Department.household,
        ProductConstants.Department.other
    ]

    private var canSave: Bool {
        !isSaving && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Produkt") {
                    TextField("Np. Woda", text: $name)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)

                    TextField("Ilość", text: $amountText)
                        .keyboardType(.decimalPad)

                    Picker("Jednostka", selection: $unit) {
                        ForEach(Self.allowedUnits, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                }

                Section("Dział") {
                    Picker("Kategoria", selection: $department) {
                        ForEach(Self.departments, id: \.self) { section in
                            Text(section).tag(section)
                        }
                    }
                }

                if let localError, !localError.isEmpty {
                    Section {
                        Text(localError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Dodaj produkt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Anuluj") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Zapisywanie..." : "Dodaj") {
                        saveTapped()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func parseAmount() -> Double? {
        let normalized = amountText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    private func saveTapped() {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            localError = "Podaj nazwę produktu."
            return
        }
        guard let amount = parseAmount() else {
            localError = "Podaj poprawną ilość większą od 0."
            return
        }

        localError = nil
        isSaving = true
        Task {
            let success = await onSave(normalizedName, amount, unit, department)
            await MainActor.run {
                isSaving = false
                if success {
                    dismiss()
                } else {
                    localError = "Nie udało się dodać produktu. Spróbuj ponownie."
                }
            }
        }
    }
}

#Preview {
    AddManualShoppingItemSheet { _, _, _, _ in
        true
    }
}
