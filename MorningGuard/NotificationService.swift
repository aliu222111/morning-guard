import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func schedule(id: String, title: String, body: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date),
            repeats: false
        )

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                #if DEBUG
                print("Notification error: \(error)")
                #endif
            }
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func cancel(ids: [String]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Affirmation notifications

    private let affirmationPrefix = "affirmation-"

    /// Schedules 14 days of affirmation notifications starting at (wake + offset),
    /// with `timesPerDay` notifications per day spaced 4 hours apart. `customText`
    /// overrides the rotating bank when non-empty.
    func scheduleAffirmations(enabled: Bool,
                              wakeMinutes: Int,
                              offsetHours: Int,
                              timesPerDay: Int,
                              customText: String,
                              alsoIncludePrebuilt: Bool = false) {
        let center = UNUserNotificationCenter.current()
        // Remove old requests FIRST, then add the new batch inside the callback.
        // The new batch reuses the same identifiers, so adding before the removal
        // completes would let the removal delete freshly scheduled notifications.
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(self.affirmationPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            guard enabled else { return }
            self.addAffirmationBatch(center: center,
                                     wakeMinutes: wakeMinutes,
                                     offsetHours: offsetHours,
                                     timesPerDay: timesPerDay,
                                     customText: customText,
                                     alsoIncludePrebuilt: alsoIncludePrebuilt)
        }
    }

    private func addAffirmationBatch(center: UNUserNotificationCenter,
                                     wakeMinutes: Int,
                                     offsetHours: Int,
                                     timesPerDay: Int,
                                     customText: String,
                                     alsoIncludePrebuilt: Bool) {
        let cal = Calendar.current
        let baseFireMinutes = wakeMinutes + offsetHours * 60
        var id = 0

        for dayOffset in 0..<14 {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: Date()) else { continue }
            let dayComps = cal.dateComponents([.year, .month, .day], from: day)

            for n in 0..<max(1, timesPerDay) {
                let fireMinutes = baseFireMinutes + n * 240  // 4 h between each
                // Add minutes to the day's start so times past midnight carry into
                // the next day instead of wrapping back onto the same date.
                guard let dayStart = cal.date(from: dayComps),
                      let fireDate = cal.date(byAdding: .minute, value: fireMinutes, to: dayStart),
                      fireDate > Date() else { continue }

                let trimmedCustom = customText.trimmingCharacters(in: .whitespacesAndNewlines)
                let dailyBuiltin = Affirmations.all[(cal.ordinality(of: .day, in: .year, for: fireDate) ?? 1) % Affirmations.all.count]
                let text: String
                if trimmedCustom.isEmpty {
                    text = dailyBuiltin
                } else if alsoIncludePrebuilt {
                    text = dailyBuiltin + "\n\n" + trimmedCustom
                } else {
                    text = trimmedCustom
                }

                let content = UNMutableNotificationContent()
                content.title = "Morning affirmation"
                content.body = text
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
                    repeats: false
                )
                center.add(
                    UNNotificationRequest(identifier: "\(affirmationPrefix)\(id)", content: content, trigger: trigger),
                    withCompletionHandler: nil
                )
                id += 1
            }
        }
    }
}
