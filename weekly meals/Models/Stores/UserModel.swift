import Foundation

struct UserModel: Identifiable, Codable, Equatable {
    var id: String { email }
    var email: String
    var displayName: String
    var households: [HouseholdModel]
}
