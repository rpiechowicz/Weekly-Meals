//
//  AuthActionsView.swift
//  weekly meals
//
//  Created by Rafi on 03/02/2026.
//

import SwiftUI

struct AuthActionsView: View {
    let isLoading: Bool
    let errorMessage: String?
    let onLoginUser1Tap: () -> Void
    let onLoginUser2Tap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onLoginUser1Tap) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: "person.circle.fill")
                    }
                    Text(isLoading ? "Logowanie..." : "Wejdź jako user1")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoading)

            Button(action: onLoginUser2Tap) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        Image(systemName: "person.circle.fill")
                    }
                    Text(isLoading ? "Logowanie..." : "Wejdź jako user2")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.cyan, .blue.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isLoading)

            VStack(spacing: 4) {
                Text("Konta testowe")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("user1 • user1@example.com")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("user2 • user2@example.com")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

#Preview {
    AuthActionsView(
        isLoading: false,
        errorMessage: nil,
        onLoginUser1Tap: {},
        onLoginUser2Tap: {}
    )
}
