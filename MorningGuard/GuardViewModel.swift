import SwiftUI
import FamilyControls
import ManagedSettings
import DeviceActivity
import Combine

@MainActor
class GuardViewModel: ObservableObject {

    // MARK: - Published State
    @Published var isGuardActive: Bool = false
    @Published var guardEndTime: Date?
    @Published var authorizationStatus: AuthorizationStatus = .notDetermined
    @Published var selectedApps: FamilyActivitySelection = FamilyActivitySelection()
    @Published var windowDurationMinutes: Int = 60
    @Published var notifyAtHalfway: Bool = true
    @Published var notifyOnCompletion: Bool = true
    @Published var weekendsEnabled: Bool = true
    @Published var timeRemainingFormatted: String = "--:--"
    @Published var progressFraction: Double = 0.0

    // MARK: - Private
    private let store = ManagedSettingsStore()
    private let center = DeviceActivityCenter()
    private var timer: AnyCancellable?
    private let defaults = UserDefaults(suiteName: "group.com.alexliu.morningguard")!

    enum AuthorizationStatus {
        case notDetermined, authorized, denied
    }

    // MARK: - Init
    init() {
        loadPersistedState()
        resumeTimerIfNeeded()
    }

    // MARK: - Authorization
    func requestAuthorization() async {
        let center = AuthorizationCenter.shared
        do {
            try await center.requestAuthorization(for: .individual)
            authorizationStatus = .authorized
        } catch {
            authorizationStatus = .denied
            print("FamilyControls authorization failed: \(error)")
        }
    }

    // MARK: - Start Morning Guard
    /// Call this when the first phone unlock of the day is detected.
    func startMorningGuard() {
        guard authorizationStatus == .authorized else { return }
        guard !isGuardActive else { return }

        let endTime = Date().addingTimeInterval(Double(windowDurationMinutes) * 60)
        guardEndTime = endTime
        isGuardActive = true
        persistState()

        applyScreenTimeRestrictions()
        scheduleDeviceActivity(until: endTime)
        startCountdownTimer()
        scheduleHalfwayNotification(endTime: endTime)
    }

    // MARK: - End Morning Guard
    func endMorningGuard() {
        isGuardActive = false
        guardEndTime = nil
        progressFraction = 1.0
        timer?.cancel()
        store.clearAllSettings()
        center.stopMonitoring()
        persistState()
        scheduleCompletionNotification()
    }

    // MARK: - Screen Time Restrictions (ManagedSettings)
    private func applyScreenTimeRestrictions() {
        // Shield the selected apps
        store.shield.applications = selectedApps.applicationTokens.isEmpty ? nil : selectedApps.applicationTokens
        store.shield.applicationCategories = selectedApps.categoryTokens.isEmpty ? nil :
            ShieldSettings.ActivityCategoryPolicy.specific(selectedApps.categoryTokens)
    }

    // MARK: - DeviceActivity Monitoring
    private func scheduleDeviceActivity(until endTime: Date) {
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: Calendar.current.component(.hour, from: Date()),
                                         minute: Calendar.current.component(.minute, from: Date())),
            intervalEnd: DateComponents(hour: Calendar.current.component(.hour, from: endTime),
                                        minute: Calendar.current.component(.minute, from: endTime)),
            repeats: false
        )

        do {
            try center.startMonitoring(.morningGuard, during: schedule)
        } catch {
            print("DeviceActivity monitoring error: \(error)")
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
        let remaining = endTime.timeIntervalSinceNow
        if remaining <= 0 {
            endMorningGuard()
            return
        }
        let total = Double(windowDurationMinutes * 60)
        progressFraction = min(1.0, (total - remaining) / total)
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        timeRemainingFormatted = String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Resume after app relaunch
    private func resumeTimerIfNeeded() {
        if isGuardActive, let endTime = guardEndTime, endTime > Date() {
            startCountdownTimer()
            applyScreenTimeRestrictions()
        } else if isGuardActive {
            endMorningGuard()
        }
    }

    // MARK: - Notifications
    private func scheduleHalfwayNotification(endTime: Date) {
        guard notifyAtHalfway else { return }
        let halfwayDate = endTime.addingTimeInterval(-Double(windowDurationMinutes) * 30)
        NotificationService.shared.schedule(
            id: "halfway",
            title: "Halfway through ☀️",
            body: "You're doing great. \(windowDurationMinutes / 2) minutes left in your morning window.",
            at: halfwayDate
        )
    }

    private func scheduleCompletionNotification() {
        guard notifyOnCompletion else { return }
        NotificationService.shared.schedule(
            id: "complete",
            title: "Morning window complete 🌤️",
            body: "Your morning is yours. Social apps are now available.",
            at: Date().addingTimeInterval(1)
        )
    }

    // MARK: - Persistence
    private func persistState() {
        defaults.set(isGuardActive, forKey: "isGuardActive")
        defaults.set(guardEndTime, forKey: "guardEndTime")
        defaults.set(windowDurationMinutes, forKey: "windowDurationMinutes")
    }

    private func loadPersistedState() {
        isGuardActive = defaults.bool(forKey: "isGuardActive")
        guardEndTime = defaults.object(forKey: "guardEndTime") as? Date
        windowDurationMinutes = defaults.integer(forKey: "windowDurationMinutes").nonZero ?? 60
        weekendsEnabled = defaults.object(forKey: "weekendsEnabled") as? Bool ?? true
        notifyAtHalfway = defaults.object(forKey: "notifyAtHalfway") as? Bool ?? true
        notifyOnCompletion = defaults.object(forKey: "notifyOnCompletion") as? Bool ?? true
    }
}

// MARK: - DeviceActivityName Extension
extension DeviceActivityName {
    static let morningGuard = Self("morningGuard")
}

// MARK: - Int Helper
private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}
