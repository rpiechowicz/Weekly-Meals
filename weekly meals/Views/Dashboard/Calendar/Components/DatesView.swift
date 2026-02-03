import SwiftUI

struct DatesView: View {
    @Bindable var datesViewModal: DatesViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(datesViewModal.dates, id: \.self) { date in
                    DateView(
                        date: date,
                        isSelected: datesViewModal.isSelected(date),
                        isToday: datesViewModal.isToday(date),
                        dayName: datesViewModal.dayName(for: date),
                        dayNumber: datesViewModal.dayNumber(for: date)
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            datesViewModal.selectDate(date)
                        }
                    }
                }
            }
            .padding()
            .padding(.top, 10)
        }
    }
}

#Preview {
    DatesView(datesViewModal: DatesViewModel())
        .padding()
}
