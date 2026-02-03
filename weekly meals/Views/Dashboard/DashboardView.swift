//
//  HomeView.swift
//  weekly meals
//
//  Created by Rafi on 03/02/2026.
//

import SwiftUI

struct DashboardView: View {
    @State private var showMealView = false
    
    var body: some View {
        ZStack {
            NavigationMenu()
        }
    }
}

#Preview {
    DashboardView()
}
