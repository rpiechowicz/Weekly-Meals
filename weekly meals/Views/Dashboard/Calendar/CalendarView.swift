import SwiftUI

struct CalendarView: View {
    @State private var datesViewModel = DatesViewModel()

    var body: some View {
        NavigationStack {
            VStack {
                DatesView(datesViewModal: datesViewModel)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(datesViewModel.formattedDate(datesViewModel.selectedDate))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                ScrollView {
                    LazyVStack {
                        ForEach(1...50, id: \.self) { index in
                            Text("\(index)")
                        }
                    }
                }
            }
            .navigationTitle("Kalendarz")
        }
    }
}

#Preview {
    CalendarView()
}
