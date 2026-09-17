import SwiftUI

struct ContentView: View {
    @EnvironmentObject var guardVM: GuardViewModel
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Today", systemImage: "house")
                }
                .tag(0)

            GuardSetupView()
                .tabItem {
                    Label("Guard", systemImage: "shield")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(Color("Sunrise"))
        .alert("Error", isPresented: Binding(
            get: { guardVM.alertError != nil },
            set: { if !$0 { guardVM.alertError = nil } }
        )) {
            Button("OK") { guardVM.alertError = nil }
        } message: {
            Text(guardVM.alertError ?? "")
        }
    }
}

