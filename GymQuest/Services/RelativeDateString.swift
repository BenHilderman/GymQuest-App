import Foundation

/// Compact "today / yesterday / 3 days ago / last week" formatter optimized
/// for shelf headers and hero rationales — short, friendly, no ambiguity.
enum RelativeDateString {

    static func short(from date: Date, to now: Date = Date()) -> String {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let startOfNow = calendar.startOfDay(for: now)
        let dayDelta = calendar.dateComponents([.day], from: startOfDay, to: startOfNow).day ?? 0

        switch dayDelta {
        case 0: return "today"
        case 1: return "yesterday"
        case 2...6: return "\(dayDelta) days ago"
        case 7...13: return "last week"
        case 14...29: return "\(dayDelta / 7) weeks ago"
        default: return "a while ago"
        }
    }

    /// Warmer, more conversational timestamp for friend cards.
    /// "just now", "this morning", "last night" instead of cold hour counts.
    static func warm(from date: Date, to now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        let minutes = Int(seconds / 60)
        let hours = Int(seconds / 3600)
        let calendar = Calendar.current
        let dateHour = calendar.component(.hour, from: date)

        if minutes < 2 { return "just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        if hours < 2 { return "1h ago" }

        let sameDay = calendar.isDate(date, inSameDayAs: now)
        if sameDay {
            if dateHour < 12 { return "this morning" }
            if dateHour < 17 { return "this afternoon" }
            return "this evening"
        }

        let yesterday = calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now)
        if yesterday {
            if dateHour >= 17 { return "last night" }
            return "yesterday"
        }

        return short(from: date, to: now)
    }
}
