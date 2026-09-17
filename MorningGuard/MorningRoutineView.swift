import SwiftUI
import AVFoundation
import Speech
import Combine
import UIKit

// MARK: - Speech Transcriber

/// NOT @MainActor: every CoreAudio call (setActive, engine.start, installTap)
/// runs on a dedicated serial background queue so a slow or wedged audio
/// daemon can never block the main thread and freeze the UI. Only the
/// @Published properties are marshaled back to the main thread.
final class SpeechTranscriber: ObservableObject {
    @Published var isTranscribing = false
    @Published var partial: String = ""
    @Published var errorMessage: String?

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let engine = AVAudioEngine()
    private let audioQueue = DispatchQueue(label: "com.morningguard.speech.audio", qos: .userInitiated)

    private func reportError(_ message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.isTranscribing = false
        }
    }

    func start() {
        // Guard against double-start using the published flag (read on main).
        if isTranscribing { return }
        errorMessage = nil
        // Make sure the spoken-audio guide isn't holding the session.
        SpeechService.shared.stop()

        // 1. Speech recognition permission.
        SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
            guard let self else { return }
            guard speechStatus == .authorized else {
                self.reportError("Speech recognition is off. Enable it in Settings ▸ Morning Guard ▸ Speech Recognition.")
                return
            }
            // 2. Microphone permission.
            AVAudioApplication.requestRecordPermission { granted in
                guard granted else {
                    self.reportError("Microphone access is off. Enable it in Settings ▸ Morning Guard ▸ Microphone.")
                    return
                }
                self.audioQueue.async { self.beginTranscribing() }
            }
        }
    }

    // Runs on audioQueue.
    private func beginTranscribing() {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard let recognizer, recognizer.isAvailable else {
            reportError("Speech recognition isn't available on this device right now.")
            return
        }
        self.recognizer = recognizer

        // 1. Activate the audio session for recording FIRST, so the input
        //    node reports a valid hardware format before we install a tap.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            reportError("Couldn't start the microphone. Try again.")
            return
        }

        // 2. Build the request.
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        // 3. Now read the (valid) input format and install the tap.
        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            self.request = nil
            reportError("Couldn't access the microphone. Try again.")
            return
        }
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        // 4. Start the engine.
        engine.prepare()
        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            self.request = nil
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            reportError("Couldn't start recording. Try again.")
            return
        }

        // 5. Kick off recognition.
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async { self.partial = text }
            }
            if error != nil || (result?.isFinal ?? false) {
                self.audioQueue.async { self.teardown() }
            }
        }

        DispatchQueue.main.async { self.isTranscribing = true }
    }

    func stop() {
        audioQueue.async { [weak self] in self?.teardown() }
    }

    // Runs on audioQueue.
    private func teardown() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        DispatchQueue.main.async { self.isTranscribing = false }
    }
}

// MARK: - Box Breathing

enum BreathPhase: CaseIterable {
    case inhale, holdIn, exhale, holdOut

    var seconds: Int { 4 }

    var label: String {
        switch self {
        case .inhale:  return "Breathe in"
        case .holdIn:  return "Hold"
        case .exhale:  return "Breathe out"
        case .holdOut: return "Hold"
        }
    }

    var targetScale: CGFloat {
        switch self {
        case .inhale, .holdIn: return 1.0
        case .exhale, .holdOut: return 0.45
        }
    }

    var next: BreathPhase {
        let all = BreathPhase.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx + 1) % all.count]
    }
}

// MARK: - One Important Task Sheet

struct TodoSheet: View {
    @Binding var todayTask: String
    @State private var draft = ""
    @State private var preDictationBase = ""
    @StateObject private var transcriber = SpeechTranscriber()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("What's the single most important thing you need to accomplish today?")
                        .font(.mg("Lora-Regular", 18))
                        .foregroundStyle(Color.appPrimaryText)
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.secondarySystemGroupedBackground))
                        if draft.isEmpty {
                            Text("e.g. Finish the project proposal")
                                .foregroundStyle(Color.secondaryText)
                                .font(.mg("Lora-Regular", 16))
                                .padding(12)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $draft)
                            .font(.mg("Lora-Regular", 16))
                            .foregroundStyle(Color(UIColor.label))
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .padding(8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 100)
                    .padding(.horizontal, 16)

                    DictationButton(transcriber: transcriber)
                        .padding(.horizontal, 16)

                    Spacer()
                }
            }
            .navigationTitle("One thing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        todayTask = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { draft = todayTask }
            .onDisappear { transcriber.stop() }
            .onChange(of: transcriber.isTranscribing) { _, recording in
                if recording { preDictationBase = draft }
            }
            .onChange(of: transcriber.partial) { _, newPartial in
                guard !newPartial.isEmpty else { return }
                let sep = preDictationBase.isEmpty ? "" : " "
                let combined = preDictationBase + sep + newPartial
                if transcriber.isTranscribing {
                    draft = combined
                } else {
                    draft = combined.trimmingCharacters(in: .whitespacesAndNewlines)
                    preDictationBase = draft
                    transcriber.partial = ""
                }
            }
        }
    }
}

// MARK: - Reusable Dictation Button

/// A clear, labeled microphone control with live feedback and error display.
/// Tap to start/stop; the transcribed text is appended by the host view's
/// onChange(of: transcriber.isTranscribing).
struct DictationButton: View {
    @ObservedObject var transcriber: SpeechTranscriber

    var body: some View {
        VStack(spacing: 8) {
            Button {
                if transcriber.isTranscribing { transcriber.stop() }
                else { transcriber.partial = ""; transcriber.start() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: transcriber.isTranscribing ? "stop.circle.fill" : "mic.fill")
                    Text(transcriber.isTranscribing ? "Stop" : "Dictate")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(transcriber.isTranscribing ? Color.red.opacity(0.9) : Color("Sunrise"))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if transcriber.isTranscribing {
                Label(transcriber.partial.isEmpty ? "Listening..." : transcriber.partial,
                      systemImage: "waveform")
                    .font(.caption)
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let err = transcriber.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Prompt Journal Sheet

struct PromptJournalSheet: View {
    @ObservedObject var journalStore: JournalStore
    let prompt: String
    let audioGuide: Bool

    @State private var responseText = ""
    @State private var preDictationBase = ""
    @StateObject private var transcriber = SpeechTranscriber()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    Text(prompt)
                        .font(.mg("Lora-Regular", 20))
                        .foregroundStyle(Color.appPrimaryText)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24).padding(.top, 24)

                    HStack(spacing: 16) {
                        Button { SpeechService.shared.speak(prompt) } label: {
                            Label("Hear prompt", systemImage: "speaker.wave.2")
                                .font(.subheadline).foregroundStyle(Color("Sunrise"))
                        }
                    }
                    .padding(.horizontal, 24)

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemGroupedBackground))
                        if responseText.isEmpty && !transcriber.isTranscribing {
                            Text("Write your response here...")
                                .foregroundStyle(Color.secondaryText)
                                .font(.mg("Lora-Regular", 16))
                                .padding(12).allowsHitTesting(false)
                        }
                        TextEditor(text: $responseText)
                            .font(.mg("Lora-Regular", 16))
                            .foregroundStyle(Color(UIColor.label))
                            .scrollContentBackground(.hidden).background(Color.clear).padding(8)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180).padding(.horizontal, 16)

                    DictationButton(transcriber: transcriber)
                        .padding(.horizontal, 16)

                    Spacer()
                }
            }
            .navigationTitle("Today's prompt").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        journalStore.save(text: prompt + "\n\n" + responseText); dismiss()
                    }
                    .disabled(responseText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { if audioGuide { SpeechService.shared.speak("Your prompt for today. " + prompt) } }
            .onDisappear { transcriber.stop() }
            .onChange(of: transcriber.isTranscribing) { _, recording in
                if recording { preDictationBase = responseText }
            }
            .onChange(of: transcriber.partial) { _, newPartial in
                guard !newPartial.isEmpty else { return }
                let sep = preDictationBase.isEmpty ? "" : " "
                let combined = preDictationBase + sep + newPartial
                if transcriber.isTranscribing {
                    responseText = combined
                } else {
                    responseText = combined.trimmingCharacters(in: .whitespacesAndNewlines)
                    preDictationBase = responseText
                    transcriber.partial = ""
                }
            }
        }
    }
}

// MARK: - Free Write Sheet

struct FreeWriteSheet: View {
    @ObservedObject var journalStore: JournalStore
    let audioGuide: Bool

    @State private var text = ""
    @State private var preDictationBase = ""
    @StateObject private var transcriber = SpeechTranscriber()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty && !transcriber.isTranscribing {
                            Text("What's on your mind this morning?")
                                .foregroundStyle(Color.secondaryText).font(.mg("Lora-Regular", 16))
                                .padding(.horizontal, 20).padding(.top, 8).allowsHitTesting(false)
                        }
                        TextEditor(text: $text)
                            .font(.mg("Lora-Regular", 16))
                            .foregroundStyle(Color(UIColor.label))
                            .scrollContentBackground(.hidden).background(Color.clear).padding(.horizontal, 16)
                    }

                    DictationButton(transcriber: transcriber)
                        .padding(16)
                }
            }
            .navigationTitle("Morning notes").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { journalStore.save(text: text); dismiss() }
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { if audioGuide { SpeechService.shared.speak("What's on your mind this morning? Take a moment and write it out.") } }
            .onDisappear { transcriber.stop() }
            .onChange(of: transcriber.isTranscribing) { _, recording in
                if recording { preDictationBase = text }
            }
            .onChange(of: transcriber.partial) { _, newPartial in
                guard !newPartial.isEmpty else { return }
                let sep = preDictationBase.isEmpty ? "" : " "
                let combined = preDictationBase + sep + newPartial
                if transcriber.isTranscribing {
                    text = combined
                } else {
                    text = combined.trimmingCharacters(in: .whitespacesAndNewlines)
                    preDictationBase = text
                    transcriber.partial = ""
                }
            }
        }
    }
}

// MARK: - Journal History Sheet

struct JournalHistorySheet: View {
    @ObservedObject var journalStore: JournalStore
    @Environment(\.dismiss) private var dismiss

    private var sortedEntries: [JournalEntry] { journalStore.entries.sorted { $0.date > $1.date } }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedEntries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption.weight(.semibold)).foregroundStyle(Color("Sunrise"))
                        Text(String(entry.text.prefix(60)))
                            .font(.subheadline).foregroundStyle(Color.appPrimaryText).lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { idx in
                    for i in idx { journalStore.delete(id: sortedEntries[i].id) }
                }
            }
            .listStyle(.plain).navigationTitle("Past entries").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
