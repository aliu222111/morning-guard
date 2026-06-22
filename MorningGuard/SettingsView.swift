import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var guardVM: GuardViewModel
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                MorningGradient().ignoresSafeArea()

                List {
                    // Blocked apps section
                    Section {
                        BrandAppToggleRow(name: "Instagram") { InstagramLogo(size: 30) }
                        BrandAppToggleRow(name: "TikTok")    { TikTokLogo(size: 30)    }
                        BrandAppToggleRow(name: "X / Twitter") { XTwitterLogo(size: 30) }
                        BrandAppToggleRow(name: "Facebook")  { FacebookLogo(size: 30)  }
                    } header: {
                        Text("Blocked apps")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color("WarmTan"))
                            .tracking(1.2)
                    }
                    .listRowBackground(Color.white.opacity(0.7))

                    // Notifications section
                    Section {
                        ToggleRow(
                            icon: "bell.badge.fill",
                            title: "Halfway reminder",
                            subtitle: "Notified at the midpoint of your window",
                            isOn: $guardVM.notifyAtHalfway
                        )
                        ToggleRow(
                            icon: "checkmark.seal.fill",
                            title: "Completion message",
                            subtitle: "Notified when the guard lifts",
                            isOn: $guardVM.notifyOnCompletion
                        )
                    } header: {
                        Text("Notifications")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color("WarmTan"))
                            .tracking(1.2)
                    }
                    .listRowBackground(Color.white.opacity(0.7))

                    // About section
                    Section {
                        HStack {
                            SettingsIcon(name: "info.circle.fill", color: Color("Sunrise"))
                            Text("Version 1.0")
                                .font(.subheadline)
                                .foregroundStyle(Color("WarmBrown"))
                            Spacer()
                            Text("Morning Guard")
                                .font(.caption)
                                .foregroundStyle(Color("WarmTan"))
                        }
                        .padding(.vertical, 2)

                        Button {
                            appState.hasCompletedOnboarding = false
                        } label: {
                            HStack {
                                SettingsIcon(name: "arrow.counterclockwise", color: .orange)
                                Text("Replay onboarding")
                                    .font(.subheadline)
                                    .foregroundStyle(Color("WarmBrown"))
                            }
                        }
                    } header: {
                        Text("About")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color("WarmTan"))
                            .tracking(1.2)
                    }
                    .listRowBackground(Color.white.opacity(0.7))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.clear, for: .navigationBar)
        }
    }
}

// MARK: - Brand App Toggle Row (uses logo views from HomeView)
struct BrandAppToggleRow<Logo: View>: View {
    let name: String
    @ViewBuilder let logo: () -> Logo
    @State private var isOn: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            logo()
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color("WarmBrown"))
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(Color("Sunrise"))
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Settings Icon
struct SettingsIcon: View {
    let name: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(color.opacity(0.15))
                .frame(width: 30, height: 30)
            Image(systemName: name)
                .foregroundStyle(color)
                .font(.system(size: 13))
        }
    }
}
