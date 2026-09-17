import Testing
import Foundation
@testable import MorningGuard

/// `MorningTasks` is the only piece of the narrowed app holding state that has
/// to survive a process boundary (the widget reads it) and roll over at
/// midnight, so it is where the bugs would be.
struct MorningTasksTests {

    /// Each test gets its own defaults suite so they can't see each other's writes.
    private func freshDefaults() -> UserDefaults {
        let suite = "test.morningtasks.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test func startsWithNothingDone() {
        let tasks = MorningTasks(defaults: freshDefaults())
        #expect(tasks.isDone(.water) == false)
        #expect(tasks.isDone(.light) == false)
        #expect(tasks.allDone == false)
    }

    @Test func markingATaskPersistsIt() {
        let defaults = freshDefaults()
        MorningTasks(defaults: defaults).setDone(.water, true)

        // A second instance stands in for a relaunch reading the same store.
        #expect(MorningTasks(defaults: defaults).isDone(.water) == true)
    }

    @Test func allDoneRequiresBothTasks() {
        let tasks = MorningTasks(defaults: freshDefaults())
        tasks.setDone(.water, true)
        #expect(tasks.allDone == false)
        tasks.setDone(.light, true)
        #expect(tasks.allDone == true)
    }

    @Test func togglingOffClearsTheTask() {
        let tasks = MorningTasks(defaults: freshDefaults())
        tasks.setDone(.water, true)
        tasks.setDone(.water, false)
        #expect(tasks.isDone(.water) == false)
    }

    @Test func progressWithinTheSameDaySurvivesAReset() {
        let defaults = freshDefaults()
        let tasks = MorningTasks(defaults: defaults)
        tasks.setDone(.water, true)

        tasks.resetIfNewDay(now: Date())

        #expect(tasks.isDone(.water) == true)
    }

    @Test func yesterdaysProgressIsClearedOnANewDay() {
        let defaults = freshDefaults()
        let tasks = MorningTasks(defaults: defaults)
        tasks.setDone(.water, true)
        tasks.setDone(.light, true)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        tasks.resetIfNewDay(now: tomorrow)

        #expect(tasks.isDone(.water) == false)
        #expect(tasks.isDone(.light) == false)
    }

    /// Rolling over must not silently reset again on every later call that day,
    /// which would wipe progress made right after the rollover.
    @Test func resettingIsIdempotentWithinTheNewDay() {
        let defaults = freshDefaults()
        let tasks = MorningTasks(defaults: defaults)
        tasks.setDone(.water, true)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        tasks.resetIfNewDay(now: tomorrow)
        tasks.setDone(.light, true)
        tasks.resetIfNewDay(now: tomorrow)

        #expect(tasks.isDone(.light) == true)
    }
}
