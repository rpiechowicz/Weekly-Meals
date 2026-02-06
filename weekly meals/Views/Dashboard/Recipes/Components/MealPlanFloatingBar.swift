import SwiftUI

struct MealPlanFloatingBar: View {
    let totalCount: Int
    let maxCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "list.clipboard")
                Text("Wybrano: \(totalCount)/\(maxCount)")
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "chevron.up")
            }
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(Color.green)
                    .shadow(color: .green.opacity(0.3), radius: 10, y: 5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}
