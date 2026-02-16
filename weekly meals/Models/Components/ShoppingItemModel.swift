import Foundation

struct ShoppingItem: Identifiable, Codable, Hashable {
    var id: String { productKey }
    let productKey: String
    var name: String
    var totalAmount: Double
    var unit: String
    var department: String
    var isChecked: Bool

    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.roundingMode = .halfUp
        return formatter
    }()

    var formattedAmount: String {
        ShoppingItem.amountFormatter.string(from: NSNumber(value: totalAmount))
            ?? String(totalAmount)
    }
}
