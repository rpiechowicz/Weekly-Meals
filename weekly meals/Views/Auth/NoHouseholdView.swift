import SwiftUI

struct NoHouseholdView: View {
    @State private var householdName: String = ""
    @FocusState private var isNameFieldFocused: Bool
    @State private var showInvitePopover: Bool = false

    let isLoading: Bool
    let errorMessage: String?
    let onCreate: (String) -> Void
    let onLogout: () -> Void

    var body: some View {
        ZStack {
            AuthBackgroundView()

            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "house.slash.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("Nie masz jeszcze gospodarstwa")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text("Możesz utworzyć własne gospodarstwo albo dołączyć z linku zaproszenia od domownika.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button {
                    showInvitePopover.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Text("Jak dołączyć?")
                            .font(.footnote.weight(.semibold))
                        Image(systemName: "info.circle")
                            .font(.footnote)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .padding(.bottom, 4)
                .popover(isPresented: $showInvitePopover, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    infoPopover
                        .padding()
                        .padding(.vertical, 20)
                        .presentationCompactAdaptation(.none)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Nowe gospodarstwo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    TextField("Np. Dom", text: $householdName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($isNameFieldFocused)
                        .submitLabel(.done)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

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
                    .disabled(isLoading || householdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 20)

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
    
    private var infoPopover: some View {
        InfoPopoverContent {
            HStack(alignment: .firstTextBaseline) {
                Text("Dołączanie do gospodarstwa")
                    .font(.headline)
                Spacer()
            }
            
            Divider()

            InfoTipRow(icon: "square.and.arrow.up", text: "Poproś domownika o nowy link zaproszenia.")
            InfoTipRow(icon: "safari", text: "Otwórz link na tym urządzeniu (np. przez Wiadomości, Mail lub Safari).")
            InfoTipRow(icon: "person.badge.plus", text: "W aplikacji wybierz „Dołącz”, aby aktywować członkostwo.")
            InfoTipRow(icon: "exclamationmark.triangle", text: "Link jest jednorazowy. Po opuszczeniu gospodarstwa potrzebny będzie nowy link.")
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
