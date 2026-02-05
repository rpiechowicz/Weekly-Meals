import SwiftUI

struct NutritionCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .myBackground()
        .myBorderOverlay()
    }
}


#Preview {
    NutritionCard(title: "Kalorie", value: "250", unit: "kcal", icon: "flame.fill", color: .orange)
}
