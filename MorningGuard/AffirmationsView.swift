import SwiftUI

struct AffirmationsView: View {
    @AppStorage("mg.affirmEnabled")          private var enabled          = false
    @AppStorage("mg.affirmWakeMinutes")      private var wakeMinutes      = 420   // 7:00 AM
    @AppStorage("mg.affirmOffsetHours")      private var offsetHours      = 2
    @AppStorage("mg.affirmTimesPerDay")      private var timesPerDay      = 1
    @AppStorage("mg.affirmCustom")           private var customText       = ""
    @AppStorage("mg.affirmUseCustom")        private var useCustom        = false
    @AppStorage("mg.affirmAlsoPrebuilt")     private var alsoPrebuilt     = false

    @State private var showBank = false

    private var wakeTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: wakeMinutes / 60, minute: wakeMinutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                wakeMinutes = (c.hour ?? 7) * 60 + (c.minute ?? 0)
            }
        )
    }

    private var fireTimesLabel: String {
        let base = wakeMinutes + offsetHours * 60
        let times = (0..<max(1, timesPerDay)).map { n -> String in
            let total = base + n * 240
            let h = (total / 60) % 24
            let m = total % 60
            let d = Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
            return d.formatted(date: .omitted, time: .shortened)
        }
        if times.count == 1 { return times[0] }
        return times.dropLast().joined(separator: ", ") + " and " + times.last!
    }

    private var toggleSection: some View {
        Section {
            Toggle(isOn: $enabled) {
                Text("Daily affirmation").foregroundStyle(Color.appPrimaryText)
            }
            .tint(Color("Sunrise"))
        } footer: {
            Text("An encouraging note \(offsetHours) hour\(offsetHours == 1 ? "" : "s") after you wake. Around \(fireTimesLabel).")
                .font(.caption).foregroundStyle(Color.secondaryText)
        }
    }

    private var timingSection: some View {
        Section("When you wake up") {
            DatePicker("Wake time", selection: wakeTime, displayedComponents: .hourAndMinute)
                .foregroundStyle(Color.appPrimaryText)
            Stepper("Send \(offsetHours) hour\(offsetHours == 1 ? "" : "s") later", value: $offsetHours, in: 1...6)
                .foregroundStyle(Color.appPrimaryText)
        }
    }

    private var frequencySection: some View {
        Section {
            Stepper(
                timesPerDay == 1 ? "Once a day" : "\(timesPerDay) times a day",
                value: $timesPerDay, in: 1...3
            )
            .foregroundStyle(Color.appPrimaryText)
        } header: {
            Text("How often")
        } footer: {
            Text(timesPerDay > 1 ? "Additional reminders send every 4 hours after the first." : "")
                .font(.caption).foregroundStyle(Color.secondaryText)
        }
    }

    private var affirmationSection: some View {
        Section {
            Toggle(isOn: $useCustom) {
                Text("Use my own affirmation").foregroundStyle(Color.appPrimaryText)
            }
            .tint(Color("Sunrise"))
            if useCustom {
                TextField("e.g. Today is mine to shape.", text: $customText, axis: .vertical)
                    .lineLimit(2...4)
                    .foregroundStyle(Color.appPrimaryText)
                    .font(.mg("Lora-Regular", 16))
                Toggle(isOn: $alsoPrebuilt) {
                    Text("Also include a daily affirmation").foregroundStyle(Color.appPrimaryText)
                }
                .tint(Color("Sunrise"))
                Button { showBank = true } label: {
                    Label("Browse the 50 affirmations", systemImage: "text.book.closed")
                        .foregroundStyle(Color("Sunrise"))
                }
            } else {
                Button { showBank = true } label: {
                    Label("Browse the 50 affirmations", systemImage: "text.book.closed")
                        .foregroundStyle(Color("Sunrise"))
                }
            }
        } header: {
            Text("Affirmation")
        } footer: {
            Text(useCustom && alsoPrebuilt
                 ? "Your affirmation plus a daily one from the library will be sent together."
                 : useCustom
                 ? "Your affirmation will be sent every time."
                 : "A different affirmation is chosen each day.")
                .font(.caption).foregroundStyle(Color.secondaryText)
        }
    }

    var body: some View {
        ZStack {
            MorningGradient().ignoresSafeArea()
            Form {
                toggleSection
                if enabled {
                    timingSection
                    frequencySection
                    affirmationSection
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Affirmations")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBank) { AffirmationBankView() }
        .onChange(of: enabled)     { _, on in if on { NotificationService.shared.requestPermission() }; reschedule() }
        .onChange(of: wakeMinutes) { _, _ in reschedule() }
        .onChange(of: offsetHours) { _, _ in reschedule() }
        .onChange(of: timesPerDay) { _, _ in reschedule() }
        .onChange(of: customText)    { _, _ in reschedule() }
        .onChange(of: useCustom)     { _, _ in reschedule() }
        .onChange(of: alsoPrebuilt)  { _, _ in reschedule() }
    }

    private func reschedule() {
        NotificationService.shared.scheduleAffirmations(
            enabled: enabled,
            wakeMinutes: wakeMinutes,
            offsetHours: offsetHours,
            timesPerDay: timesPerDay,
            customText: useCustom ? customText : "",
            alsoIncludePrebuilt: useCustom && alsoPrebuilt
        )
    }
}

// Read-only preview of the affirmation bank.
private struct AffirmationBankView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                MorningGradient().ignoresSafeArea()
                List {
                    ForEach(Array(Affirmations.all.enumerated()), id: \.offset) { _, text in
                        Text(text)
                            .font(.mg("Lora-Regular", 16))
                            .foregroundStyle(Color.appPrimaryText)
                            .listRowBackground(Color.appCardFill.opacity(0.7))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Affirmations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
