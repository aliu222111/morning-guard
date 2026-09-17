import WidgetKit
import SwiftUI
import UIKit

// MARK: - Palette (mirrors the app's warm morning look, dark-mode aware)

private extension Color {
    static let wSunrise = Color(red: 224/255, green: 120/255, blue: 48/255)
    static let wPrimary = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.96, green: 0.92, blue: 0.85, alpha: 1)
            : UIColor(red: 0.47, green: 0.28, blue: 0.12, alpha: 1)
    })
    static let wSecondary = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.80, green: 0.72, blue: 0.62, alpha: 1)
            : UIColor(red: 0.62, green: 0.48, blue: 0.34, alpha: 1)
    })
}

private struct WidgetGradient: View {
    private let top = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.11, blue: 0.08, alpha: 1)
            : UIColor(red: 1.0, green: 0.97, blue: 0.93, alpha: 1)
    })
    private let bottom = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.22, green: 0.15, blue: 0.11, alpha: 1)
            : UIColor(red: 0.96, green: 0.98, blue: 1.0, alpha: 1)
    })
    var body: some View {
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Timeline

struct MorningEntry: TimelineEntry {
    let date: Date
    let isGuardActive: Bool
    let guardEnd: Date?
    let streak: Int
    let best: Int
    let tasksDone: Int
    let tasksTotal: Int

    /// Active for display: an "active" flag with an expired end time means the
    /// guard already lifted while nothing refreshed us — show resting.
    var showsActive: Bool {
        guard isGuardActive else { return false }
        if let end = guardEnd { return end > date }
        return true   // schedule-managed block (no countdown)
    }

    static let sample = MorningEntry(date: .now, isGuardActive: true,
                                     guardEnd: .now.addingTimeInterval(32 * 60),
                                     streak: 5, best: 12, tasksDone: 1, tasksTotal: 2)
}

struct MorningProvider: TimelineProvider {
    func placeholder(in context: Context) -> MorningEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (MorningEntry) -> Void) {
        completion(context.isPreview ? .sample : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MorningEntry>) -> Void) {
        let entry = load()
        // While a countdown runs, pre-compute a "resting" entry dated at the end
        // time so the widget flips on its own even if the budgeted reload lags.
        if entry.showsActive, let end = entry.guardEnd, end > entry.date {
            let resting = MorningEntry(date: end, isGuardActive: false, guardEnd: nil,
                                       streak: entry.streak, best: entry.best,
                                       tasksDone: entry.tasksDone, tasksTotal: entry.tasksTotal)
            completion(Timeline(entries: [entry, resting], policy: .after(end.addingTimeInterval(5))))
        } else {
            completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(30 * 60))))
        }
    }

    private func load() -> MorningEntry {
        let d = UserDefaults(suiteName: StreakLedger.suiteName)
        return MorningEntry(
            date: Date(),
            isGuardActive: d?.bool(forKey: "isGuardActive") ?? false,
            guardEnd: d?.object(forKey: "guardEndTime") as? Date,
            streak: StreakLedger.displayStreak(d),
            best: StreakLedger.best(d),
            tasksDone: (d?.stringArray(forKey: "mg.tasks.done") ?? []).count,
            tasksTotal: 2
        )
    }
}

// MARK: - Streak widget

struct StreakWidgetView: View {
    let entry: MorningEntry

    var body: some View {
        VStack(spacing: 6) {
            Image(entry.streak > 0 ? "doodle-complete" : "doodle-resting")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(height: 60)
            if entry.streak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(Color.wSunrise)
                    Text("\(entry.streak)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.wPrimary)
                        .monospacedDigit()
                }
                Text(entry.streak == 1 ? "day streak" : "day streak · best \(entry.best)")
                    .font(.caption2)
                    .foregroundStyle(Color.wSecondary)
            } else {
                Text("Start a streak")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.wPrimary)
                Text("Guard your morning today")
                    .font(.caption2)
                    .foregroundStyle(Color.wSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .containerBackground(for: .widget) { WidgetGradient() }
    }
}

struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MorningGuard.Streak", provider: MorningProvider()) {
            StreakWidgetView(entry: $0)
        }
        .configurationDisplayName("Morning Streak")
        .description("How many mornings in a row you've protected.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Guard status widget

struct GuardWidgetView: View {
    let entry: MorningEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if family == .systemMedium { medium } else { small }
        }
        .containerBackground(for: .widget) { WidgetGradient() }
    }

    private var small: some View {
        VStack(spacing: 6) {
            if entry.showsActive {
                Image(systemName: "shield.fill")
                    .font(.title2)
                    .foregroundStyle(Color.wSunrise)
                Text("Guard active")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.wPrimary)
                if let end = entry.guardEnd {
                    Text(timerInterval: entry.date...end, countsDown: true)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.wSunrise)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                    Text("until apps unlock")
                        .font(.caption2)
                        .foregroundStyle(Color.wSecondary)
                } else {
                    Text("Bedtime block on")
                        .font(.caption2)
                        .foregroundStyle(Color.wSecondary)
                }
            } else {
                Image("doodle-resting")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(height: 56)
                Text("Guard resting")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.wPrimary)
                if entry.tasksTotal > 0 {
                    Text("Water & light \(entry.tasksDone) of \(entry.tasksTotal)")
                        .font(.caption2)
                        .foregroundStyle(Color.wSecondary)
                }
            }
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            Image(entry.showsActive || entry.streak > 0 ? "doodle-complete" : "doodle-resting")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(height: 74)

            VStack(alignment: .leading, spacing: 4) {
                if entry.showsActive {
                    Text("Guard active")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.wPrimary)
                    if let end = entry.guardEnd {
                        Text(timerInterval: entry.date...end, countsDown: true)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.wSunrise)
                            .monospacedDigit()
                    } else {
                        Text("Bedtime block on")
                            .font(.caption)
                            .foregroundStyle(Color.wSecondary)
                    }
                } else {
                    Text("Guard resting")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.wPrimary)
                    if entry.tasksTotal > 0 {
                        Text("Water & light \(entry.tasksDone) of \(entry.tasksTotal)")
                            .font(.caption)
                            .foregroundStyle(Color.wSecondary)
                    }
                }
                if entry.streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(Color.wSunrise)
                        Text("\(entry.streak) day streak")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.wPrimary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct GuardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MorningGuard.Guard", provider: MorningProvider()) {
            GuardWidgetView(entry: $0)
        }
        .configurationDisplayName("Morning Guard")
        .description("Whether the guard is on, and when your apps unlock.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Bundle

@main
struct MorningGuardWidgetBundle: WidgetBundle {
    var body: some Widget {
        GuardWidget()
        StreakWidget()
    }
}
