import SwiftUI

// MARK: - Guided Routine Flow

/// A full-screen, one-step-at-a-time guided walk through the morning routine in
/// the user's chosen order. Shows progress, narrates each step when the audio
/// guide is on, and ends with a completion summary.
struct GuidedRoutineView: View {
    @ObservedObject var store: RoutineStore
    @StateObject private var journalStore = JournalStore()
    @StateObject private var sunlightVM = SunlightViewModel()
    @AppStorage("mg.audioGuide") private var audioGuide = false
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var showVoiceDownloadHint = false

    private var steps: [RoutineItem] { store.activeItems }
    private var isSummary: Bool { index >= steps.count }
    private var currentStep: RoutineItem? { isSummary ? nil : steps[index] }

    var body: some View {
        ZStack {
            MorningGradient().ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 20) {
                        if let step = currentStep {
                            stepIntro(step)
                            stepBody(step)
                        } else {
                            summary
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }

                if !isSummary { footer }
            }
        }
        .onAppear {
            store.resetIfNewDay()
            narrateCurrent()
        }
        .onDisappear {
            sunlightVM.stopTracking()
            SpeechService.shared.stop()
        }
        .alert("Get a more natural voice", isPresented: $showVoiceDownloadHint) {
            Button("OK") {}
        } message: {
            Text("For a human-sounding guide, download a premium voice: Settings ▸ Accessibility ▸ Spoken Content ▸ Voices ▸ English ▸ tap a voice like \"Ava\" to download. Morning Guard will use it automatically.")
        }
    }

    // MARK: Header (progress + close)

    private var header: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    // With zero enabled steps the view opens on the summary; going
                    // "back" would index steps[-1] and crash — dismiss instead.
                    if (index > 0 || isSummary) && !steps.isEmpty {
                        SpeechService.shared.stop()
                        withAnimation(.easeInOut) {
                            index = isSummary ? max(0, steps.count - 1) : max(0, index - 1)
                        }
                        narrateCurrent()
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: (index > 0 || isSummary) ? "chevron.left" : "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                        .frame(width: 44, height: 44)
                        .background(Color.appCardFill, in: Circle())
                }
                .accessibilityLabel((index > 0 || isSummary) ? "Back" : "Close routine")
                Spacer()
                Text(isSummary ? "Complete" : "Step \(index + 1) of \(steps.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appPrimaryText)
                Spacer()
                // Audio guide quick-toggle
                Button {
                    audioGuide.toggle()
                    if audioGuide {
                        if !SpeechService.shared.hasHumanVoiceInstalled { showVoiceDownloadHint = true }
                        narrateCurrent()
                    } else {
                        SpeechService.shared.stop()
                    }
                } label: {
                    Image(systemName: audioGuide ? "speaker.wave.2.fill" : "speaker.slash")
                        .font(.subheadline)
                        .foregroundStyle(audioGuide ? Color("Sunrise") : Color.secondaryText)
                        .frame(width: 44, height: 44)
                        .background(Color.appCardFill, in: Circle())
                }
                .accessibilityLabel("Audio guide")
                .accessibilityValue(audioGuide ? "On" : "Off")
            }

            ProgressView(value: isSummary ? 1 : Double(index) / Double(max(steps.count, 1)))
                .tint(Color("Sunrise"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: Step intro

    @ViewBuilder
    private func stepIntro(_ step: RoutineItem) -> some View {
        VStack(spacing: 8) {
            Doodle(name: step.doodle ?? "", maxHeight: 46) {
                Image(systemName: step.icon)
                    .font(.system(size: 30))
                    .foregroundStyle(Color("Sunrise"))
            }
            .frame(width: 72, height: 72)
            .background(Color("Sunrise").opacity(0.12), in: Circle())
            Text(step.title)
                .font(.mg("Raleway-SemiBold", 26))
                .foregroundStyle(Color.appPrimaryText)
            Text(step.subtitle)
                .font(.mg("Lora-Regular", 15))
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
            if store.isDone(id: step.id) {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("Sunrise"))
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: Step body (reuses the self-contained step views)

    @ViewBuilder
    private func stepBody(_ item: RoutineItem) -> some View {
        switch item {
        case .builtin(let step):
            switch step {
            case .water:
                WaterStepView(store: store, audioGuide: audioGuide)
            case .movement:
                MovementStepView(store: store, audioGuide: audioGuide)
            case .light:
                LightStepView(store: store, sunlightVM: sunlightVM)
            case .meditation:
                MeditationStepView(store: store, audioGuide: audioGuide)
            case .journal:
                JournalStepView(store: store, journalStore: journalStore, audioGuide: audioGuide, prompt: JournalPrompts.today)
            case .task:
                TaskStepView(store: store)
            }
        case .custom(let custom):
            CustomStepView(store: store, custom: custom)
        }
    }

    // MARK: Footer (next / finish)

    private var footer: some View {
        let done = currentStep.map { store.isDone(id: $0.id) } ?? false
        return Button { advance() } label: {
            Text(index == steps.count - 1 ? "Finish" : "Next")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(done ? Color("Sunrise") : Color("Sunrise").opacity(0.5))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: Summary

    private var summary: some View {
        VStack(spacing: 18) {
            // Your completion doodle, falling back to the sun icon.
            Doodle(name: "doodle-complete", maxHeight: 140) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(store.allDone ? Color(red: 1.0, green: 0.96, blue: 0.78) : Color("Sunrise"))
                    .shadow(color: store.allDone ? Color(red: 1.0, green: 0.9, blue: 0.5).opacity(0.8) : .clear, radius: 12)
            }
            .padding(.top, 24)

            Text(store.allDone ? "Routine complete" : "Nice start")
                .font(.mg("Raleway-SemiBold", 28))
                .foregroundStyle(Color.appPrimaryText)

            Text(store.allDone
                 ? "You completed every step. Have a great day."
                 : "You finished \(store.doneCount) of \(store.totalCount). You can pick the rest up any time.")
                .font(.mg("Lora-Regular", 16))
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            if store.allDone {
                let streak = StreakLedger.displayStreak(UserDefaults(suiteName: StreakLedger.suiteName))
                if streak > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Color("Sunrise"))
                        Text(streak == 1 ? "1-day streak — it starts today" : "\(streak)-day streak")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appPrimaryText)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color("Sunrise").opacity(0.12)))
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { i, step in
                    if i > 0 { Divider().opacity(0.35) }
                    HStack(spacing: 12) {
                        Image(systemName: store.isDone(id: step.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(store.isDone(id: step.id) ? Color("Sunrise") : Color.secondary)
                        Text(step.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.appPrimaryText)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
            .background(stepSummaryCardBG)

            Button { dismiss() } label: {
                Text("Done")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color("Sunrise"))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.top, 4)
        }
        .onAppear {
            if audioGuide {
                SpeechService.shared.speak(store.allDone
                    ? "Routine complete. You did everything. Have a great day."
                    : "Nice start. You can finish the rest whenever you're ready.")
            }
        }
    }

    private var stepSummaryCardBG: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.appCardFill)
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
            .compositingGroup()
    }

    // MARK: Navigation

    private func advance() {
        sunlightVM.stopTracking()
        SpeechService.shared.stop()
        withAnimation(.easeInOut) {
            index += 1
        }
        narrateCurrent()
    }

    private func narrateCurrent() {
        guard audioGuide, let step = currentStep else { return }
        SpeechService.shared.speak(step.narration)
    }
}

// MARK: - Customize Routine

/// Reorder and enable/disable routine steps. Order + enabled state persist via
/// the shared RoutineStore.
struct CustomizeRoutineView: View {
    @ObservedObject var store: RoutineStore
    @Environment(\.dismiss) private var dismiss
    @State private var showAddCustom = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.items) { item in
                        HStack(spacing: 12) {
                            Doodle(name: item.doodle ?? "", maxHeight: 24) {
                                Image(systemName: item.icon).foregroundStyle(Color("Sunrise"))
                            }
                            .frame(width: 28, height: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color.appPrimaryText)
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(Color.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { store.isEnabled(id: item.id) },
                                set: { store.setEnabled(id: item.id, $0) }
                            ))
                            .labelsHidden()
                            .tint(Color("Sunrise"))
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove { source, destination in
                        store.move(from: source, to: destination)
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            switch store.items[i] {
                            case .custom(let c):
                                store.deleteCustom(id: c.id)
                            case .builtin(let step):
                                // Built-ins can't be removed entirely, but "delete"
                                // should still do what you expect: take the step out
                                // of the routine. It stays in the "Disabled built-in
                                // steps" list below so you can add it back.
                                store.setEnabled(step, false)
                            }
                        }
                    }
                    .listRowBackground(Color.appCardFill.opacity(0.7))
                } header: {
                    Text("Drag to reorder, toggle to include")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                        .tracking(1.2)
                } footer: {
                    Text("Your guided morning walks through the enabled steps in this order. Swipe a custom activity to delete it.")
                        .font(.caption)
                        .foregroundStyle(Color.secondaryText)
                }

                let disabledBuiltins = RoutineStep.allCases.filter { !store.isEnabled($0) }
                if !disabledBuiltins.isEmpty {
                    Section {
                        ForEach(disabledBuiltins) { step in
                            Button {
                                store.setEnabled(step, true)
                            } label: {
                                HStack(spacing: 12) {
                                    Doodle(name: step.doodle, maxHeight: 24) {
                                        Image(systemName: step.icon).foregroundStyle(Color("Sunrise"))
                                    }
                                    .frame(width: 28, height: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(step.title)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color.appPrimaryText)
                                        Text(step.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(Color.secondaryText)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(Color("Sunrise"))
                                }
                            }
                            .listRowBackground(Color.appCardFill.opacity(0.7))
                        }
                    } header: {
                        Text("Disabled built-in steps")
                    } footer: {
                        Text("Tap to re-enable a step in your routine.")
                            .font(.caption).foregroundStyle(Color.secondaryText)
                    }
                }

                Section {
                    Button { showAddCustom = true } label: {
                        Label("Add custom activity", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color("Sunrise"))
                    }
                    .listRowBackground(Color.appCardFill.opacity(0.7))
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(MorningGradient().ignoresSafeArea())
            .navigationTitle("Customize routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddCustom) { AddCustomStepView(store: store) }
        }
    }
}

// MARK: - Custom Step (guided body) + Add Custom

/// The body shown in the guided flow for a user-defined activity.
struct CustomStepView: View {
    @ObservedObject var store: RoutineStore
    let custom: CustomStep

    private var done: Bool { store.isDone(id: custom.id) }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(Color("Sunrise"))
                .padding(.top, 8)

            Text(custom.title)
                .font(.mg("Raleway-Medium", 22))
                .foregroundStyle(Color.appPrimaryText)
                .multilineTextAlignment(.center)

            if !custom.note.isEmpty {
                Text(custom.note)
                    .font(.mg("Lora-Regular", 15))
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Button {
                store.toggleDone(id: custom.id)
            } label: {
                Label(done ? "Done" : "Mark done", systemImage: done ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(done ? Color("PillGreen") : Color("Sunrise"))
                    .foregroundStyle(done ? Color("PillGreenText") : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.appCardFill)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                .compositingGroup()
        )
    }
}

struct AddCustomStepView: View {
    @ObservedObject var store: RoutineStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("e.g. Cold shower, Read 10 pages", text: $title)
                        .foregroundStyle(Color.appPrimaryText)
                }
                Section("Note (optional)") {
                    TextField("A short reminder of what to do", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .foregroundStyle(Color.appPrimaryText)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MorningGradient().ignoresSafeArea())
            .navigationTitle("Custom activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addCustom(title: title, note: note)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
