//
//  AuthActionsView.swift
//  weekly meals
//
//  Created by Rafi on 03/02/2026.
//

import AuthenticationServices
import SwiftUI

struct AuthActionsView: View {
    let isLoading: Bool
    let errorMessage: String?
    let onSignInWithAppleTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Natywny przycisk Apple — wymaga ASAuthorizationAppleIDButton
                // (użytkownik nie może być zmuszany do użycia custom stylingu
                // zgodnie z wytycznymi Apple).
                SignInWithAppleButton(
                    .signIn,
                    onRequest: { _ in
                        // Prawdziwy request jest budowany przez AppleSignInCoordinator
                        // (potrzebuje nonce + scopes zsynchronizowanych z backendem).
                        // Ten onRequest jest wywołany tylko, żeby spełnić API SwiftUI —
                        // samą autoryzację uruchamiamy ręcznie przez tap.
                    },
                    onCompletion: { _ in
                        // Wynik jest konsumowany przez AppleSignInCoordinator.
                    }
                )
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .allowsHitTesting(false) // przechwyć tap naszym wrapperem niżej

                Button(action: onSignInWithAppleTap) {
                    Color.clear
                }
                .frame(height: 48)
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isLoading)
            }

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().progressViewStyle(.circular)
                    Text("Logowanie przez Apple…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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
        onSignInWithAppleTap: {}
    )
}
