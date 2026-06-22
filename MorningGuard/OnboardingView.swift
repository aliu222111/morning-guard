import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var guardVM: GuardViewModel
    @State private var page = 0

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
                        title: "Start your morning\nwithout the scroll.",
                        body: "Morning Guard quietly protects the first hour of your day — no willpower required.",
                        tag: 0
                    )
                    OnboardPage(
                        emoji: "🔒",
                        title: "Your rules,\nyour apps.",
                        body: "Choose exactly which social apps to block. Instagram, TikTok, X — your call.",
                        tag: 1
                    )
                    OnboardPage(
                        emoji: "☀️",
                        title: "It lifts\nautomatically.",
                        body: "When your morning window ends, guard lifts on its own. No friction, no guilt.",
                        tag: 2
                    )
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(maxHeight: .infinity)

                VStack(spacing: 14) {
                    if page < 2 {
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
                            Task {
                                await guardVM.requestAuthorization()
                                NotificationService.shared.requestPermission()
                                appState.hasCompletedOnboarding = true
                            }
                        } label: {
                            Label("Enable Morning Guard", systemImage: "sun.horizon.fill")
                                .font(.body.weight(.medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color("Sunrise"))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                        }
                    }

                    if page < 2 {
                        Button("Skip") {
                            appState.hasCompletedOnboarding = true
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color("WarmTan"))
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
    let title: String
    let body: String
    let tag: Int

    var body: some View {
        VStack(spacing: 24) {
            Text(emoji)
                .font(.system(size: 72))
                .shadow(color: .orange.opacity(0.3), radius: 20)

            Text(title)
                .font(.custom("Georgia", size: 30))
                .italic()
                .foregroundStyle(Color("WarmBrown"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text(body)
                .font(.body)
                .foregroundStyle(Color("WarmTan"))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 280)
        }
        .padding(.horizontal, 32)
        .tag(tag)
    }
}
