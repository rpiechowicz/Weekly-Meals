//
//  CalendarView.swift
//  weekly meals
//
//  Created by Rafi on 03/02/2026.
//

import SwiftUI

struct CalendarView: View {
    @State private var viewModel = CalendarViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                DatesView(viewModel: viewModel)
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
