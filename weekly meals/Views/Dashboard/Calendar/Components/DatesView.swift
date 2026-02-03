import SwiftUI

struct DatesView: View {
    @Bindable var viewModel: CalendarViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.dates, id: \.self) { date in
                    DateView(
                        date: date,
                        isSelected: viewModel.isSelected(date),
                        isToday: viewModel.isToday(date),
                        dayName: viewModel.dayName(for: date),
                        dayNumber: viewModel.dayNumber(for: date)
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.selectDate(date)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

#Preview {
    DatesView(viewModel: CalendarViewModel())
        .padding()
}
