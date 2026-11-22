import AVFoundation

/// Lecture à voix haute, mot à mot.
///
/// La voix parle à partir d'un mot donné et signale chaque mot prononcé :
/// c'est elle qui guide le défilement quand la voix est activée.
@MainActor
final class SpeechEngine: NSObject {
    var onWord: ((Int) -> Void)?
    var onFinish: (() -> Void)?
    /// Appel, Siri… : la lecture doit se mettre en pause.
    var onInterruption: (() -> Void)?

    private let synth = AVSpeechSynthesizer()
    private var current: ObjectIdentifier?
    private var baseOffset = 0
    private weak var document: PrompterDocument?
    private var isOneShot = false

    private var interruptionObserver: NSObjectProtocol?

    override init() {
        super.init()
        synth.delegate = self
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            guard raw == AVAudioSession.InterruptionType.began.rawValue else { return }
            MainActor.assumeIsolated {
                guard let self, self.current != nil else { return }
                self.stop()
                self.onInterruption?()
            }
        }
    }

    deinit {
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
    }

    var isSpeaking: Bool { synth.isSpeaking }

    /// Lit le document depuis `word` jusqu'à `endWord` (exclu) ou la fin.
    func speak(_ doc: PrompterDocument, from word: Int, to endWord: Int? = nil,
               wordsPerMinute: Double, voiceID: String) {
        stop()
        guard doc.words.indices.contains(word) else { onFinish?(); return }
        let last = min(endWord ?? doc.words.count, doc.words.count) - 1
        guard last >= word else { onFinish?(); return }
        let start = doc.words[word].range.location
        let endRange = doc.words[last].range
        let end = endRange.location + endRange.length
        let ns = doc.text as NSString
        let text = ns.substring(with: NSRange(location: start, length: end - start))

        Self.activateAudioSession()
        let u = AVSpeechUtterance(string: text)
        u.voice = Self.voice(for: voiceID)
        u.rate = Self.rate(forWordsPerMinute: wordsPerMinute)
        u.preUtteranceDelay = 0
        u.postUtteranceDelay = 0
        document = doc
        baseOffset = start
        isOneShot = false
        current = ObjectIdentifier(u)
        synth.speak(u)
    }

    /// Lecture ponctuelle (test de voix), sans suivi.
    func preview(_ text: String, voiceID: String, wordsPerMinute: Double) {
        stop()
        Self.activateAudioSession()
        let u = AVSpeechUtterance(string: text)
        u.voice = Self.voice(for: voiceID)
        u.rate = Self.rate(forWordsPerMinute: wordsPerMinute)
        isOneShot = true
        current = ObjectIdentifier(u)
        synth.speak(u)
    }

    func stop() {
        current = nil
        // Sans condition : juste après speak(), isSpeaking peut encore être faux.
        synth.stopSpeaking(at: .immediate)
    }

    // MARK: Correspondances

    /// Vitesse de défilement (mots/min) → débit de la synthèse vocale.
    static func rate(forWordsPerMinute wpm: Double) -> Float {
        let points: [(Double, Double)] = [(40, 0.26), (60, 0.31), (110, 0.42), (175, 0.5), (260, 0.6)]
        if wpm <= points[0].0 { return Float(points[0].1) }
        for k in 1..<points.count where wpm <= points[k].0 {
            let (x0, y0) = points[k - 1], (x1, y1) = points[k]
            return Float(y0 + (wpm - x0) / (x1 - x0) * (y1 - y0))
        }
        return Float(points.last!.1)
    }

    static var frenchVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("fr") }
            .sorted { a, b in
                if a.quality != b.quality { return a.quality.rawValue > b.quality.rawValue }
                if (a.language == "fr-FR") != (b.language == "fr-FR") { return a.language == "fr-FR" }
                return a.name < b.name
            }
    }

    static func voice(for identifier: String) -> AVSpeechSynthesisVoice? {
        if !identifier.isEmpty, let v = AVSpeechSynthesisVoice(identifier: identifier) { return v }
        return frenchVoices.first ?? AVSpeechSynthesisVoice(language: "fr-FR")
    }

    static func displayName(_ voice: AVSpeechSynthesisVoice) -> String {
        var name = voice.name
        switch voice.quality {
        case .premium: name += " · Premium"
        case .enhanced: name += " · Améliorée"
        default: break
        }
        let region = voice.language.split(separator: "-").last.map(String.init) ?? ""
        let regionName = Locale(identifier: "fr_FR").localizedString(forRegionCode: region) ?? region
        return "\(name) (\(regionName))"
    }

    /// La voix et les sons jouent même en mode silencieux, sans couper ni
    /// baisser durablement la musique d'une autre app.
    static func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    /// À la fermeture du lecteur : rend la main aux autres apps.
    static func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Rappels (sur le fil principal)

    fileprivate func handleWord(at location: Int, utterance id: ObjectIdentifier) {
        guard id == current, !isOneShot, let doc = document,
              let w = doc.wordIndex(atUTF16: baseOffset + location) else { return }
        onWord?(w)
    }

    fileprivate func handleFinish(utterance id: ObjectIdentifier) {
        guard id == current else { return }
        current = nil
        if !isOneShot { onFinish?() }
    }
}

extension SpeechEngine: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       willSpeakRangeOfSpeechString characterRange: NSRange,
                                       utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        let loc = characterRange.location
        Task { @MainActor in self.handleWord(at: loc, utterance: id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.handleFinish(utterance: id) }
    }
}
