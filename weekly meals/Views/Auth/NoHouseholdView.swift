import SwiftUI

struct NoHouseholdView: View {
    @State private var householdName: String = ""
    @FocusState private var isNameFieldFocused: Bool

    let isLoading: Bool
    let errorMessage: String?
    let onCreate: (String) -> Void
    let onLogout: () -> Void

    var body: some View {
        ZStack {
            AuthBackgroundView()

            VStack(spacing: 18) {
                Spacer()

                Image(systemName: "house.slash.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Nie masz jeszcze gospodarstwa")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("Utwórz nowe gospodarstwo, aby rozpocząć planowanie i listy zakupów.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                TextField("Nazwa gospodarstwa", text: $householdName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($isNameFieldFocused)
                    .submitLabel(.done)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)

                Button {
                    onCreate(householdName)
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "house.badge.plus.fill")
                        }
                        Text(isLoading ? "Tworzenie..." : "Utwórz gospodarstwo")
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
                .padding(.horizontal, 20)
                .disabled(isLoading || householdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Wyloguj") {
                    onLogout()
                }
                .foregroundStyle(.red)
                .padding(.top, 6)

                if let errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()
            }
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    NoHouseholdView(
        isLoading: false,
        errorMessage: nil,
        onCreate: { _ in },
        onLogout: {}
    )
}
