import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity
import Combine
import WidgetKit

@MainActor
class GuardViewModel: ObservableObject {

    // MARK: - Published State
    @Published var isGuardActive: Bool = false
    @Published var guardEndTime: Date?
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection() {
        didSet {
            guard !isLoadingState else { return }
            // Persist immediately so the picked apps survive relaunch and the
            // extension shields the current list — not only when a guard starts.
            persistSelectedApps()
            if isGuardActive { applyScreenTimeRestrictions() }
            if morningAutoBlockEnabled { updateMorningAutoBlock() }
            updateUsageTrigger()
        }
    }

    /// Writes the selection to the App Group (read by the extension) AND to
    /// standard defaults as a backup. If the group container misbehaves on this
    /// device, the selection still survives relaunch via the backup.
    private func persistSelectedApps() {
        guard let data = try? JSONEncoder().encode(selectedApps) else { return }
        defaults.set(data, forKey: "selectedApps")
        UserDefaults.standard.set(data, forKey: "selectedAppsBackup")
        // Flush now so a force-quit right after picking can't lose the write.
        defaults.synchronize()
        UserDefaults.standard.synchronize()
    }
    @Published var windowDurationMinutes: Int = 60 {
        didSet {
            defaults.set(windowDurationMinutes, forKey: "windowDurationMinutes")
            if morningAutoBlockEnabled { updateMorningAutoBlock() }
        }
    }
    @Published var notifyAtHalfway: Bool = true { didSet { defaults.set(notifyAtHalfway, forKey: "notifyAtHalfway") } }
    @Published var notifyOnCompletion: Bool = true { didSet { defaults.set(notifyOnCompletion, forKey: "notifyOnCompletion") } }
    @Published var weekendsEnabled: Bool = true { didSet { defaults.set(weekendsEnabled, forKey: "weekendsEnabled") } }
    @Published var firstUnlockEnabled: Bool = true { didSet { defaults.set(firstUnlockEnabled, forKey: "firstUnlockEnabled") } }
    @Published var scheduledGuardEnabled: Bool = false {
        didSet {
            defaults.set(scheduledGuardEnabled, forKey: "scheduledGuardEnabled")
            updateScheduledGuard()
        }
    }
    @Published var scheduledGuardStartTime: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date() {
        didSet { defaults.set(scheduledGuardStartTime, forKey: "scheduledGuardStartTime") }
    }
    @Published var scheduledGuardDurationHours: Int = 9 {
        didSet { defaults.set(scheduledGuardDurationHours, forKey: "scheduledGuardDurationHours") }
    }

    // Morning Auto-Block: applies shields at wake time via DeviceActivity, no app launch needed.
    @Published var morningAutoBlockEnabled: Bool = false {
        didSet {
            defaults.set(morningAutoBlockEnabled, forKey: "morningAutoBlockEnabled")
            updateMorningAutoBlock()
        }
    }
    @Published var morningAutoBlockTime: Date = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date() {
        didSet {
            defaults.set(morningAutoBlockTime, forKey: "morningAutoBlockTime")
            if morningAutoBlockEnabled { updateMorningAutoBlock() }
        }
    }

    @Published var alertError: String?

    // MARK: - Private
    private let store = ManagedSettingsStore()
    private let center = DeviceActivityCenter()
    private var timer: AnyCancellable?
    private let defaults: UserDefaults = UserDefaults(suiteName: "group.com.alexliu.morningguard") ?? .standard
    // True only while loadPersistedState() is assigning values, so the property
    // didSet observers don't re-register DeviceActivity schedules on every cold launch.
    private var isLoadingState = false

    enum AuthorizationStatus {
        case notDetermined, authorized, denied
    }

    // MARK: - Init
    init() {
        loadPersistedState()
        refreshAuthorizationStatus()
    }

    // MARK: - Authorization
    /// Syncs our local status from the real system authorization. Must be
    /// called on launch / foreground, otherwise authorizationStatus is stuck at
    /// .notDetermined after relaunch and "Start now" silently does nothing.
    func refreshAuthorizationStatus() {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved:
            authorizationStatus = .authorized
        case .denied:
            authorizationStatus = .denied
        case .notDetermined:
            authorizationStatus = .notDetermined
        @unknown default:
            authorizationStatus = .notDetermined
        }
    }

    func requestAuthorization() async {
        let center = AuthorizationCenter.shared
        do {
            try await center.requestAuthorization(for: .individual)
            authorizationStatus = .authorized
        } catch {
            authorizationStatus = .denied
            #if DEBUG
            print("FamilyControls authorization failed: \(error)")
            #endif
        }
    }

    // MARK: - First-unlock auto-start
    func autoStartIfFirstMorningUnlock() {
        guard firstUnlockEnabled else { return }
        guard authorizationStatus == .authorized else { return }
        guard !isGuardActive else { return }
        // Nothing selected yet → skip silently. Routing into startMorningGuard()
        // would pop its "pick some apps" alert on every morning app-open.
        guard !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty else { return }
        // Auto-start respects the weekend setting (manual Start now does not).
        guard weekendsEnabled || !Calendar.current.isDateInWeekend(Date()) else { return }
        let hour = Calendar.current.component(.hour, from: Date())
        // Only trigger in the morning window 5 AM to 12 PM
        guard hour >= 5 && hour < 12 else { return }
        // Guard runs at most once per day (locale-stable day key).
        guard defaults.string(forKey: "mg.lastGuardDate") != StreakLedger.dayString(Date()) else { return }
        startMorningGuard()
    }

    // MARK: - Start Morning Guard
    func startMorningGuard() {
        // Manual start: surface why it can't start instead of failing silently.
        guard authorizationStatus == .authorized else {
            alertError = "Screen Time access is needed first. Open Settings ▸ Screen Time, or re-run onboarding in Settings."
            return
        }
        guard !isGuardActive else { return }
        guard !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty else {
            alertError = "Pick some apps to block first, in the Guard tab."
            return
        }

        let endTime = Date().addingTimeInterval(Double(windowDurationMinutes) * 60)
        guardEndTime = endTime
        isGuardActive = true
        applyScreenTimeRestrictions()
        // Record nothing until monitoring actually starts — a failed start must
        // not burn the once-per-day slot, the streak credit, or the caffeine anchor.
        guard scheduleDeviceActivity(until: endTime) else { return }

        defaults.set(StreakLedger.dayString(Date()), forKey: "mg.lastGuardDate")
        recordCaffeineAnchor()
        StreakLedger.credit(defaults)   // a guarded morning keeps the streak alive
        persistState()
        startCountdownTimer()
        scheduleHalfwayNotification(endTime: endTime)
        scheduleCompletionNotification(endTime: endTime)
    }

    // MARK: - End Morning Guard
    func endMorningGuard() {
        timer?.cancel()
        // Only stop this session's one-shot monitor. The repeating morningAutoBlock
        // and scheduledGuard schedules must survive so they fire again tomorrow.
        center.stopMonitoring([DeviceActivityName.morningGuard])

        if defaults.bool(forKey: "mg.bedtimeActive") {
            // A bedtime block still owns the shields: the countdown is over, but
            // apps must stay locked until the bedtime window ends. Hand back.
            guardEndTime = nil
            isGuardActive = true
            applyScreenTimeRestrictions()
            NotificationService.shared.cancel(ids: ["complete"])   // "apps are back" would be a lie
            persistState()
            return
        }

        isGuardActive = false
        guardEndTime = nil
        store.clearAllSettings()
        persistState()
    }

    // MARK: - Screen Time Restrictions (ManagedSettings)
    private func applyScreenTimeRestrictions() {
        // Shield the selected apps
        store.shield.applications = selectedApps.applicationTokens.isEmpty ? nil : selectedApps.applicationTokens
        store.shield.applicationCategories = selectedApps.categoryTokens.isEmpty ? nil :
            ShieldSettings.ActivityCategoryPolicy.specific(selectedApps.categoryTokens)
    }

    // MARK: - DeviceActivity Monitoring
    /// Returns false (after rolling back guard state) when monitoring can't start.
    private func scheduleDeviceActivity(until endTime: Date) -> Bool {
        let now = Date()
        let cal = Calendar.current
        let startComponents = cal.dateComponents([.year, .month, .day, .hour, .minute], from: now)
        let endComponents = cal.dateComponents([.year, .month, .day, .hour, .minute], from: endTime)
        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )
        do {
            try center.startMonitoring(.morningGuard, during: schedule)
            return true
        } catch {
            #if DEBUG
            print("DeviceActivity monitoring error: \(error)")
            #endif
            isGuardActive = false
            guardEndTime = nil
            timer?.cancel()
            store.clearAllSettings()
            persistState()
            alertError = "Couldn't start the guard. Try again."
            return false
        }
    }

    // MARK: - Countdown Timer
    private func startCountdownTimer() {
        timer?.cancel()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateCountdown()
            }
    }

    private func updateCountdown() {
        guard let endTime = guardEndTime else { return }
        if endTime.timeIntervalSinceNow <= 0 { endMorningGuard() }
    }

    // MARK: - Resume after app relaunch
    func resumeTimerIfNeeded() {
        // Sync with whatever the extension wrote while we were backgrounded
        // (a schedule- or usage-triggered guard may have started or ended).
        isGuardActive = defaults.bool(forKey: "isGuardActive")
        guardEndTime = defaults.object(forKey: "guardEndTime") as? Date

        if isGuardActive, let endTime = guardEndTime {
            if endTime > Date() {
                // Countdown-based guard still running.
                startCountdownTimer()
                applyScreenTimeRestrictions()
            } else {
                // Expired while the app was away.
                endMorningGuard()
            }
        } else if isGuardActive {
            // Schedule-managed block (bedtime) with no app countdown. Keep the
            // shields on and the guard locked — don't tear it down on open.
            applyScreenTimeRestrictions()
        } else {
            // No guard should be active — clear any shields a finished guard
            // may have left behind while the app was closed.
            store.clearAllSettings()
        }
    }

    // MARK: - Bedtime block state
    /// True when a schedule-managed bedtime block currently owns the shields:
    /// active, but with no morning countdown. (Morning guards always set an end.)
    var isBedtimeBlockActive: Bool { isGuardActive && guardEndTime == nil }

    /// The end of the bedtime window that currently contains `now`, computed from
    /// the schedule so the UI can show a countdown even though the block itself is
    /// managed by the DeviceActivity schedule (which crosses midnight).
    var bedtimeBlockEnd: Date? {
        guard scheduledGuardEnabled else { return nil }
        let cal = Calendar.current
        let now = Date()
        let c = cal.dateComponents([.hour, .minute], from: scheduledGuardStartTime)
        guard let todayStart = cal.date(bySettingHour: c.hour ?? 22, minute: c.minute ?? 0, second: 0, of: now)
        else { return nil }
        let duration = Double(scheduledGuardDurationHours) * 3600
        // The active window could have started today or yesterday (crosses midnight).
        for start in [todayStart, cal.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart] {
            let end = start.addingTimeInterval(duration)
            if now >= start && now < end { return end }
        }
        return nil
    }

    // MARK: - Caffeine Anchor
    /// The time the guard first activated today. Anchors the "wait 90 min before
    /// coffee" window and stays fixed for the whole day, so restarting or
    /// re-activating the guard never resets the countdown.
    var caffeineAnchor: Date? {
        guard let anchor = defaults.object(forKey: "mg.caffeineAnchor") as? Date,
              Calendar.current.isDateInToday(anchor) else { return nil }
        return anchor
    }

    private func recordCaffeineAnchor() {
        if caffeineAnchor == nil { defaults.set(Date(), forKey: "mg.caffeineAnchor") }
    }

    // MARK: - Notifications
    private func scheduleHalfwayNotification(endTime: Date) {
        guard notifyAtHalfway else { return }
        let halfwayDate = endTime.addingTimeInterval(-Double(windowDurationMinutes) * 30)
        NotificationService.shared.schedule(
            id: "halfway",
            title: "Halfway through ☀️",
            body: "Halfway through your morning window. Keep going.",
            at: halfwayDate
        )
    }

    /// Scheduled up-front for the window's end so it fires even when the guard
    /// ends while the app is closed (endMorningGuard only runs in-process).
    private func scheduleCompletionNotification(endTime: Date) {
        guard notifyOnCompletion else { return }
        NotificationService.shared.schedule(
            id: "complete",
            title: "Morning window complete 🌤️",
            body: "Morning window done. Social apps are back.",
            at: endTime
        )
    }

    // MARK: - Morning Auto-Block

    func updateMorningAutoBlock() {
        guard !isLoadingState else { return }
        center.stopMonitoring([DeviceActivityName.morningAutoBlock])
        guard morningAutoBlockEnabled else { return }
        guard !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty else { return }

        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: morningAutoBlockTime)
        // Clamp the window so it can't cross midnight, which would make intervalEnd
        // precede intervalStart — and keep it ≥15 min (DeviceActivity's minimum),
        // or startMonitoring throws for wake times within 15 min of midnight.
        var startMinutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let endMinutes = min(startMinutes + windowDurationMinutes, 23 * 60 + 59)
        if endMinutes - startMinutes < 15 { startMinutes = max(0, endMinutes - 15) }
        let startComps = DateComponents(hour: startMinutes / 60, minute: startMinutes % 60)
        let endComps = DateComponents(hour: endMinutes / 60, minute: endMinutes % 60)

        let schedule = DeviceActivitySchedule(intervalStart: startComps, intervalEnd: endComps, repeats: true)
        do {
            try center.startMonitoring(.morningAutoBlock, during: schedule)
        } catch {
            #if DEBUG
            print("Morning auto-block monitoring error: \(error)")
            #endif
        }
    }

    // MARK: - Phone-Use Trigger
    // Always on: whenever blocked apps are set, using them 5 AM–noon starts the guard.
    // `force: false` (app launch) keeps an existing registration alive — re-registering
    // resets the usage accumulated toward the 1-minute threshold, so opening this app
    // mid-morning must not restart the count.
    func updateUsageTrigger(force: Bool = true) {
        guard !isLoadingState else { return }
        guard !selectedApps.applicationTokens.isEmpty || !selectedApps.categoryTokens.isEmpty else {
            center.stopMonitoring([DeviceActivityName.usageTrigger])
            return
        }
        if !force && center.activities.contains(.usageTrigger) { return }
        center.stopMonitoring([DeviceActivityName.usageTrigger])

        // Monitor 5 AM – noon daily; fire after 1 min of use (Apple's minimum).
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 5, minute: 0),
            intervalEnd: DateComponents(hour: 12, minute: 0),
            repeats: true
        )
        let event = DeviceActivityEvent(
            applications: selectedApps.applicationTokens,
            categories: selectedApps.categoryTokens,
            threshold: DateComponents(minute: 1)
        )
        do {
            try center.startMonitoring(.usageTrigger, during: schedule, events: [.usageTrigger: event])
        } catch {
            #if DEBUG
            print("Usage trigger monitoring error: \(error)")
            #endif
        }
    }

    // MARK: - Scheduled (Bedtime) Guard
    func updateScheduledGuard() {
        guard !isLoadingState else { return }
        center.stopMonitoring([DeviceActivityName.scheduledGuard])
        guard scheduledGuardEnabled else {
            // Turned off. Stopping the monitor cancels its pending end event, so if
            // a bedtime block is active right now (its signature: active with no
            // countdown end time), lift it here instead of stranding the shields.
            defaults.set(false, forKey: "mg.bedtimeActive")
            if isGuardActive && guardEndTime == nil {
                store.clearAllSettings()
                isGuardActive = false
                persistState()
            }
            return
        }

        let cal = Calendar.current
        let startComps = cal.dateComponents([.hour, .minute], from: scheduledGuardStartTime)
        let endTime = scheduledGuardStartTime.addingTimeInterval(Double(scheduledGuardDurationHours) * 3600)
        let endComps = cal.dateComponents([.hour, .minute], from: endTime)

        let schedule = DeviceActivitySchedule(
            intervalStart: startComps,
            intervalEnd: endComps,
            repeats: true
        )
        do {
            try center.startMonitoring(.scheduledGuard, during: schedule)
        } catch {
            #if DEBUG
            print("Scheduled guard monitoring error: \(error)")
            #endif
        }
    }

    // MARK: - Persistence
    private func persistState() {
        defaults.set(isGuardActive, forKey: "isGuardActive")
        // Keep guardEndTime in the SAME store as isGuardActive (the App Group)
        // so they can never be cleared/loaded out of sync.
        defaults.set(guardEndTime, forKey: "guardEndTime")
        defaults.set(windowDurationMinutes, forKey: "windowDurationMinutes")
        persistSelectedApps()
        // Guard state changed → keep the home-screen widgets in sync.
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func loadPersistedState() {
        isLoadingState = true
        defer {
            isLoadingState = false
            // Register the persistent schedules exactly once, after all values load.
            if morningAutoBlockEnabled { updateMorningAutoBlock() }
            if scheduledGuardEnabled { updateScheduledGuard() }
            // Don't force: a live registration keeps its accumulated usage.
            updateUsageTrigger(force: false)
        }
        // Fresh-install cleanup. The marker lives in the SAME container we wipe,
        // so it can only be missing when the container is genuinely new. (It used
        // to live in UserDefaults.standard — which iOS deletes on uninstall while
        // the group container can survive — so a reinstall wiped saved apps.)
        if !defaults.bool(forKey: "mg.groupInstalled") {
            if !UserDefaults.standard.bool(forKey: "mg.installed") {
                defaults.dictionaryRepresentation().keys.forEach { defaults.removeObject(forKey: $0) }
            }
            defaults.set(true, forKey: "mg.groupInstalled")
            UserDefaults.standard.set(true, forKey: "mg.installed")
        }
        isGuardActive = defaults.bool(forKey: "isGuardActive")
        // Migrate any legacy value from UserDefaults.standard, then read from the App Group.
        guardEndTime = defaults.object(forKey: "guardEndTime") as? Date
            ?? UserDefaults.standard.object(forKey: "guardEndTime") as? Date
        windowDurationMinutes = defaults.integer(forKey: "windowDurationMinutes").nonZero ?? 60
        weekendsEnabled = defaults.object(forKey: "weekendsEnabled") as? Bool ?? true
        firstUnlockEnabled = defaults.object(forKey: "firstUnlockEnabled") as? Bool ?? true
        notifyAtHalfway = defaults.object(forKey: "notifyAtHalfway") as? Bool ?? true
        notifyOnCompletion = defaults.object(forKey: "notifyOnCompletion") as? Bool ?? true
        scheduledGuardEnabled = defaults.object(forKey: "scheduledGuardEnabled") as? Bool ?? false
        if let saved = defaults.object(forKey: "scheduledGuardStartTime") as? Date {
            scheduledGuardStartTime = saved
        }
        scheduledGuardDurationHours = defaults.integer(forKey: "scheduledGuardDurationHours").nonZero ?? 9
        morningAutoBlockEnabled = defaults.object(forKey: "morningAutoBlockEnabled") as? Bool ?? false
        if let saved = defaults.object(forKey: "morningAutoBlockTime") as? Date {
            morningAutoBlockTime = saved
        }
        // Prefer the App Group copy; fall back to the standard-defaults backup
        // if the group copy is missing (container hiccup, migration, etc.).
        let selectionData = defaults.data(forKey: "selectedApps")
            ?? UserDefaults.standard.data(forKey: "selectedAppsBackup")
        if let data = selectionData,
           let saved = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selectedApps = saved
            // Heal the group copy so the extension shields the right apps.
            if defaults.data(forKey: "selectedApps") == nil {
                defaults.set(data, forKey: "selectedApps")
            }
        }
    }
}

// MARK: - DeviceActivityName Extension
extension DeviceActivityName {
    static let morningGuard    = Self("morningGuard")
    static let scheduledGuard  = Self("scheduledGuard")
    static let morningAutoBlock = Self("morningAutoBlock")
    static let usageTrigger    = Self("usageTrigger")
}

extension DeviceActivityEvent.Name {
    static let usageTrigger = Self("usageTrigger")
}

// MARK: - Int Helper
private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
