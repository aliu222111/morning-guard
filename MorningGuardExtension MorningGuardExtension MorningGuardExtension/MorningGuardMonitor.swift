import DeviceActivity
import ManagedSettings
import Foundation

// This extension runs in a separate process (no UI).
// The OS calls it when the DeviceActivity schedule interval ends.

class MorningGuardMonitor: DeviceActivityMonitor {

    private let store = ManagedSettingsStore()

    // Called when the morning window starts
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // Restrictions are already applied by the main app.
        // This is a safety net in case the main app isn't running.
    }

    // Called when the morning window ends — lift all restrictions
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.clearAllSettings()

        let defaults = UserDefaults(suiteName: "group.com.alexliu.morningguard")
        defaults?.set(false, forKey: "isGuardActive")
    }

    // Called if usage threshold is crossed (not used here, but available)
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
    }
}
