import SwiftUI
import FamilyControls
import CoreText
import AVFoundation
import UIKit

@main
struct MorningGuardApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var guardViewModel = GuardViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("mg.appearance") private var appearance = "dark"

    /// Maps the stored appearance preference to a SwiftUI color scheme.
    /// nil = follow the system setting.
    private var preferredScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    init() {
        registerFonts()
        configureNavigationBarFont()
        resetAudioSession()
    }

    /// Render all navigation-bar titles in Raleway so the Guard/Settings headers
    /// match the Raleway greeting on the Home tab. Transparent background keeps
    /// the morning gradient showing through, as before.
    private func configureNavigationBarFont() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()

        let titleColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.96, green: 0.92, blue: 0.85, alpha: 1)
                : UIColor(red: 0.47, green: 0.28, blue: 0.12, alpha: 1)
        }
        if let large = UIFont(name: "Raleway-SemiBold", size: 32) {
            appearance.largeTitleTextAttributes = [.font: large, .foregroundColor: titleColor]
        }
        if let inline = UIFont(name: "Raleway-SemiBold", size: 17) {
            appearance.titleTextAttributes = [.font: inline, .foregroundColor: titleColor]
        }
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.hasCompletedOnboarding {
                    ContentView()
                        .environmentObject(guardViewModel)
                        .environmentObject(appState)
                } else {
                    OnboardingView()
                        .environmentObject(guardViewModel)
                        .environmentObject(appState)
                }
            }
            // Honor the user's Appearance setting (System / Light / Dark).
            // Adaptive color tokens handle each scheme; see Color+MorningGuard.
            .preferredColorScheme(preferredScheme)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                guardViewModel.refreshAuthorizationStatus()
                guardViewModel.resumeTimerIfNeeded()
                guardViewModel.autoStartIfFirstMorningUnlock()
                // Roll the routine over here too: views that stayed mounted
                // overnight never re-fire onAppear, which left yesterday's
                // progress on screen (and mirrored into the widgets) all morning.
                RoutineStore.shared.resetIfNewDay()
                refreshAffirmations()
            }
        }
    }

    private func registerFonts() {
        let names = ["Raleway-Medium", "Raleway-SemiBold", "Lora-Regular"]
        for name in names {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// Re-tops-up the rolling batch of affirmation notifications on each launch.
    private func refreshAffirmations() {
        let d = UserDefaults.standard
        guard d.bool(forKey: "mg.affirmEnabled") else {
            NotificationService.shared.scheduleAffirmations(enabled: false, wakeMinutes: 0, offsetHours: 0, timesPerDay: 1, customText: "")
            return
        }
        let wake = d.object(forKey: "mg.affirmWakeMinutes") as? Int ?? 420
        let offset = d.object(forKey: "mg.affirmOffsetHours") as? Int ?? 2
        let times = d.object(forKey: "mg.affirmTimesPerDay") as? Int ?? 1
        let useCustom = d.bool(forKey: "mg.affirmUseCustom")
        let custom = useCustom ? (d.string(forKey: "mg.affirmCustom") ?? "") : ""
        let alsoPrebuilt = useCustom && d.bool(forKey: "mg.affirmAlsoPrebuilt")
        NotificationService.shared.scheduleAffirmations(enabled: true, wakeMinutes: wake, offsetHours: offset, timesPerDay: times, customText: custom, alsoIncludePrebuilt: alsoPrebuilt)
    }

    /// Clears any audio session left active by a prior crash/force-quit so the
    /// first audio call after launch can't inherit a wedged state. Runs off the
    /// main thread because setActive can block.
    private func resetAudioSession() {
        DispatchQueue.global(qos: .utility).async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
