import Foundation
import Combine
import WidgetKit

/// The two things Morning Guard asks you to do while the block is up.
///
/// State lives in the App Group rather than standard defaults because the
/// widget process reads the same values, and it is keyed by day so yesterday's
/// ticks don't greet you in the morning.
final class MorningTasks: ObservableObject {

    enum Task: String, CaseIterable, Identifiable {
        case water
        case light

        var id: String { rawValue }

        var title: String {
            switch self {
            case .water: return "Drink a glass of water"
            case .light: return "Get morning light"
            }
        }

        var detail: String {
            switch self {
            case .water:
                return "You've been asleep for hours. Rehydrating now kick-starts your metabolism."
            case .light:
                return "Bright light early sets your circadian clock for the day."
            }
        }

        var symbol: String {
            switch self {
            case .water: return "drop.fill"
            case .light: return "sun.max.fill"
            }
        }
    }

    static let shared = MorningTasks(defaults: UserDefaults(suiteName: StreakLedger.suiteName) ?? .standard)

    private let defaults: UserDefaults
    private let doneKey = "mg.tasks.done"
    private let dayKey  = "mg.tasks.day"

    @Published private(set) var done: Set<Task> = []

    init(defaults: UserDefaults) {
        self.defaults = defaults
        resetIfNewDay()
    }

    func isDone(_ task: Task) -> Bool { done.contains(task) }

    var allDone: Bool { Task.allCases.allSatisfy(done.contains) }

    var doneCount: Int { done.count }

    func setDone(_ task: Task, _ value: Bool) {
        if value { done.insert(task) } else { done.remove(task) }
        persist()
    }

    func toggle(_ task: Task) { setDone(task, !isDone(task)) }

    /// Clears progress when the calendar day has moved on. Safe to call as often
    /// as you like: it only writes when the stored day actually differs.
    func resetIfNewDay(now: Date = Date()) {
        let today = StreakLedger.dayString(now)
        guard defaults.string(forKey: dayKey) != today else {
            done = loadDone()
            return
        }
        done = []
        defaults.set(today, forKey: dayKey)
        persist()
    }

    private func loadDone() -> Set<Task> {
        let raw = defaults.stringArray(forKey: doneKey) ?? []
        return Set(raw.compactMap(Task.init(rawValue:)))
    }

    private func persist() {
        defaults.set(done.map(\.rawValue), forKey: doneKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
