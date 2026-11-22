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
    /// Énoncés en file → position (UTF-16) de leur début dans le texte.
    private var queued: [ObjectIdentifier: Int] = [:]
    private var lastQueued: ObjectIdentifier?
    private weak var document: PrompterDocument?
    private var isOneShot = false
    private var current: ObjectIdentifier? { lastQueued }

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
    ///
    /// Aux allures lentes (apprentissage), la voix ralentit et marque une pause
    /// après chaque phrase ; aux plus lentes, elle lit mot à mot.
    func speak(_ doc: PrompterDocument, from word: Int, to endWord: Int? = nil,
               wordsPerMinute: Double, voiceID: String) {
        stop()
        guard doc.words.indices.contains(word) else { onFinish?(); return }
        let last = min(endWord ?? doc.words.count, doc.words.count) - 1
        guard last >= word else { onFinish?(); return }

        AudioSession.activate()
        document = doc
        isOneShot = false
        let voice = Self.voice(for: voiceID)
        let rate = Self.rate(forWordsPerMinute: wordsPerMinute)
        let ns = doc.text as NSString
        for chunk in Self.chunks(doc, from: word, through: last, wordsPerMinute: wordsPerMinute) {
            let start = doc.words[chunk.words.lowerBound].range.location
            let endRange = doc.words[chunk.words.upperBound - 1].range
            let u = AVSpeechUtterance(string: ns.substring(with: NSRange(location: start,
                                                                         length: endRange.location + endRange.length - start)))
            u.voice = voice
            u.rate = rate
            u.preUtteranceDelay = 0
            u.postUtteranceDelay = chunk.pause
            let id = ObjectIdentifier(u)
            queued[id] = start
            lastQueued = id
            synth.speak(u)
        }
    }

    struct Chunk: Equatable {
        let words: Range<Int>
        let pause: TimeInterval
    }

    /// Découpe la lecture selon l'allure : d'un seul tenant (rapide), phrase par
    /// phrase avec une pause (lent), mot à mot (très lent).
    static func chunks(_ doc: PrompterDocument, from first: Int, through last: Int,
                       wordsPerMinute wpm: Double) -> [Chunk] {
        guard first <= last else { return [] }
        if wpm >= 70 { return [Chunk(words: first..<(last + 1), pause: 0)] }
        if wpm <= 16 {
            let pause = min(2.5, 60 / wpm * 0.55)
            return (first...last).map { Chunk(words: $0..<($0 + 1), pause: pause) }
        }
        let pause = min(2.0, 36 / wpm * 0.6)
        var out: [Chunk] = []
        var start = first
        for w in first...last {
            let endOfSentence = w == last || doc.words[w + 1].sentence != doc.words[w].sentence
            if endOfSentence {
                out.append(Chunk(words: start..<(w + 1), pause: pause))
                start = w + 1
            }
        }
        return out
    }

    /// Lecture ponctuelle (test de voix), sans suivi.
    func preview(_ text: String, voiceID: String, wordsPerMinute: Double) {
        stop()
        AudioSession.activate()
        let u = AVSpeechUtterance(string: text)
        u.voice = Self.voice(for: voiceID)
        u.rate = Self.rate(forWordsPerMinute: wordsPerMinute)
        isOneShot = true
        let id = ObjectIdentifier(u)
        queued[id] = 0
        lastQueued = id
        synth.speak(u)
    }

    func stop() {
        queued.removeAll()
        lastQueued = nil
        // Sans condition : juste après speak(), isSpeaking peut encore être faux.
        synth.stopSpeaking(at: .immediate)
    }

    // MARK: Correspondances

    /// Vitesse de défilement (mots/min) → débit de la synthèse vocale.
    static func rate(forWordsPerMinute wpm: Double) -> Float {
        let points: [(Double, Double)] = [(10, 0.2), (20, 0.24), (40, 0.3), (60, 0.33), (110, 0.42),
                                          (175, 0.5), (260, 0.6)]
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

    // MARK: Rappels (sur le fil principal)

    fileprivate func handleWord(at location: Int, utterance id: ObjectIdentifier) {
        guard !isOneShot, let base = queued[id], let doc = document,
              let w = doc.wordIndex(atUTF16: base + location) else { return }
        onWord?(w)
    }

    fileprivate func handleFinish(utterance id: ObjectIdentifier) {
        guard queued.removeValue(forKey: id) != nil, id == lastQueued else { return }
        lastQueued = nil
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
