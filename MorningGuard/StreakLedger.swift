import Foundation

/// Day-streak bookkeeping shared by the app, the DeviceActivity monitor
/// extension, and the widgets. All state lives in the App Group so every
/// process sees the same numbers.
///
/// A day is credited when the morning "happened": the guard ran (any start
/// path) or the routine was fully completed. Crediting is idempotent per day.
enum StreakLedger {

    static let suiteName = "group.com.alexliu.morningguard"

    private static let currentKey  = "mg.streak.current"
    private static let bestKey     = "mg.streak.best"
    private static let lastDateKey = "mg.streak.lastDate"

    /// Fixed-format day key, immune to locale/12-hour setting changes.
    private static let dayFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    static func dayString(_ date: Date) -> String { dayFormatter.string(from: date) }

    /// Credit "the morning happened" for `date`. Consecutive-day logic:
    /// credited yesterday → streak grows; otherwise it restarts at 1.
    static func credit(_ defaults: UserDefaults?, on date: Date = Date()) {
        guard let d = defaults else { return }
        let today = dayString(date)
        guard d.string(forKey: lastDateKey) != today else { return }   // once per day

        let yesterday = dayString(Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date)
        let newCurrent = d.string(forKey: lastDateKey) == yesterday
            ? d.integer(forKey: currentKey) + 1
            : 1
        d.set(newCurrent, forKey: currentKey)
        d.set(today, forKey: lastDateKey)
        if newCurrent > d.integer(forKey: bestKey) {
            d.set(newCurrent, forKey: bestKey)
        }
    }

    /// The streak to display right now. Alive if credited today, or credited
    /// yesterday (today's morning can still keep it going). Otherwise broken → 0.
    static func displayStreak(_ defaults: UserDefaults?, now: Date = Date()) -> Int {
        guard let d = defaults, let last = d.string(forKey: lastDateKey) else { return 0 }
        let today = dayString(now)
        let yesterday = dayString(Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now)
        return (last == today || last == yesterday) ? d.integer(forKey: currentKey) : 0
    }

    /// True when today's morning has already been credited.
    static func creditedToday(_ defaults: UserDefaults?, now: Date = Date()) -> Bool {
        defaults?.string(forKey: lastDateKey) == dayString(now)
    }

    static func best(_ defaults: UserDefaults?) -> Int {
        defaults?.integer(forKey: bestKey) ?? 0
    }
}
