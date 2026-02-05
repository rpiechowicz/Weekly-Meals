import SwiftUI

struct DatesView: View {
    @Bindable var datesViewModal: DatesViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
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
                        .id(date)
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
            .onAppear {
                DispatchQueue.main.async {
                    if let today = datesViewModal.dates.first(where: { datesViewModal.isToday($0) }) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(today, anchor: .center)
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(datesViewModal.selectedDate, anchor: .center)
                        }
                    }
                }
            }
            .onChange(of: datesViewModal.selectedDate) { oldValue, newValue in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}

#Preview {
    DatesView(datesViewModal: DatesViewModel())
        .padding()
}
