import SwiftUI

struct CalendarView: View {
    @State private var datesViewModel = DatesViewModel()

    var body: some View {
        ScrollView {
            VStack() {
                DatesView(datesViewModal: datesViewModel)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(datesViewModel.formattedDate(datesViewModel.selectedDate))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Headers(HeaderConstans.Calendar.self)
        }
    }
}

#Preview {
    CalendarView()
}
