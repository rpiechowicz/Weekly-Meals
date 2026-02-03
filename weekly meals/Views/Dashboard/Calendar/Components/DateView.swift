import SwiftUI

struct DateView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let dayName: String
    let dayNumber: String
    
    var body: some View {
        VStack(spacing: 6) {
            Text(dayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : .secondary)
            
            Text(dayNumber)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(isSelected ? .white : .primary)
            
            if isToday {
                Circle()
                    .fill(isSelected ? .white : .blue)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(width: 60, height: 80)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color.blue : Color.gray.opacity(0.1))
        }
        .overlay {
            if !isSelected {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            }
        }
    }
}
