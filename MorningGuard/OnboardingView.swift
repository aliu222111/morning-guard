import SwiftUI
import UIKit

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var guardVM: GuardViewModel
    @State private var page = 0
    @State private var isAuthorizing = false
    @State private var showDeniedAlert = false

    private let totalPages = 3

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("DawnPink"), Color("CardGold").opacity(0.4), Color("MorningCream")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    OnboardPage(
                        emoji: "🌅",
                        doodle: "doodle-onboard-1",
                        title: "Start your morning\nwithout the scroll.",
                        bodyText: "Morning Guard blocks the apps that steal your attention for a window after you wake. No willpower required.",
                        tag: 0
                    )
                    OnboardPage(
                        emoji: "☀️",
                        doodle: "doodle-onboard-2",
                        title: "Water and daylight,\nnothing else.",
                        bodyText: "Two things worth doing before the day starts. Drink a glass of water, and get some real light on your face.",
                        tag: 1
                    )
                    OnboardPage(
                        emoji: "🔒",
                        doodle: "doodle-onboard-4",
                        title: "It lifts\nautomatically.",
                        bodyText: "When your morning window ends, the guard lifts on its own. We'll notify you halfway through and when it's done.",
                        tag: 2
                    )
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(maxHeight: .infinity)

                VStack(spacing: 14) {
                    if page < totalPages - 1 {
                        Button {
                            withAnimation { page += 1 }
                        } label: {
                            Text("Next")
                                .font(.body.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color("Sunrise"))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                    } else {
                        Button {
                            guard !isAuthorizing else { return }
                            isAuthorizing = true
                            Task {
                                await guardVM.requestAuthorization()
                                isAuthorizing = false
                                if guardVM.authorizationStatus == .authorized {
                                    NotificationService.shared.requestPermission()
                                    appState.hasCompletedOnboarding = true
                                } else {
                                    showDeniedAlert = true
                                }
                            }
                        } label: {
                            Group {
                                if isAuthorizing {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else {
                                    Label("Enable Morning Guard", systemImage: "sun.horizon.fill")
                                        .font(.body.weight(.medium))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("Sunrise").opacity(isAuthorizing ? 0.7 : 1.0))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                        .disabled(isAuthorizing)
                        .alert("Screen Time Access Required", isPresented: $showDeniedAlert) {
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Morning Guard needs Screen Time access to block apps. Enable it in Settings and Screen Time.")
                        }

                        // Without Screen Time access the block cannot run, but the
                        // water and light steps still work, so let them in anyway.
                        Button {
                            NotificationService.shared.requestPermission()
                            appState.hasCompletedOnboarding = true
                        } label: {
                            Text("Not now, explore first")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondaryText)
                        }
                        .disabled(isAuthorizing)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }
}

struct OnboardPage: View {
    let emoji: String
    var doodle: String? = nil
    let title: String
    let bodyText: String
    let tag: Int

    var body: some View {
        VStack(spacing: 24) {
            // Your hand-drawn art if present, otherwise the emoji.
            Doodle(name: doodle ?? "", maxHeight: 160) {
                Text(emoji)
                    .font(.system(size: 72))
                    .shadow(color: .orange.opacity(0.3), radius: 20)
            }

            Text(title)
                .font(.mg("Raleway-SemiBold", 30))
                .foregroundStyle(Color("WarmBrown"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text(bodyText)
                .font(.body)
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 280)
        }
        .padding(.horizontal, 32)
        .tag(tag)
    }
}
