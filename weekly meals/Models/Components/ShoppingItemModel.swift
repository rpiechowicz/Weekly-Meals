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
        let roundedValue = Int(totalAmount.rounded(.toNearestOrAwayFromZero))
        return roundedValue.formatted(.number.locale(Locale(identifier: "pl_PL")))
    }
}
