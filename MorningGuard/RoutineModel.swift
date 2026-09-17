import SwiftUI
import Combine
import WidgetKit

// MARK: - Routine Step (built-ins)

/// A built-in activity in the morning routine. The raw value is the stable key
/// used for persistence, so don't rename them.
enum RoutineStep: String, CaseIterable, Codable, Identifiable {
    case water
    case movement
    case light
    case meditation
    case journal
    case task

    var id: String { rawValue }

    var title: String {
        switch self {
        case .water:      return "Hydrate"
        case .movement:   return "Move"
        case .light:      return "Morning light"
        case .meditation: return "Breathe"
        case .journal:    return "Journal"
        case .task:       return "Set your focus"
        }
    }

    var subtitle: String {
        switch self {
        case .water:      return "Drink a glass of water"
        case .movement:   return "Your exercises and stretches"
        case .light:      return "Get bright light to set your clock"
        case .meditation: return "Box breathing to settle in"
        case .journal:    return "A prompt or a free write"
        case .task:       return "The one thing that matters today"
        }
    }

    var icon: String {
        switch self {
        case .water:      return "drop.fill"
        case .movement:   return "figure.strengthtraining.traditional"
        case .light:      return "sun.max.fill"
        case .meditation: return "wind"
        case .journal:    return "book.closed.fill"
        case .task:       return "star.fill"
        }
    }

    /// Hand-drawn pixel-art asset for this step (see Assets.xcassets/doodle-step-*).
    var doodle: String { "doodle-step-\(rawValue)" }

    var narration: String {
        switch self {
        case .water:      return "First, drink a glass of water. Hydration sets up everything that follows."
        case .movement:   return "Time to move. Do each exercise when you're ready, then mark it done."
        case .light:      return "Get some morning light. Step outside and measure how bright it is."
        case .meditation: return "Let's take a few rounds of box breathing to settle in."
        case .journal:    return "Take a moment to journal. You can use today's prompt or write freely."
        case .task:       return "Finally, set the one most important thing you need to do today."
        }
    }
}

// MARK: - Custom Step

/// A user-defined routine activity. Its id is prefixed "custom:" so it never
/// collides with a built-in RoutineStep raw value.
struct CustomStep: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var note: String

    init(title: String, note: String = "") {
        self.id = "custom:\(UUID().uuidString)"
        self.title = title
        self.note = note
    }
}

// MARK: - Routine Item (unified)

/// One entry in the routine: either a built-in step or a custom activity.
enum RoutineItem: Identifiable {
    case builtin(RoutineStep)
    case custom(CustomStep)

    var id: String {
        switch self {
        case .builtin(let s): return s.rawValue
        case .custom(let c):  return c.id
        }
    }

    var title: String {
        switch self {
        case .builtin(let s): return s.title
        case .custom(let c):  return c.title
        }
    }

    var subtitle: String {
        switch self {
        case .builtin(let s): return s.subtitle
        case .custom(let c):  return c.note.isEmpty ? "Your custom activity" : c.note
        }
    }

    var icon: String {
        switch self {
        case .builtin(let s): return s.icon
        case .custom:         return "sparkles"
        }
    }

    /// Pixel-art asset name for built-in steps; nil for custom (falls back to icon).
    var doodle: String? {
        switch self {
        case .builtin(let s): return s.doodle
        case .custom:         return nil
        }
    }

    var narration: String {
        switch self {
        case .builtin(let s): return s.narration
        case .custom(let c):  return c.note.isEmpty ? "Time for \(c.title)." : "\(c.title). \(c.note)"
        }
    }

    var builtinStep: RoutineStep? {
        if case .builtin(let s) = self { return s }
        return nil
    }
}

// MARK: - Stored configuration

private struct RoutineItemConfig: Codable {
    var id: String
    var enabled: Bool
}

// MARK: - Routine Store

/// Single source of truth for the routine's item order, which items are
/// enabled, which are done today, and the user's custom activities.
@MainActor
final class RoutineStore: ObservableObject {

    static let shared = RoutineStore()

    @Published private(set) var order: [String]          // item ids in order
    @Published private(set) var enabledIDs: Set<String>
    @Published private(set) var doneToday: Set<String>   // item ids done today
    @Published private(set) var customSteps: [CustomStep]

    private let orderKey = "mg.routineItemsV2"
    private let customKey = "mg.customSteps"
    private let doneKey = "mg.routineDoneToday"
    private let dateKey = "mg.routineDate"

    private static let dayFormatter: DateFormatter = {
        let fmt = DateFormatter()
        // Fixed locale so the day key can't shift with a region/12-hour change —
        // matches StreakLedger, otherwise a rollover comparison can miss and
        // leave yesterday's "done" state on screen.
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    private init() {
        // Custom steps first, so order reconciliation can see them.
        if let data = UserDefaults.standard.data(forKey: customKey),
           let list = try? JSONDecoder().decode([CustomStep].self, from: data) {
            customSteps = list
        } else {
            customSteps = []
        }

        if let data = UserDefaults.standard.data(forKey: orderKey),
           let configs = try? JSONDecoder().decode([RoutineItemConfig].self, from: data) {
            order = configs.map(\.id)
            enabledIDs = Set(configs.filter(\.enabled).map(\.id))
        } else {
            let defaultOrder = RoutineStep.allCases.map(\.id)
            order = defaultOrder
            enabledIDs = Set(defaultOrder)
        }

        doneToday = []
        reconcile()
        resetIfNewDay()
    }

    /// Ensure every built-in and existing custom step is present in `order`, and
    /// drop ids that no longer resolve (e.g. a deleted custom step).
    private func reconcile() {
        let customIDs = Set(customSteps.map(\.id))
        let validIDs = Set(RoutineStep.allCases.map(\.id)).union(customIDs)

        // Drop dangling ids.
        order.removeAll { !validIDs.contains($0) }
        enabledIDs.formIntersection(validIDs)

        // Append any missing built-ins, then missing customs.
        for step in RoutineStep.allCases where !order.contains(step.id) {
            order.append(step.id); enabledIDs.insert(step.id)
        }
        for c in customSteps where !order.contains(c.id) {
            order.append(c.id); enabledIDs.insert(c.id)
        }
    }

    // MARK: Derived

    func item(for id: String) -> RoutineItem? {
        if let step = RoutineStep(rawValue: id) { return .builtin(step) }
        if let c = customSteps.first(where: { $0.id == id }) { return .custom(c) }
        return nil
    }

    /// All items in order (enabled or not) — used by the customize screen.
    var items: [RoutineItem] { order.compactMap(item(for:)) }

    /// Enabled items in order — this is the guided flow.
    var activeItems: [RoutineItem] { items.filter { enabledIDs.contains($0.id) } }

    var totalCount: Int { activeItems.count }
    var doneCount: Int { activeItems.filter { doneToday.contains($0.id) }.count }
    var allDone: Bool { totalCount > 0 && doneCount == totalCount }
    var progress: Double { totalCount == 0 ? 0 : Double(doneCount) / Double(totalCount) }

    // MARK: id-based API

    func isEnabled(id: String) -> Bool { enabledIDs.contains(id) }
    func isDone(id: String) -> Bool { doneToday.contains(id) }

    func setEnabled(id: String, _ on: Bool) {
        if on { enabledIDs.insert(id) } else { enabledIDs.remove(id) }
        persistOrder()
    }

    func markDone(id: String) {
        resetIfNewDay()
        doneToday.insert(id)
        persistDone()
        // A fully completed routine counts as "the morning happened".
        if allDone { StreakLedger.credit(UserDefaults(suiteName: StreakLedger.suiteName)) }
    }
    func markNotDone(id: String) { doneToday.remove(id); persistDone() }
    func toggleDone(id: String) { isDone(id: id) ? markNotDone(id: id) : markDone(id: id) }

    func move(from source: IndexSet, to destination: Int) {
        order.move(fromOffsets: source, toOffset: destination)
        persistOrder()
    }

    // MARK: RoutineStep convenience (keeps the step views unchanged)

    func isEnabled(_ step: RoutineStep) -> Bool { isEnabled(id: step.rawValue) }
    func isDone(_ step: RoutineStep) -> Bool { isDone(id: step.rawValue) }
    func setEnabled(_ step: RoutineStep, _ on: Bool) { setEnabled(id: step.rawValue, on) }
    func markDone(_ step: RoutineStep) { markDone(id: step.rawValue) }
    func markNotDone(_ step: RoutineStep) { markNotDone(id: step.rawValue) }
    func toggleDone(_ step: RoutineStep) { toggleDone(id: step.rawValue) }

    // MARK: Custom CRUD

    func addCustom(title: String, note: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let step = CustomStep(title: trimmed, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        customSteps.append(step)
        order.append(step.id)
        enabledIDs.insert(step.id)
        persistCustom(); persistOrder()
    }

    func updateCustom(_ step: CustomStep) {
        guard let i = customSteps.firstIndex(where: { $0.id == step.id }) else { return }
        customSteps[i] = step
        persistCustom()
    }

    func deleteCustom(id: String) {
        customSteps.removeAll { $0.id == id }
        order.removeAll { $0 == id }
        enabledIDs.remove(id)
        doneToday.remove(id)
        persistCustom(); persistOrder(); persistDone()
    }

    // MARK: Persistence

    private func persistOrder() {
        let configs = order.map { RoutineItemConfig(id: $0, enabled: enabledIDs.contains($0)) }
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: orderKey)
        }
        mirrorProgressToWidgets()
    }

    private func persistCustom() {
        if let data = try? JSONEncoder().encode(customSteps) {
            UserDefaults.standard.set(data, forKey: customKey)
        }
    }

    private func persistDone() {
        UserDefaults.standard.set(Array(doneToday), forKey: doneKey)
        mirrorProgressToWidgets()
    }

    /// The widgets can't read this store's standard-defaults keys, so mirror
    /// today's progress into the App Group and refresh the timelines.
    private func mirrorProgressToWidgets() {
        let group = UserDefaults(suiteName: StreakLedger.suiteName)
        group?.set(doneCount, forKey: "mg.routineDoneCount")
        group?.set(totalCount, forKey: "mg.routineTotalCount")
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Clears today's completion (and the legacy per-step flags) at day rollover.
    func resetIfNewDay() {
        let today = Self.dayFormatter.string(from: Date())
        let stored = UserDefaults.standard.string(forKey: dateKey)

        if stored != today {
            doneToday = []
            UserDefaults.standard.set(today, forKey: dateKey)
            UserDefaults.standard.removeObject(forKey: doneKey)
            UserDefaults.standard.removeObject(forKey: "mg.todayTask")
            ["mg.waterDone", "mg.pushUpsDone", "mg.squatsDone", "mg.sitUpsDone", "mg.stretchDone"].forEach {
                UserDefaults.standard.set(false, forKey: $0)
            }
            ExerciseStore.shared.resetDoneForNewDay()
            mirrorProgressToWidgets()
        } else if doneToday.isEmpty {
            let raw = UserDefaults.standard.stringArray(forKey: doneKey) ?? []
            doneToday = Set(raw)
        }
    }
}

// MARK: - Exercise (editable list for the Move step)

enum ExerciseKind: String, Codable {
    case reps    // counted (e.g. push-ups)
    case timed   // held for a duration (e.g. a stretch)
}

struct Exercise: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var icon: String
    var kind: ExerciseKind
    var amount: Int   // reps when .reps; seconds when .timed

    init(name: String,
         icon: String = "figure.strengthtraining.functional",
         kind: ExerciseKind = .reps,
         amount: Int = 10) {
        self.id = UUID().uuidString
        self.name = name
        self.icon = icon
        self.kind = kind
        self.amount = amount
    }

    /// e.g. "10 reps" or "30s"
    var amountLabel: String {
        switch kind {
        case .reps:  return "\(amount) reps"
        case .timed: return amount >= 60 ? "\(amount / 60)m \(amount % 60)s" : "\(amount)s"
        }
    }

    /// Spoken instruction for the audio guide.
    var spoken: String {
        switch kind {
        case .reps:  return "\(name). \(amount) reps."
        case .timed: return "\(name). Hold for \(amount) seconds."
        }
    }
}

/// Common stretches the user can add with one tap.
enum StretchLibrary {
    static let all: [Exercise] = [
        Exercise(name: "Forward fold",      icon: "figure.flexibility", kind: .timed, amount: 30),
        Exercise(name: "Hamstring stretch", icon: "figure.flexibility", kind: .timed, amount: 30),
        Exercise(name: "Quad stretch",      icon: "figure.flexibility", kind: .timed, amount: 30),
        Exercise(name: "Shoulder stretch",  icon: "figure.flexibility", kind: .timed, amount: 25),
        Exercise(name: "Neck rolls",        icon: "figure.flexibility", kind: .timed, amount: 20),
        Exercise(name: "Chest opener",      icon: "figure.flexibility", kind: .timed, amount: 25),
        Exercise(name: "Hip flexor stretch", icon: "figure.flexibility", kind: .timed, amount: 30),
        Exercise(name: "Cat-cow",           icon: "figure.flexibility", kind: .timed, amount: 30),
        Exercise(name: "Child's pose",      icon: "figure.flexibility", kind: .timed, amount: 40),
        Exercise(name: "Calf stretch",      icon: "figure.flexibility", kind: .timed, amount: 30)
    ]
}

/// Editable list of exercises/stretches shown in the Move step, with per-day
/// completion. Independent of RoutineStore so the movement card can be edited
/// without touching the routine order.
@MainActor
final class ExerciseStore: ObservableObject {

    static let shared = ExerciseStore()

    @Published private(set) var exercises: [Exercise]
    @Published private(set) var doneToday: Set<String>

    private let listKey = "mg.exercises"
    private let doneKey = "mg.exercisesDone"
    private let dateKey = "mg.exercisesDoneDate"

    private static let dayFormatter: DateFormatter = {
        let fmt = DateFormatter()
        // Fixed locale so the day key can't shift with a region/12-hour change
        // (matches StreakLedger).
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    private init() {
        if let data = UserDefaults.standard.data(forKey: listKey),
           let list = try? JSONDecoder().decode([Exercise].self, from: data), !list.isEmpty {
            exercises = list
        } else {
            exercises = [
                Exercise(name: "Push-ups", icon: "figure.strengthtraining.traditional", kind: .reps, amount: 10),
                Exercise(name: "Squats",   icon: "figure.cross.training", kind: .reps, amount: 15),
                Exercise(name: "Sit-ups",  icon: "figure.core.training", kind: .reps, amount: 10),
                Exercise(name: "Forward fold", icon: "figure.flexibility", kind: .timed, amount: 30)
            ]
        }

        let today = Self.dayFormatter.string(from: Date())
        if UserDefaults.standard.string(forKey: dateKey) != today {
            doneToday = []
            UserDefaults.standard.set(today, forKey: dateKey)
            UserDefaults.standard.removeObject(forKey: doneKey)
        } else {
            doneToday = Set(UserDefaults.standard.stringArray(forKey: doneKey) ?? [])
        }
    }

    var allDone: Bool { !exercises.isEmpty && exercises.allSatisfy { doneToday.contains($0.id) } }

    func isDone(_ ex: Exercise) -> Bool { doneToday.contains(ex.id) }

    func toggle(_ ex: Exercise) {
        if doneToday.contains(ex.id) { doneToday.remove(ex.id) } else { doneToday.insert(ex.id) }
        persistDone()
    }

    func add(name: String, kind: ExerciseKind = .reps, amount: Int = 10,
             icon: String = "figure.strengthtraining.functional") {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        exercises.append(Exercise(name: trimmed, icon: icon, kind: kind, amount: amount))
        persistList()
    }

    /// Adds a copy of a library exercise (fresh id so it can be tweaked/removed).
    func add(_ exercise: Exercise) {
        exercises.append(Exercise(name: exercise.name, icon: exercise.icon,
                                  kind: exercise.kind, amount: exercise.amount))
        persistList()
    }

    func rename(_ ex: Exercise, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let i = exercises.firstIndex(where: { $0.id == ex.id }) else { return }
        exercises[i].name = trimmed
        persistList()
    }

    func update(_ ex: Exercise) {
        guard let i = exercises.firstIndex(where: { $0.id == ex.id }) else { return }
        exercises[i] = ex
        persistList()
    }

    func remove(at offsets: IndexSet) {
        for i in offsets { doneToday.remove(exercises[i].id) }
        exercises.remove(atOffsets: offsets)
        persistList(); persistDone()
    }

    func move(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
        persistList()
    }

    func resetDoneForNewDay() {
        doneToday = []
        UserDefaults.standard.set(Self.dayFormatter.string(from: Date()), forKey: dateKey)
        UserDefaults.standard.removeObject(forKey: doneKey)
    }

    private func persistList() {
        if let data = try? JSONEncoder().encode(exercises) {
            UserDefaults.standard.set(data, forKey: listKey)
        }
    }

    private func persistDone() {
        UserDefaults.standard.set(Array(doneToday), forKey: doneKey)
    }
}
