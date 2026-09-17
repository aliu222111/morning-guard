import SwiftUI
import UIKit

// MARK: - Shared card background

private var stepCardBG: some View {
    RoundedRectangle(cornerRadius: 18)
        .fill(Color.appCardFill)
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        // Flatten shape+shadow into one layer so SwiftUI rasterizes the shadow
        // from the rounded-rect alpha once, instead of an offscreen pass on
        // every render/scroll tick.
        .compositingGroup()
}

// MARK: - Step view protocol surface
//
// Each step view reports completion to the RoutineStore via `onComplete` so the
// guided flow can auto-advance, and reads `audioGuide` to narrate. They are
// self-contained and reusable both in the guided flow and (potentially) inline.

// MARK: - Water Step

struct WaterStepView: View {
    @ObservedObject var store: RoutineStore
    let audioGuide: Bool

    private var done: Bool { store.isDone(.water) }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "drop.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color("Sunrise"))
                .padding(.top, 8)

            Text("Drink a full glass of water")
                .font(.mg("Raleway-Medium", 22))
                .foregroundStyle(Color.appPrimaryText)
                .multilineTextAlignment(.center)

            Text("You've been asleep for hours. Rehydrating now kick-starts your metabolism and sharpens focus.")
                .font(.mg("Lora-Regular", 15))
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Button {
                if !done {
                    UserDefaults.standard.set(true, forKey: "mg.waterDone")
                    store.markDone(.water)
                    if audioGuide { SpeechService.shared.speak("Good. Hydration sets up everything that follows.") }
                }
            } label: {
                Label(done ? "Done" : "I drank water", systemImage: done ? "checkmark.circle.fill" : "drop.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(done ? Color("PillGreen") : Color("Sunrise"))
                    .foregroundStyle(done ? Color("PillGreenText") : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(done)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(stepCardBG)
    }
}

// MARK: - Movement Step

struct MovementStepView: View {
    @ObservedObject var store: RoutineStore
    @ObservedObject private var exercises = ExerciseStore.shared
    let audioGuide: Bool

    @State private var isGuided = false
    @State private var showEditor = false

    private var allDone: Bool { exercises.allDone }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(exercises.exercises.enumerated()), id: \.element.id) { i, ex in
                if i > 0 { Divider().opacity(0.35) }
                exerciseRow(ex)
            }

            if allDone {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color("Sunrise"))
                    Text("Movement complete").font(.subheadline.weight(.medium)).foregroundStyle(Color("Sunrise"))
                }
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button { showEditor = true } label: {
                Label("Edit exercises", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color("Sunrise"))
            }
            .padding(.top, 12)

            if audioGuide {
                Button {
                    if isGuided { SpeechService.shared.stop(); isGuided = false }
                    else { isGuided = true; SpeechService.shared.speakSequence(movementSequence()) }
                } label: {
                    Text(isGuided ? "Stop guide" : "Guide me")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(isGuided ? Color.red.opacity(0.85) : Color("Sunrise"))
                        .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 10)
            }
        }
        .padding(16)
        .background(stepCardBG)
        .onChange(of: allDone) { _, complete in
            if complete { store.markDone(.movement) } else { store.markNotDone(.movement) }
        }
        .onAppear { if allDone { store.markDone(.movement) } }
        .sheet(isPresented: $showEditor) { EditExercisesView(store: exercises) }
    }

    @ViewBuilder
    private func exerciseRow(_ ex: Exercise) -> some View {
        let done = exercises.isDone(ex)
        HStack(spacing: 12) {
            Image(systemName: ex.icon).foregroundStyle(Color("Sunrise")).frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(ex.name).font(.subheadline.weight(.medium)).foregroundStyle(Color.appPrimaryText)
                Text(ex.amountLabel).font(.caption).foregroundStyle(Color.secondaryText)
            }
            Spacer()
            Button {
                exercises.toggle(ex)
                if !done && audioGuide { SpeechService.shared.speak("Nice work.") }
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(done ? Color("Sunrise") : Color.secondary)
                    .font(.title3)
            }
        }
        .padding(.vertical, 12)
    }

    private func movementSequence() -> [(text: String, preDelay: TimeInterval)] {
        var seq: [(String, TimeInterval)] = [("Let's do your morning movement. Do each one when you're ready.", 0.2)]
        for (i, ex) in exercises.exercises.enumerated() {
            let lead = i == 0 ? "First. " : "Next. "
            // For timed stretches, give roughly the hold time before the next cue.
            let delay: TimeInterval = ex.kind == .timed ? min(Double(ex.amount), 45) : 4.0
            seq.append((lead + ex.spoken, i == 0 ? 1.0 : delay))
        }
        seq.append(("Done. Great work.", 5.0))
        return seq
    }
}

// MARK: - Edit Exercises

struct EditExercisesView: View {
    @ObservedObject var store: ExerciseStore
    @Environment(\.dismiss) private var dismiss
    @State private var showAddCustom = false
    @State private var showStretchLibrary = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.exercises) { ex in
                        NavigationLink {
                            ExerciseDetailView(store: store, exercise: ex)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: ex.icon).foregroundStyle(Color("Sunrise")).frame(width: 24)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(ex.name).font(.subheadline.weight(.medium)).foregroundStyle(Color.appPrimaryText)
                                    Text(ex.amountLabel).font(.caption).foregroundStyle(Color.secondaryText)
                                }
                            }
                        }
                    }
                    .onDelete { store.remove(at: $0) }
                    .onMove { store.move(from: $0, to: $1) }
                    .listRowBackground(Color.appCardFill.opacity(0.7))
                } header: {
                    Text("Your exercises and stretches")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.secondaryText)
                } footer: {
                    Text("Tap to set reps or hold time. Swipe to delete, drag to reorder.")
                        .font(.caption).foregroundStyle(Color.secondaryText)
                }

                Section {
                    Button { showAddCustom = true } label: {
                        Label("Add custom exercise", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color("Sunrise"))
                    }
                    Button { showStretchLibrary = true } label: {
                        Label("Add a common stretch", systemImage: "figure.flexibility")
                            .foregroundStyle(Color("Sunrise"))
                    }
                    .listRowBackground(Color.appCardFill.opacity(0.7))
                }
                .listRowBackground(Color.appCardFill.opacity(0.7))
            }
            .scrollContentBackground(.hidden)
            .background(MorningGradient().ignoresSafeArea())
            .navigationTitle("Edit movement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showAddCustom) { AddExerciseView(store: store) }
            .sheet(isPresented: $showStretchLibrary) { StretchLibraryView(store: store) }
        }
    }
}

// Edit one exercise: name, reps vs timed, and amount.
private struct ExerciseDetailView: View {
    @ObservedObject var store: ExerciseStore
    let exercise: Exercise

    @State private var name = ""
    @State private var kind: ExerciseKind = .reps
    @State private var amount = 10
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $name).foregroundStyle(Color.appPrimaryText)
            }
            Section("Type") {
                Picker("Type", selection: $kind) {
                    Text("Reps").tag(ExerciseKind.reps)
                    Text("Timed (stretch)").tag(ExerciseKind.timed)
                }
                .pickerStyle(.segmented)
            }
            Section(kind == .reps ? "Reps" : "Hold time") {
                if kind == .reps {
                    Stepper("\(amount) reps", value: $amount, in: 1...100)
                } else {
                    Stepper(secondsLabel(amount), value: $amount, in: 5...300, step: 5)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MorningGradient().ignoresSafeArea())
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            name = exercise.name; kind = exercise.kind; amount = exercise.amount
        }
        .onDisappear { save() }
    }

    private func secondsLabel(_ s: Int) -> String {
        s >= 60 ? "\(s / 60)m \(s % 60)s" : "\(s)s"
    }

    private func save() {
        var updated = exercise
        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? exercise.name : name
        updated.kind = kind
        updated.amount = amount
        if kind == .timed && updated.icon == "figure.strengthtraining.functional" {
            updated.icon = "figure.flexibility"
        }
        store.update(updated)
    }
}

// Add a brand-new custom exercise/stretch.
private struct AddExerciseView: View {
    @ObservedObject var store: ExerciseStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var kind: ExerciseKind = .reps
    @State private var amount = 10

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Lunges", text: $name).foregroundStyle(Color.appPrimaryText)
                }
                Section("Type") {
                    Picker("Type", selection: $kind) {
                        Text("Reps").tag(ExerciseKind.reps)
                        Text("Timed (stretch)").tag(ExerciseKind.timed)
                    }
                    .pickerStyle(.segmented)
                }
                Section(kind == .reps ? "Reps" : "Hold time") {
                    if kind == .reps {
                        Stepper("\(amount) reps", value: $amount, in: 1...100)
                    } else {
                        Stepper(amount >= 60 ? "\(amount/60)m \(amount%60)s" : "\(amount)s", value: $amount, in: 5...300, step: 5)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MorningGradient().ignoresSafeArea())
            .navigationTitle("New exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.add(name: name, kind: kind, amount: amount,
                                  icon: kind == .timed ? "figure.flexibility" : "figure.strengthtraining.functional")
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// Pick from common stretches.
private struct StretchLibraryView: View {
    @ObservedObject var store: ExerciseStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(StretchLibrary.all) { stretch in
                    Button {
                        store.add(stretch)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: stretch.icon).foregroundStyle(Color("Sunrise")).frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(stretch.name).font(.subheadline.weight(.medium)).foregroundStyle(Color.appPrimaryText)
                                Text(stretch.amountLabel).font(.caption).foregroundStyle(Color.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "plus.circle").foregroundStyle(Color("Sunrise"))
                        }
                    }
                    .listRowBackground(Color.appCardFill.opacity(0.7))
                }
            }
            .scrollContentBackground(.hidden)
            .background(MorningGradient().ignoresSafeArea())
            .navigationTitle("Common stretches")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

// MARK: - Morning Light Step

struct LightStepView: View {
    @ObservedObject var store: RoutineStore
    @ObservedObject var sunlightVM: SunlightViewModel

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "sun.max.fill").foregroundStyle(Color("Sunrise"))
                if sunlightVM.luxLevel >= 10 {
                    Text(Int(sunlightVM.luxLevel).formatted())
                        .font(.mg("Raleway-Medium", 34))
                        .foregroundStyle(Color.appPrimaryText)
                        .monospacedDigit()
                    Text("lux").font(.subheadline).foregroundStyle(Color.secondaryText)
                } else {
                    Text(sunlightVM.isTracking ? "Measuring light…" : "Ready to measure")
                        .font(.mg("Raleway-Medium", 22))
                        .foregroundStyle(Color.secondaryText)
                }
                Spacer()
                Text(sunlightVM.quality.label)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(sunlightVM.quality.accentColorName).opacity(0.22))
                    .foregroundStyle(Color(sunlightVM.quality.accentColorName))
                    .clipShape(Capsule())
            }

            if sunlightVM.isTracking {
                HStack {
                    Text(sunlightVM.formattedElapsed)
                        .font(.mg("Raleway-Medium", 20))
                        .foregroundStyle(Color.appPrimaryText).monospacedDigit()
                    Text("/ \(sunlightVM.quality.targetLabel)").font(.caption).foregroundStyle(Color.secondaryText)
                    Spacer()
                    if sunlightVM.isGoalMet {
                        Label("Done", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.medium)).foregroundStyle(Color("Sunrise"))
                    }
                }
                ProgressView(value: sunlightVM.progress).tint(Color("Sunrise"))
            }

            Text(sunlightVM.quality.tip).font(.caption).foregroundStyle(Color.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                if sunlightVM.isTracking { sunlightVM.stopTracking() } else { sunlightVM.startTracking() }
            } label: {
                Text(sunlightVM.isTracking ? "Stop" : "Measure light")
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(sunlightVM.isTracking ? Color.red.opacity(0.85) : Color("Sunrise"))
                    .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text("Lay the phone flat or point a camera at the sky. We use whichever camera faces up.")
                .font(.caption2).foregroundStyle(Color.secondaryText).multilineTextAlignment(.center)
        }
        .padding(16)
        .background(stepCardBG)
        .onChange(of: sunlightVM.isGoalMet) { _, met in
            if met { store.markDone(.light) }
        }
        .alert("Camera Access Needed", isPresented: $sunlightVM.permissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Morning Guard measures ambient light with the camera. No images are captured or stored.")
        }
    }
}

// MARK: - Meditation Step

struct MeditationStepView: View {
    @ObservedObject var store: RoutineStore
    let audioGuide: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var breathPhase: BreathPhase = .inhale
    @State private var breathCount = 0
    @State private var breathSeconds = 4
    @State private var breathActive = false
    @State private var breathRounds = 5
    @State private var breathTimer: Timer? = nil
    @State private var circleScale: CGFloat = 0.45

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color("Sunrise").opacity(0.15), lineWidth: 2)
                    .frame(width: 140, height: 140)
                Circle()
                    .fill(Color("Sunrise").opacity(breathActive ? 0.25 : 0.08))
                    .frame(width: 140, height: 140)
                    // Respect Reduce Motion: hold the circle steady and rely on the
                    // phase label + countdown instead of the scaling animation.
                    .scaleEffect(reduceMotion ? 0.72 : circleScale)
                    .animation(reduceMotion ? nil : .easeInOut(duration: Double(breathPhase.seconds)), value: circleScale)

                VStack(spacing: 2) {
                    Text(breathActive ? breathPhase.label : "Box Breathing")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appPrimaryText)
                        .multilineTextAlignment(.center)
                    if breathActive {
                        Text("\(breathSeconds)")
                            .font(.mg("Raleway-Medium", 30))
                            .foregroundStyle(Color("Sunrise"))
                            .monospacedDigit()
                    }
                }
            }

            if breathActive {
                Text("Round \(breathCount / 4 + 1) of \(breathRounds)")
                    .font(.caption).foregroundStyle(Color.secondaryText)
            }

            if !breathActive {
                HStack(spacing: 8) {
                    ForEach([3, 5, 10], id: \.self) { r in
                        Button {
                            breathRounds = r
                        } label: {
                            Text("\(r) rounds")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(breathRounds == r ? Color("Sunrise") : Color("Sunrise").opacity(0.12))
                                .foregroundStyle(breathRounds == r ? .white : Color("Sunrise"))
                                .clipShape(Capsule())
                        }
                    }
                }

                Text("Inhale, hold, exhale, hold, each for 4 seconds.")
                    .font(.caption).foregroundStyle(Color.secondaryText).multilineTextAlignment(.center)
            }

            Button {
                if breathActive { stopBreathing() } else { startBreathing() }
            } label: {
                Text(breathActive ? "Stop" : "Begin")
                    .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(breathActive ? Color.red.opacity(0.85) : Color("Sunrise"))
                    .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background(stepCardBG)
        .onDisappear { breathTimer?.invalidate(); breathTimer = nil }
    }

    private func startBreathing() {
        breathActive = true
        breathCount = 0
        breathPhase = .inhale
        breathSeconds = breathPhase.seconds
        circleScale = 1.0
        if audioGuide { SpeechService.shared.speak("Breathe in.") }
        breathTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in self.tickBreath() }
        }
    }

    private func tickBreath() {
        breathSeconds -= 1
        if breathSeconds <= 0 {
            breathCount += 1
            if breathCount >= breathRounds * 4 {
                stopBreathing()
                store.markDone(.meditation)
                if audioGuide { SpeechService.shared.speak("Well done. Take a moment to sit with that stillness.") }
                return
            }
            breathPhase = breathPhase.next
            breathSeconds = breathPhase.seconds
            withAnimation(.easeInOut(duration: Double(breathPhase.seconds))) {
                circleScale = breathPhase.targetScale
            }
            if audioGuide { SpeechService.shared.speak(breathPhase.label) }
        }
    }

    private func stopBreathing() {
        breathTimer?.invalidate()
        breathTimer = nil
        breathActive = false
        breathCount = 0
        breathSeconds = 4
        withAnimation { circleScale = 0.45 }
    }
}

// MARK: - Journal Step

struct JournalStepView: View {
    @ObservedObject var store: RoutineStore
    @ObservedObject var journalStore: JournalStore
    let audioGuide: Bool
    let prompt: String

    @State private var showPromptJournal = false
    @State private var showFreeJournal = false
    @State private var showJournalHistory = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            journalButton(icon: "quote.bubble.fill", label: "Today's prompt", sub: prompt) { showPromptJournal = true }
            Divider().opacity(0.35)
            journalButton(icon: "pencil", label: "Free write", sub: "Start from a blank page") { showFreeJournal = true }
            if !journalStore.entries.isEmpty {
                Divider().opacity(0.35)
                Button { showJournalHistory = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath").foregroundStyle(Color("Sunrise"))
                        Text("Past entries").font(.subheadline.weight(.medium)).foregroundStyle(Color.appPrimaryText)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.secondaryText)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(16)
        .background(stepCardBG)
        .sheet(isPresented: $showPromptJournal, onDismiss: { markJournalIfWritten() }) {
            PromptJournalSheet(journalStore: journalStore, prompt: prompt, audioGuide: audioGuide)
        }
        .sheet(isPresented: $showFreeJournal, onDismiss: { markJournalIfWritten() }) {
            FreeWriteSheet(journalStore: journalStore, audioGuide: audioGuide)
        }
        .sheet(isPresented: $showJournalHistory) {
            JournalHistorySheet(journalStore: journalStore)
        }
    }

    /// Only count the journal step as done if an entry was actually saved today.
    private func markJournalIfWritten() {
        if journalStore.todayEntry != nil {
            store.markDone(.journal)
        } else {
            store.markNotDone(.journal)
        }
    }

    @ViewBuilder
    private func journalButton(icon: String, label: String, sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(Color("Sunrise")).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.subheadline.weight(.medium)).foregroundStyle(Color.appPrimaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(sub).font(.caption).foregroundStyle(Color.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Color.secondaryText)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Task Step

struct TaskStepView: View {
    @ObservedObject var store: RoutineStore
    @AppStorage("mg.todayTask") private var todayTask: String = ""
    @State private var showTodoSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if todayTask.isEmpty {
                Text("What's the single most important thing you need to do today?")
                    .font(.mg("Lora-Regular", 16))
                    .foregroundStyle(Color.secondaryText)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "star.fill").foregroundStyle(Color("Sunrise")).padding(.top, 2)
                    Text(todayTask)
                        .font(.mg("Lora-Regular", 17))
                        .foregroundStyle(Color.appPrimaryText)
                }
            }

            Button { showTodoSheet = true } label: {
                Label(todayTask.isEmpty ? "Set my focus" : "Change", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(todayTask.isEmpty ? Color("Sunrise") : Color("Sunrise").opacity(0.12))
                    .foregroundStyle(todayTask.isEmpty ? .white : Color("Sunrise"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(stepCardBG)
        .sheet(isPresented: $showTodoSheet) {
            TodoSheet(todayTask: $todayTask)
        }
        .onChange(of: todayTask) { _, value in
            if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                store.markDone(.task)
            }
        }
        .onAppear {
            if !todayTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                store.markDone(.task)
            }
        }
    }
}
