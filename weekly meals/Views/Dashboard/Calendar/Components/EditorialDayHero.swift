import SwiftUI

// Editorial hero on Kalendarz v2.
// Eyebrow: "23 KWIETNIA · DZISIAJ" — terracotta tracking caps.
// Title: "Czwartkowy\njadłospis" — italic terracotta first line + black bold "jadłospis".
struct EditorialDayHero: View {
    let date: Date
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrowText)
                .font(.system(size: 10, weight: .bold))
                .tracking(2.4)
                .foregroundStyle(WMPalette.terracotta)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: -8) {
                Text(dayAdjective)
                    .font(.system(size: 56, weight: .medium))
                    .italic()
                    .foregroundStyle(WMPalette.terracotta)

                Text("jadłospis")
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(Color.wmLabel(scheme))
            }
            .tracking(-2.2)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityLabel("\(dayAdjective) jadłospis")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Polish helpers

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pl_PL")
        f.dateFormat = "d MMMM"
        return f
    }()

    private var eyebrowText: String {
        let cal = Calendar.current
        let dayMonth = Self.dayMonthFormatter.string(from: date).uppercased()
        if cal.isDateInToday(date)     { return "\(dayMonth) · DZISIAJ" }
        if cal.isDateInTomorrow(date)  { return "\(dayMonth) · JUTRO" }
        if cal.isDateInYesterday(date) { return "\(dayMonth) · WCZORAJ" }
        return dayMonth
    }

    /// Map Polish weekday → adjective form used as italic hero ("Czwartkowy jadłospis").
    private var dayAdjective: String {
        let weekday = Calendar.current.component(.weekday, from: date) // 1 = Sunday
        switch weekday {
        case 1: return "Niedzielny"
        case 2: return "Poniedziałkowy"
        case 3: return "Wtorkowy"
        case 4: return "Środowy"
        case 5: return "Czwartkowy"
        case 6: return "Piątkowy"
        case 7: return "Sobotni"
        default: return ""
        }
    }
}
