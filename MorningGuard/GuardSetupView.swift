import SwiftUI
import FamilyControls

struct GuardSetupView: View {
    @EnvironmentObject var guardVM: GuardViewModel
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                MorningGradient().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Duration + weekends
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Block duration")
                            DurationCard()
                        }

                        // App picker
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Apps to block")
                            AppPickerCard(showPicker: $showPicker)
                        }

                        // Auto-activate
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Auto-activate")
                            MorningAutoBlockCard()
                        }

                        // Bedtime guard
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Bedtime Guard")
                            ScheduledGuardCard()
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Guard")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.clear, for: .navigationBar)
            .familyActivityPicker(isPresented: $showPicker, selection: $guardVM.selectedApps)
        }
    }
}

// MARK: - Duration Card
struct DurationCard: View {
    @EnvironmentObject var guardVM: GuardViewModel

    var body: some View {
        VStack(spacing: 14) {
            Text("\(guardVM.windowDurationMinutes) min")
                .font(.mg("Raleway-SemiBold", 40))
                .foregroundStyle(guardVM.isGuardActive ? Color.secondary : Color("Sunrise"))

            // While a guard is running the window is fixed; changing it here would
            // desync the countdown, the completion notification, and the shield lift.
            Text(guardVM.isGuardActive ? "locked while guard is active" : "block window length")
                .font(.caption)
                .foregroundStyle(Color.secondaryText)

            Slider(
                value: Binding(
                    get: { Double(guardVM.windowDurationMinutes) },
                    set: { guardVM.windowDurationMinutes = Int($0) }
                ),
                in: 15...120,
                step: 15
            )
            .tint(Color("Sunrise"))
            .disabled(guardVM.isGuardActive)

            HStack {
                Text("15m")
                Spacer()
                Text("2h")
            }
            .font(.caption2)
            .foregroundStyle(Color.secondaryText)

            Divider().opacity(0.35)

            HStack {
                Text("Include weekends")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appPrimaryText)
                Spacer()
                Toggle("", isOn: $guardVM.weekendsEnabled)
                    .tint(Color("Sunrise"))
                    .labelsHidden()
            }
        }
        .padding(20)
        .background(morningCard)
        .padding(.horizontal)
    }
}

// MARK: - App Picker Card
struct AppPickerCard: View {
    @EnvironmentObject var guardVM: GuardViewModel
    @Binding var showPicker: Bool

    var selectedCount: Int {
        guardVM.selectedApps.applicationTokens.count + guardVM.selectedApps.categoryTokens.count
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                guard !guardVM.isGuardActive else { return }
                showPicker = true
            } label: {
                HStack {
                    Image(systemName: "apps.iphone")
                        .foregroundStyle(guardVM.isGuardActive ? Color.secondary : Color("Sunrise"))
                        .frame(width: 28)
                    Text("Choose apps")
                        .foregroundStyle(guardVM.isGuardActive ? Color.secondary : Color.appPrimaryText)
                    Spacer()
                    if selectedCount > 0 {
                        Text("\(selectedCount) selected")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(guardVM.isGuardActive ? Color.secondary : Color("Sunrise"))
                    }
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color("WarmTan").opacity(0.6))
                        .font(.caption)
                }
                .padding(16)
            }
            .disabled(guardVM.isGuardActive)

            if guardVM.isGuardActive {
                Divider().opacity(0.35).padding(.horizontal, 14)
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                    Text("App selection is locked while guard is running.")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(morningCard)
        .padding(.horizontal)
    }
}

// MARK: - Scheduled Guard Card
struct ScheduledGuardCard: View {
    @EnvironmentObject var guardVM: GuardViewModel

    var body: some View {
        // Once a bedtime block is running, it's committed — no escape-hatch toggle
        // and no editing its window until it ends on its own.
        let locked = guardVM.isBedtimeBlockActive

        return VStack(spacing: 0) {
            ToggleRow(
                icon: "moon.fill",
                title: "Scheduled Guard",
                subtitle: "Automatically activate guard at a set time each day",
                isOn: $guardVM.scheduledGuardEnabled,
                locked: locked
            )

            if locked {
                Divider().opacity(0.35).padding(.horizontal, 14)
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                    Text("The block is running now — it lifts on its own when the window ends.")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            if guardVM.scheduledGuardEnabled && !locked {
                Divider().opacity(0.35).padding(.horizontal, 14)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start time")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appPrimaryText)
                        Text("Guard activates at this time daily")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                    }
                    Spacer()
                    DatePicker(
                        "",
                        selection: $guardVM.scheduledGuardStartTime,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    .onChange(of: guardVM.scheduledGuardStartTime) { _, _ in
                        guardVM.updateScheduledGuard()
                    }
                }
                .padding(14)

                Divider().opacity(0.35).padding(.horizontal, 14)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duration")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appPrimaryText)
                        Text("\(guardVM.scheduledGuardDurationHours) hr block")
                            .font(.caption)
                            .foregroundStyle(Color.secondaryText)
                    }
                    Spacer()
                    Stepper("", value: $guardVM.scheduledGuardDurationHours, in: 1...12)
                        .labelsHidden()
                        .onChange(of: guardVM.scheduledGuardDurationHours) { _, _ in
                            guardVM.updateScheduledGuard()
                        }
                }
                .padding(14)
            }
        }
        .background(morningCard)
        .padding(.horizontal)
    }
}

// MARK: - Morning Auto-Block Card

struct MorningAutoBlockCard: View {
    @EnvironmentObject var guardVM: GuardViewModel

    var body: some View {
        VStack(spacing: 0) {
            ToggleRow(
                icon: "sun.horizon.fill",
                title: "Schedule wake time",
                subtitle: "Blocks activate automatically, no app launch needed",
                isOn: $guardVM.morningAutoBlockEnabled
            )

            if guardVM.morningAutoBlockEnabled {
                Divider().opacity(0.35).padding(.horizontal, 14)

                HStack {
                    Text("Wake time")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.appPrimaryText)
                    Spacer()
                    DatePicker("", selection: $guardVM.morningAutoBlockTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .onChange(of: guardVM.morningAutoBlockTime) { _, _ in
                            guardVM.updateMorningAutoBlock()
                        }
                }
                .padding(14)
            }
        }
        .background(morningCard)
        .padding(.horizontal)
    }
}

// MARK: - Reusable Toggle Row
struct ToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var locked: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color("DawnPink"))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundStyle(Color("Sunrise"))
                    .font(.system(size: 14))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.appPrimaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer()
            if locked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
            }
            Toggle("", isOn: $isOn)
                .tint(Color("Sunrise"))
                .labelsHidden()
                .disabled(locked)
        }
        .padding(14)
    }
}

// MARK: - Shared card background
var morningCard: some View {
    RoundedRectangle(cornerRadius: 18)
        .fill(Color.appCardFill)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        .compositingGroup()
}
