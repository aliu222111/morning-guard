import SwiftUI

struct ContentView: View {
    @EnvironmentObject var guardVM: GuardViewModel
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Today", systemImage: "house")
                    }
                    .tag(0)

                GuardSetupView()
                    .tabItem {
                        Label("Guard", systemImage: "person.crop.circle.badge.checkmark")
                    }
                    .tag(1)

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(2)
            }
            .tint(Color("Sunrise"))

            // iOS-style home indicator bar
            HomeIndicatorBar()
        }
    }
}

// MARK: - iOS Home Indicator Bar
struct HomeIndicatorBar: View {
    var body: some View {
        Capsule()
            .fill(Color("WarmBrown").opacity(0.22))
            .frame(width: 134, height: 5)
            .padding(.bottom, 8)
            .allowsHitTesting(false)
    }
}
