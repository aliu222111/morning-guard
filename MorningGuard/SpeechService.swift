import AVFoundation
import Combine

final class SpeechService: NSObject, ObservableObject {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    @Published var isSpeaking = false

    // Session activation can block; keep it off the main thread.
    private let sessionQueue = DispatchQueue(label: "com.morningguard.speech.session", qos: .userInitiated)

    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    // Speaks a single string through the speaker, ignoring silent switch.
    // stopSpeaking + speak run on the same serial queue so a new narration
    // always clears any stale/queued speech first — this keeps the spoken step
    // in sync with the step on screen, even when the user skips quickly.
    func speak(_ text: String, rate: Float = 0.48) {
        isSpeaking = true
        let u = utterance(text, rate: rate)
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.synthesizer.stopSpeaking(at: .immediate)
            self.activateSession()
            self.synthesizer.speak(u)
        }
    }

    // Queues a sequence of (text, preDelay) pairs -- plays in order automatically
    func speakSequence(_ items: [(text: String, preDelay: TimeInterval)]) {
        isSpeaking = true
        let utterances = items.map { item -> AVSpeechUtterance in
            let u = utterance(item.text, rate: item.text.count <= 2 ? 0.42 : 0.48)
            u.preUtteranceDelay = item.preDelay
            return u
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.synthesizer.stopSpeaking(at: .immediate)
            self.activateSession()
            for u in utterances { self.synthesizer.speak(u) }
        }
    }

    func stop() {
        isSpeaking = false
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.synthesizer.stopSpeaking(at: .immediate)
            self.deactivateSession()
        }
    }

    private func utterance(_ text: String, rate: Float) -> AVSpeechUtterance {
        let u = AVSpeechUtterance(string: text)
        u.rate = rate
        u.pitchMultiplier = 1.0
        u.voice = bestEnglishVoice()
        return u
    }

    /// True when a natural (enhanced/premium) Apple voice is installed; otherwise
    /// the system falls back to the robotic compact voice.
    var hasHumanVoiceInstalled: Bool {
        AVSpeechSynthesisVoice.speechVoices().contains {
            $0.language.hasPrefix("en") && ($0.quality == .enhanced || $0.quality == .premium)
        }
    }

    /// The name of the voice that will actually be used.
    var activeVoiceName: String {
        bestEnglishVoice()?.name ?? "Default"
    }

    /// A short human-readable description of the active voice's quality.
    var activeVoiceQualityLabel: String {
        switch bestEnglishVoice()?.quality {
        case .premium:  return "Premium"
        case .enhanced: return "Enhanced"
        default:        return "Basic"
        }
    }

    // Apple's most natural voices, best first.
    private let preferredVoiceNames = ["Ava", "Evan", "Zoe", "Nathan", "Joelle", "Samantha", "Allison"]

    private func bestEnglishVoice() -> AVSpeechSynthesisVoice? {
        let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }

        // Prefer premium, then enhanced; within each, honor our name ranking.
        for quality in [AVSpeechSynthesisVoiceQuality.premium, .enhanced] {
            let pool = english.filter { $0.quality == quality }
            for name in preferredVoiceNames {
                if let match = pool.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) {
                    return match
                }
            }
            if let any = pool.first { return any }
        }

        // Last resort: a US compact voice (robotic, but functional).
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    private func activateSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if !synthesizer.isSpeaking {
            isSpeaking = false
            sessionQueue.async { [weak self] in self?.deactivateSession() }
        }
    }
}
