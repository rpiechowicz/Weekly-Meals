import Foundation

struct IUser: Identifiable, Codable, Equatable {
    var id: String { email }
    var email: String
    var displayName: String
    var households: [IHousehold]
}
