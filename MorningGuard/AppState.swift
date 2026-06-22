import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "onboardingComplete") }
    }

    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "onboardingComplete")
    }
}
