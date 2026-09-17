import SwiftUI
import UIKit
import Combine

// MARK: - Doodle (hand-drawn illustration slot)

/// A slot for your own hand-drawn art. Drop a PNG named `name` into
/// Assets.xcassets (the empty `doodle-*` image sets are already there) and it
/// appears automatically. Until then, `fallback` renders — so the app always
/// looks intentional whether or not the art has been added yet.
struct Doodle<Fallback: View>: View {
    let name: String
    var maxHeight: CGFloat = 120
    @ViewBuilder var fallback: () -> Fallback

    var body: some View {
        if UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .interpolation(.none)          // keep the pixel-art edges crisp
                .scaledToFit()
                .frame(maxHeight: maxHeight)
                .accessibilityHidden(true)
        } else {
            fallback()
        }
    }
}

extension Doodle where Fallback == EmptyView {
    init(_ name: String, maxHeight: CGFloat = 120) {
        self.init(name: name, maxHeight: maxHeight) { EmptyView() }
    }
}

// MARK: - Wake-up animation (plays once per launch)

/// A short pixel-art scene of someone waking up and getting up to start their
/// morning. It steps through frames once, then rests on the final frame — and
/// won't replay when you return to the Home tab within the same app session.
struct WakeUpAnimation: View {
    private static var hasPlayed = false
    private let frameCount = 6
    private let interval = 0.5

    @State private var frame = 1

    var body: some View {
        Doodle("doodle-wake-\(frame)", maxHeight: 132)
            .frame(maxWidth: .infinity)
            .onAppear(perform: start)
    }

    private func start() {
        // Already ran this session → jump straight to the resting final frame.
        guard !Self.hasPlayed else { frame = frameCount; return }
        Self.hasPlayed = true
        frame = 1
        advance()
    }

    private func advance() {
        guard frame < frameCount else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
            withAnimation(.easeInOut(duration: 0.15)) { frame += 1 }
            advance()
        }
    }
}

struct HomeView: View {
    @EnvironmentObject var guardVM: GuardViewModel
    @StateObject private var routineStore = RoutineStore.shared
    @StateObject private var weather = WeatherService()

    @State private var formattedDate: String = Date().formatted(date: .complete, time: .omitted)
    @State private var showGuidedRoutine = false
    @State private var showCustomize = false
    @State private var streak = 0

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default:     return "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                MorningGradient()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {

                        // Header
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(greeting)
                                        .font(.mg("Raleway-SemiBold", 32))
                                        .foregroundStyle(Color.appPrimaryText)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(formattedDate)
                                        .font(.subheadline)
                                        .foregroundStyle(Color.secondaryText)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                Spacer(minLength: 8)
                                Button { showCustomize = true } label: {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color("Sunrise"))
                                        .frame(width: 44, height: 44)
                                        .background(Color.appCardFill, in: Circle())
                                }
                                .accessibilityLabel("Customize routine")
                            }

                            // Streak + weather live on their own row so they don't
                            // crowd the greeting and settings button up top.
                            if streak > 0 || weather.available {
                                HStack(spacing: 8) {
                                    StreakChip(streak: streak)
                                    if weather.available {
                                        WeatherChip(weather: weather)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Wake-up scene — plays once per launch, then rests
                        WakeUpAnimation()
                            .padding(.horizontal)

                        // Hero — Start Morning Routine
                        RoutineHeroCard(store: routineStore) { showGuidedRoutine = true }
                            .padding(.horizontal)

                        // Guard status
                        GuardStatusCard()
                            .padding(.horizontal)

                        // Coffee timer (only after the guard has run today)
                        CaffeineTimerCard()
                            .padding(.horizontal)

                        // WeatherKit requires the Apple Weather attribution + a link to
                        // the data sources on any screen that shows weather data.
                        if weather.available, let url = URL(string: "https://weatherkit.apple.com/legal-attribution.html") {
                            Link(destination: url) {
                                Text("Weather data provided by \(Text(Image(systemName: "apple.logo"))) Weather")
                                    .font(.caption2)
                                    .foregroundStyle(Color.secondaryText)
                            }
                            .padding(.horizontal)
                            .padding(.top, 2)
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.top)
                }
            }
            .navigationBarHidden(true)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                formattedDate = Date().formatted(date: .complete, time: .omitted)
                refreshStreak()   // day rolled over — a stale streak may have expired
            }
            .onAppear {
                routineStore.resetIfNewDay()
                refreshStreak()
            }
            .onChange(of: guardVM.isGuardActive) { _, _ in refreshStreak() }
            .task { weather.refresh() }
            .fullScreenCover(isPresented: $showGuidedRoutine, onDismiss: refreshStreak) {
                GuidedRoutineView(store: routineStore)
            }
            .sheet(isPresented: $showCustomize) {
                CustomizeRoutineView(store: routineStore)
            }
        }
    }

    private func refreshStreak() {
        streak = StreakLedger.displayStreak(UserDefaults(suiteName: StreakLedger.suiteName))
    }
}

// MARK: - Streak Chip

/// Small header pill showing the current day streak. Hidden until a streak exists.
struct StreakChip: View {
    let streak: Int

    var body: some View {
        if streak > 0 {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color("Sunrise"))
                Text("\(streak)")
                    .font(.mg("Raleway-SemiBold", 17))
                    .foregroundStyle(Color.appPrimaryText)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(Color.appCardFill)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 1)
                    .compositingGroup()
            )
            .accessibilityLabel("\(streak) day streak")
        }
    }
}

// MARK: - Routine Hero Card

struct RoutineHeroCard: View {
    @ObservedObject var store: RoutineStore
    let start: () -> Void

    private var allDone: Bool { store.allDone }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Morning Routine")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                        .tracking(1.2)
                        .textCase(.uppercase)
                    Text(allDone ? "All done for today" : "\(store.doneCount) of \(store.totalCount) done")
                        .font(.mg("Raleway-SemiBold", 24))
                        .foregroundStyle(Color.appPrimaryText)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color("Sunrise").opacity(0.15), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: store.progress)
                        .stroke(Color("Sunrise"), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 18, weight: .semibold))
                        // A risen, yellowish-white sun once the routine is complete.
                        .foregroundStyle(allDone ? Color(red: 1.0, green: 0.96, blue: 0.78) : Color("Sunrise"))
                        .shadow(color: allDone ? Color(red: 1.0, green: 0.9, blue: 0.5).opacity(0.8) : .clear, radius: 6)
                }
                .frame(width: 54, height: 54)
                .animation(.easeInOut, value: store.progress)
            }

            Button(action: start) {
                Label(allDone ? "Review routine" : (store.doneCount > 0 ? "Continue routine" : "Start morning routine"),
                      systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color("Sunrise"))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appCardFill)
                .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
                .compositingGroup()
        )
    }
}

// MARK: - Weather Chip

struct WeatherChip: View {
    @ObservedObject var weather: WeatherService

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: weather.conditionSymbol)
                .font(.title3)
                .foregroundStyle(Color("Sunrise"))
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text(weather.temperatureText)
                        .font(.mg("Raleway-SemiBold", 17))
                        .foregroundStyle(Color.appPrimaryText)
                    if !weather.highText.isEmpty {
                        Text("H:\(weather.highText)  L:\(weather.lowText)")
                            .font(.caption2)
                            .foregroundStyle(Color.secondaryText)
                    }
                }
                if !weather.cityName.isEmpty {
                    Text(weather.cityName)
                        .font(.caption2)
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(Color.appCardFill)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 1)
                .compositingGroup()
        )
    }
}

// MARK: - Morning Gradient Background
struct MorningGradient: View {
    // Top of the gradient: warm dawn (light) / deep espresso brown (dark).
    private let topColor = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.11, blue: 0.08, alpha: 1)
            : UIColor(red: 1.0, green: 0.97, blue: 0.93, alpha: 1)
    })
    // Bottom of the gradient: light morning sky / slightly warmer brown (dark).
    private let bottomColor = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.22, green: 0.15, blue: 0.11, alpha: 1)
            : UIColor(red: 0.96, green: 0.98, blue: 1.0, alpha: 1)
    })

    var body: some View {
        LinearGradient(
            colors: [topColor, bottomColor],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Guard Status Card
struct GuardStatusCard: View {
    @EnvironmentObject var guardVM: GuardViewModel
    @State private var displayTime: String = "--:--"
    @State private var displayProgress: Double = 0
    @State private var bedtimeDisplay: String = "--"

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Morning Guard")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.secondaryText)
                    .tracking(1.2)
                    .textCase(.uppercase)
                Spacer()
                StatusPill(isActive: guardVM.isGuardActive)
            }

            if guardVM.isGuardActive {
                if guardVM.guardEndTime != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayTime)
                            .font(.mg("Raleway-Medium", 48))
                            .foregroundStyle(Color.appPrimaryText)
                        Text("remaining in your morning window")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                    }

                    ProgressView(value: displayProgress)
                        .tint(Color("Sunrise"))
                        .scaleEffect(x: 1, y: 1.5)
                } else {
                    // Schedule-managed bedtime block: countdown to the window's end.
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bedtimeDisplay)
                            .font(.mg("Raleway-Medium", 48))
                            .foregroundStyle(Color.appPrimaryText)
                        Text("until your bedtime block ends")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                    }
                }

            } else {
                Doodle("doodle-resting", maxHeight: 96)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Guard is resting")
                        .font(.mg("Raleway-Medium", 22))
                        .foregroundStyle(Color.appPrimaryText)
                    Text("Tap \"Start now\" or configure auto-block in the Guard tab.")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }

                Button {
                    guardVM.startMorningGuard()
                } label: {
                    Label("Start now", systemImage: "sun.rise.fill")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color("Sunrise"))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.appCardFill)
                .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
                .compositingGroup()
        )
        .onReceive(tick) { _ in refreshDisplay() }
        .onChange(of: guardVM.isGuardActive) { _, _ in refreshDisplay() }
        .onChange(of: guardVM.guardEndTime) { _, _ in refreshDisplay() }
        .onAppear { refreshDisplay() }
    }

    private func refreshDisplay() {
        // Bedtime block: coarse "Xh Ym" countdown to the window's end.
        if guardVM.isBedtimeBlockActive {
            let remaining = max(0, guardVM.bedtimeBlockEnd?.timeIntervalSinceNow ?? 0)
            let h = Int(remaining) / 3600
            let m = (Int(remaining) % 3600) / 60
            bedtimeDisplay = h > 0 ? "\(h)h \(m)m" : "\(m)m"
            return
        }
        guard let endTime = guardVM.guardEndTime else {
            displayTime = "--:--"; displayProgress = 0; return
        }
        let remaining = max(0, endTime.timeIntervalSinceNow)
        let total = Double(guardVM.windowDurationMinutes * 60)
        displayProgress = total > 0 ? min(1, (total - remaining) / total) : 0
        let m = Int(remaining) / 60
        let s = Int(remaining) % 60
        displayTime = String(format: "%d:%02d", m, s)
    }
}

// MARK: - Caffeine Timer Card

/// Shows how long until it's optimal to have caffeine — 90 minutes after the
/// guard first activated today. Anchored to a stable daily timestamp, so it
/// never resets when the guard restarts.
struct CaffeineTimerCard: View {
    @EnvironmentObject var guardVM: GuardViewModel
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var now = Date()

    private var caffeineOpen: Date? {
        guardVM.caffeineAnchor?.addingTimeInterval(90 * 60)
    }

    private var minutesUntil: Int? {
        guard let open = caffeineOpen else { return nil }
        let remaining = open.timeIntervalSince(now)
        return remaining > 0 ? Int(ceil(remaining / 60)) : nil
    }

    private var visible: Bool {
        guardVM.caffeineAnchor != nil && Calendar.current.component(.hour, from: now) < 14
    }

    var body: some View {
        if visible {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "cup.and.heat.waves.fill")
                            .font(.subheadline)
                            .foregroundStyle(Color("Sunrise"))
                        Text("Coffee")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                        Spacer()
                        Text("90 min")
                            .font(.caption2)
                            .foregroundStyle(Color.secondaryText)
                    }
                    if let mins = minutesUntil {
                        Text("in \(mins) min")
                            .font(.mg("Raleway-Medium", 24))
                            .foregroundStyle(Color.appPrimaryText)
                    } else {
                        Text("Open now")
                            .font(.mg("Raleway-Medium", 24))
                            .foregroundStyle(Color("Sunrise"))
                    }
                }
                // Your coffee doodle, if added.
                Doodle("doodle-coffee", maxHeight: 56)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(morningCard)
            .onReceive(tick) { now = $0 }
        }
    }
}

// MARK: - Status Pill
struct StatusPill: View {
    let isActive: Bool
    var body: some View {
        Text(isActive ? "Active" : "Resting")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isActive ? Color("PillGreen") : Color.secondary.opacity(0.15))
            .foregroundStyle(isActive ? Color("PillGreenText") : .secondary)
            .clipShape(Capsule())
    }
}

// MARK: - Section Label
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.secondaryText)
            .tracking(1.2)
            .textCase(.uppercase)
            .padding(.horizontal)
    }
}

