import SwiftUI

struct MealPlanFloatingBar: View {
    let totalCount: Int
    let maxCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text("Wybrane przepisy")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))

                    Text("\(totalCount)/\(maxCount)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }

                Spacer()
                Text("Podsumuj")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.9))

                Image(systemName: "chevron.up")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.green.opacity(0.9))
                    .shadow(color: .green.opacity(0.24), radius: 12, y: 6)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}
