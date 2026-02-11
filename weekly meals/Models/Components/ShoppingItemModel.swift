import Foundation

struct ShoppingItem: Identifiable, Codable, Hashable {
    var id: String { productKey }
    let productKey: String
    var name: String
    var totalAmount: Double
    var unit: String
    var department: String
    var isChecked: Bool

    var formattedAmount: String {
        totalAmount.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", totalAmount)
            : String(format: "%.1f", totalAmount)
    }
}
