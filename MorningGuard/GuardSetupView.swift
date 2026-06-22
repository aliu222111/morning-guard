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

                        // Duration picker
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Block duration")
                            DurationCard()
                        }

                        // App picker
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Apps to block")
                            AppPickerCard(showPicker: $showPicker)
                        }

                        // Schedule options
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(text: "Schedule")
                            ScheduleCard()
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

    let steps = [15, 30, 45, 60, 90, 120]

    var body: some View {
        VStack(spacing: 14) {
            Text("\(guardVM.windowDurationMinutes) min")
                .font(.custom("Georgia", size: 40))
                .foregroundStyle(Color("Sunrise"))

            Text("after first phone unlock")
                .font(.caption)
                .foregroundStyle(Color("WarmTan"))

            Slider(
                value: Binding(
                    get: { Double(guardVM.windowDurationMinutes) },
                    set: { guardVM.windowDurationMinutes = Int($0) }
                ),
                in: 15...120,
                step: 15
            )
            .tint(Color("Sunrise"))

            HStack {
                Text("15m")
                Spacer()
                Text("2h")
            }
            .font(.caption2)
            .foregroundStyle(Color("WarmTan"))
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
                showPicker = true
            } label: {
                HStack {
                    Image(systemName: "apps.iphone")
                        .foregroundStyle(Color("Sunrise"))
                        .frame(width: 28)
                    Text("Choose apps")
                        .foregroundStyle(Color("WarmBrown"))
                    Spacer()
                    if selectedCount > 0 {
                        Text("\(selectedCount) selected")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color("Sunrise"))
                    }
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color("WarmTan").opacity(0.6))
                        .font(.caption)
                }
                .padding(16)
            }
        }
        .background(morningCard)
        .padding(.horizontal)
    }
}

// MARK: - Schedule Card
struct ScheduleCard: View {
    @EnvironmentObject var guardVM: GuardViewModel

    var body: some View {
        VStack(spacing: 0) {
            ToggleRow(
                icon: "moon.fill",
                title: "Night reset",
                subtitle: "Re-arm guard automatically after midnight",
                isOn: .constant(true)
            )
            Divider().padding(.leading, 56)
            ToggleRow(
                icon: "calendar.badge.clock",
                title: "Weekends",
                subtitle: "Keep guard active on Saturdays and Sundays",
                isOn: $guardVM.weekendsEnabled
            )
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
                    .foregroundStyle(Color("WarmBrown"))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Color("WarmTan"))
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(Color("Sunrise"))
                .labelsHidden()
        }
        .padding(14)
    }
}

// MARK: - Shared card background
var morningCard: some View {
    RoundedRectangle(cornerRadius: 18)
        .fill(.white.opacity(0.7))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color("WarmTan").opacity(0.25), lineWidth: 0.5)
        )
}
