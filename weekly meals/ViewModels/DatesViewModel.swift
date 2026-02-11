import Foundation
import Observation

@Observable
class DatesViewModel {
    var selectedDate: Date = Date()
    var currentWeekOffset: Int = 0 // 0 = bieżący tydzień, -1 = poprzedni, +1 = następny
    
    /// Generuje tablicę dat dla wybranego tygodnia (Poniedziałek - Niedziela)
    var dates: [Date] {
        let calendar = Calendar.current
        let today = Date()
        
        // Oblicz datę docelową na podstawie offsetu tygodnia
        guard let targetDate = calendar.date(byAdding: .weekOfYear, value: currentWeekOffset, to: today),
              let weekStart = calendar.dateInterval(of: .weekOfYear, for: targetDate)?.start else {
            return []
        }
        
        // Znajdź poniedziałek
        let monday = calendar.date(byAdding: .day, value: calendar.firstWeekday == 1 ? 1 : 0, to: weekStart) ?? weekStart
        
        // Wygeneruj 7 dni od poniedziałku
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: monday)
        }
    }

    /// `weekStart` w formacie backendowym `yyyy-MM-dd` (poniedziałek wybranego tygodnia)
    var weekStartISO: String {
        guard let monday = dates.first else {
            return Self.weekStartFormatter.string(from: Date())
        }
        return Self.weekStartFormatter.string(from: monday)
    }

    private static let weekStartFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    /// Sprawdza czy podana data to dzisiaj
    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
    
    /// Sprawdza czy podana data jest wybrana
    func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }
    
    /// Formatuje datę na nazwę dnia (np. "PN", "WT")
    func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        formatter.locale = Locale(identifier: "pl_PL")
        return formatter.string(from: date).uppercased()
    }
    
    /// Formatuje datę na numer dnia (np. "3", "14")
    func dayNumber(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        formatter.locale = Locale(identifier: "pl_PL")
        return formatter.string(from: date).capitalized
    }
        
    /// Wybiera konkretną datę
    func selectDate(_ date: Date) {
        selectedDate = date
    }
    
    /// Przechodzi do poprzedniego tygodnia
    func goToPreviousWeek() {
        currentWeekOffset -= 1
    }
    
    /// Przechodzi do następnego tygodnia
    func goToNextWeek() {
        currentWeekOffset += 1
    }
    
    /// Sprawdza czy data jest dzisiaj lub w przyszłości (można edytować)
    func isEditable(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.startOfDay(for: date) >= calendar.startOfDay(for: Date())
    }

    /// Wraca do bieżącego tygodnia
    func goToCurrentWeek() {
        currentWeekOffset = 0
        selectedDate = Date()
    }
}
