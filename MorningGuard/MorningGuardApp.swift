import SwiftUI
import FamilyControls

@main
struct MorningGuardApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var guardViewModel = GuardViewModel()

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
            .task {
                // Request FamilyControls authorization on launch
                await guardViewModel.requestAuthorization()
            }
        }
    }
}
