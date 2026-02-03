//
//  CalendarView.swift
//  weekly meals
//
//  Created by Rafi on 03/02/2026.
//

import SwiftUI

struct CalendarView: View {
    var body: some View {
        VStack(spacing: 0) {
            Headers(HeaderConstans.Calendar.self)
            
            // Tutaj będzie główna zawartość kalendarza
            ScrollView {
                Text("Zawartość kalendarza")
                    .padding()
            }
        }
    }
}

#Preview {
    CalendarView()
}
