import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation
import WidgetKit
import UserNotifications

// This extension runs in a separate process (no UI).
// The OS calls it when DeviceActivity schedule intervals start/end,
// and when usage event thresholds are crossed.

class MorningGuardMonitor: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()

    // MARK: - Interval start

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)

        switch activity.rawValue {

        case "scheduledGuard":
            // Bedtime guard: apply shields and mark bedtime ownership so a
            // countdown guard's teardown can't lift a block that must last all
            // night. If a countdown is mid-flight, leave its end time alone —
            // the end paths hand the shields back to bedtime.
            let defaults = UserDefaults(suiteName: "group.com.alexliu.morningguard")
            defaults?.set(true, forKey: "mg.bedtimeActive")
            applyShields()
            if !countdownRunning(defaults) {
                writeGuardActive(true, endTime: nil)
            }

        case "morningAutoBlock":
            // Wake-time auto-block: apply shields and write full guard state so the
            // main app can show a countdown when the user opens it.
            // Skip if a guard already ran today, or another countdown guard is live.
            // A bedtime-only block (active, no end time) does NOT block us — the
            // morning window takes over so the wake-time block still happens.
            let defaults = UserDefaults(suiteName: "group.com.alexliu.morningguard")
            let today = StreakLedger.dayString(Date())
            guard defaults?.string(forKey: "mg.lastGuardDate") != today else { return }
            guard !countdownRunning(defaults) else { return }
            guard weekendAllowed(defaults) else { return }
            applyShields()
            let windowMins = Self.storedWindowMinutes(defaults)
            let endTime = Date().addingTimeInterval(Double(windowMins) * 60)
            writeGuardActive(true, endTime: endTime)
            defaults?.set(today, forKey: "mg.lastGuardDate")
            recordCaffeineAnchor(defaults)
            StreakLedger.credit(defaults)
            scheduleOneShotEnd(until: endTime)
            scheduleCompletionNotification(defaults, at: endTime)

        default:
            break
        }
    }

    // MARK: - Interval end

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Only the guard activities should lift shields. Any other activity ending
        // must not wipe an in-progress guard's shields or shared state.
        let defaults = UserDefaults(suiteName: "group.com.alexliu.morningguard")
        switch activity.rawValue {
        case "scheduledGuard":
            defaults?.set(false, forKey: "mg.bedtimeActive")
            // A countdown guard with time left keeps the shields.
            if countdownRunning(defaults, slack: 60) { return }
            store.clearAllSettings()
            writeGuardActive(false, endTime: nil)

        case "morningGuard", "morningAutoBlock":
            // A different countdown guard with time left keeps the shields.
            if countdownRunning(defaults, slack: 60) { return }
            if defaults?.bool(forKey: "mg.bedtimeActive") == true {
                // The bedtime block still owns the shields — hand back, don't lift.
                writeGuardActive(true, endTime: nil)
                return
            }
            store.clearAllSettings()
            writeGuardActive(false, endTime: nil)

        default:
            break
        }
    }

    // MARK: - Usage threshold crossed

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)

        guard activity.rawValue == "usageTrigger" else { return }

        let defaults = UserDefaults(suiteName: "group.com.alexliu.morningguard")
        let today = StreakLedger.dayString(Date())
        // Activate at most once per day; don't stack on a running guard.
        guard defaults?.string(forKey: "mg.lastGuardDate") != today else { return }
        guard !(defaults?.bool(forKey: "isGuardActive") ?? false) else { return }
        guard weekendAllowed(defaults) else { return }

        applyShields()

        let windowMins = Self.storedWindowMinutes(defaults)
        let endTime = Date().addingTimeInterval(Double(windowMins) * 60)
        writeGuardActive(true, endTime: endTime)
        defaults?.set(today, forKey: "mg.lastGuardDate")
        recordCaffeineAnchor(defaults)
        StreakLedger.credit(defaults)
        scheduleOneShotEnd(until: endTime)
        scheduleCompletionNotification(defaults, at: endTime)
    }

    // MARK: - Helpers

    /// The user's block window in minutes. `integer(forKey:)` returns 0 when the
    /// key is missing — never treat that as a 0-minute window (the guard would
    /// end the moment it starts).
    private static func storedWindowMinutes(_ defaults: UserDefaults?) -> Int {
        let stored = defaults?.integer(forKey: "windowDurationMinutes") ?? 0
        return stored > 0 ? stored : 60
    }

    /// True while a countdown guard's end time is still in the future. `slack`
    /// tolerates the minute-truncated one-shot schedule ending up to 59 s before
    /// the stored end time.
    private func countdownRunning(_ defaults: UserDefaults?, slack: TimeInterval = 0) -> Bool {
        guard let end = defaults?.object(forKey: "guardEndTime") as? Date else { return false }
        return end.timeIntervalSinceNow > slack
    }

    /// "Morning window complete" for guards this extension starts — the app isn't
    /// around to schedule it. Honors the user's completion-notification setting.
    private func scheduleCompletionNotification(_ defaults: UserDefaults?, at endTime: Date) {
        guard (defaults?.object(forKey: "notifyOnCompletion") as? Bool ?? true) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Morning window complete 🌤️"
        content.body = "Morning window done. Social apps are back."
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: endTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "complete", content: content, trigger: trigger)
        )
    }

    /// False on weekends when the user has turned weekends off, so schedule- and
    /// usage-triggered morning guards match the first-unlock auto-start behavior.
    private func weekendAllowed(_ defaults: UserDefaults?) -> Bool {
        let weekendsEnabled = defaults?.object(forKey: "weekendsEnabled") as? Bool ?? true
        return weekendsEnabled || !Calendar.current.isDateInWeekend(Date())
    }

    /// One-shot morningGuard interval so intervalDidEnd lifts the shields at the
    /// right time even if the app is never opened or the source schedule is later
    /// disabled mid-window.
    private func scheduleOneShotEnd(until endTime: Date) {
        let cal = Calendar.current
        let nowComps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        let endComps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: endTime)
        let schedule = DeviceActivitySchedule(intervalStart: nowComps, intervalEnd: endComps, repeats: false)
        try? DeviceActivityCenter().startMonitoring(DeviceActivityName("morningGuard"), during: schedule)
    }

    private func applyShields() {
        let defaults = UserDefaults(suiteName: "group.com.alexliu.morningguard")
        guard let data = defaults?.data(forKey: "selectedApps"),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }

        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil : ShieldSettings.ActivityCategoryPolicy.specific(selection.categoryTokens)
    }

    // Set the caffeine anchor once per day so the coffee countdown doesn't reset
    // when the guard re-activates. Mirrors GuardViewModel.recordCaffeineAnchor.
    private func recordCaffeineAnchor(_ defaults: UserDefaults?) {
        let existing = defaults?.object(forKey: "mg.caffeineAnchor") as? Date
        let isToday = existing.map { Calendar.current.isDateInToday($0) } ?? false
        if !isToday { defaults?.set(Date(), forKey: "mg.caffeineAnchor") }
    }

    private func writeGuardActive(_ active: Bool, endTime: Date?) {
        let defaults = UserDefaults(suiteName: "group.com.alexliu.morningguard")
        defaults?.set(active, forKey: "isGuardActive")
        if let endTime {
            defaults?.set(endTime, forKey: "guardEndTime")
        } else {
            defaults?.removeObject(forKey: "guardEndTime")
        }
        // Guard state changed while the app may be closed → refresh widgets.
        WidgetCenter.shared.reloadAllTimelines()
    }
}
