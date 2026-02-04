import SwiftUI

struct RecipeInfoBadge: View {
    let icon: String
    let text: String
    var color: Color = .secondary
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color(.separator).opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 3, x: 0, y: 1)
    }
}

#Preview {
    RecipeInfoBadge(icon: "clock", text: "30 min")
    RecipeInfoBadge(icon: "person.2", text: "2 porcje")
    RecipeInfoBadge(icon: "star", text: "łatwe", color: .green)
    RecipeInfoBadge(icon: "star.leadinghalf.filled", text: "średnie", color: .orange)
    RecipeInfoBadge(icon: "star.fill", text: "trudne", color: .red)
}
