import SwiftUI

// Profile header card on Ustawienia v2 — avatar + display name + email.
// Source: settings.jsx → top `CardGroup` with `Avatar`.
//
// Design specifies the avatar as a 48pt circle with a top-left → bottom-right
// terracotta gradient and the user's first initial in white. We swap the
// initial-in-gradient look for the existing `ProfileAvatar` (which falls
// back to initials when no remote photo is set), so Google users still get
// their real photo while Apple users see the warm tinted initial fallback.
//
// Wyloguj icon was intentionally removed from this card — the design moved
// the destructive action to a full-width button at the bottom of the screen.
struct EditorialProfileCard: View {
    let displayName: String
    let email: String
    let avatarUrl: String?

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        EditorialSettingsCardGroup {
            HStack(spacing: 14) {
                avatar

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayNameLabel)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(Color.wmLabel(scheme))
                        .lineLimit(1)

                    Text(emailLabel)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(Color.wmMuted(scheme))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    // The profile photo. Falls back to a tinted gradient with the user's
    // initial when no remote URL is set — Apple Sign in users land here.
    private var avatar: some View {
        ProfileAvatar(
            avatarUrl: trimmedAvatarUrl,
            displayName: displayNameLabel,
            size: 48
        )
    }

    private var trimmedAvatarUrl: String? {
        guard let avatarUrl else { return nil }
        let trimmed = avatarUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var displayNameLabel: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Twoje konto" : trimmed
    }

    private var emailLabel: String {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Brak e-maila" : trimmed
    }
}
