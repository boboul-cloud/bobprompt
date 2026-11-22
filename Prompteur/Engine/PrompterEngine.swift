import QuartzCore
import Observation

/// Horloge d'affichage (60–120 images/s).
final class DisplayLinkDriver: NSObject {
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private let onTick: (Double) -> Void

    init(onTick: @escaping (Double) -> Void) { self.onTick = onTick }

    var isRunning: Bool { link != nil }

    func start() {
        guard link == nil else { return }
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        l.add(to: .main, forMode: .common)
        link = l
        last = 0
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func tick(_ l: CADisplayLink) {
        if last == 0 { last = l.timestamp }
        let dt = l.targetTimestamp - last
        last = l.targetTimestamp
        onTick(min(max(dt, 0), 1.0 / 20.0))
    }
}

/// Le cœur du lecteur : position, lecture, pause, compte à rebours, voix.
///
/// La position est exprimée dans la ligne de temps fournie par le mode
/// d'affichage actif ; changer de mode conserve le mot en cours.
@MainActor
@Observable
final class PrompterEngine {
    enum Phase: Equatable {
        case idle, countdown(Int), playing, paused, finished
        var isRunning: Bool { self == .playing }
    }

    private(set) var phase: Phase = .idle
    private(set) var beat: Double = 0
    private(set) var timeline: Timeline
    private(set) var document: PrompterDocument

    /// Progression arrondie (pour les barres et compteurs, mise à jour ~10×/s).
    private(set) var displayProgress: Double = 0
    private(set) var remainingSeconds: Int = 0
    /// Mot en cours, mis à jour seulement quand il change (pour les vues qui
    /// n'ont pas besoin de la position à chaque image).
    private(set) var coarseWord: Int = 0
    /// Vrai pendant qu'une voix guide la lecture.
    private(set) var voiceGuided = false
    /// Mot à partir duquel la lecture d'une seule phrase s'arrête.
    private(set) var oneSentenceEnd: Int? = nil

    var wordsPerMinute: Double = 110 {
        didSet {
            guard wordsPerMinute != oldValue else { return }
            refreshCoarse(force: true)
            // La voix suit la nouvelle vitesse tout de suite.
            if phase == .playing, voiceGuided, oneSentenceEnd == nil { startVoice(from: currentWord) }
        }
    }
    var voiceEnabled = false
    var voiceID = ""

    @ObservationIgnored private lazy var driver = DisplayLinkDriver { [weak self] dt in
        MainActor.assumeIsolated { self?.tick(dt) }
    }
    @ObservationIgnored private var speechStorage: SpeechEngine?
    @ObservationIgnored private var speedFactor: Double = 0
    @ObservationIgnored private var coast: Double = 0
    @ObservationIgnored private var inertia: Double = 0
    @ObservationIgnored private var voiceTarget: Double = 0
    @ObservationIgnored private var voiceCeiling: Double = 0
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var isScrubbing = false

    /// Appelé quand le texte arrive à la fin.
    @ObservationIgnored var onFinish: (() -> Void)?

    init(document: PrompterDocument) {
        self.document = document
        self.timeline = document.timeline
        refreshCoarse(force: true)
    }

    /// Synthèse vocale créée à la première utilisation.
    private var speech: SpeechEngine {
        if let s = speechStorage { return s }
        let s = SpeechEngine()
        s.onWord = { [weak self] w in self?.voiceReached(word: w) }
        s.onFinish = { [weak self] in self?.voiceFinished() }
        s.onInterruption = { [weak self] in self?.pause() }
        speechStorage = s
        return s
    }

    // MARK: - Lecture de l'état

    var wordPosition: Double { timeline.wordPosition(atBeat: beat) }
    var currentWord: Int { timeline.wordIndex(atBeat: beat) }
    var progress: Double { timeline.total > 0 ? min(1, beat / timeline.total) : 0 }
    var isPlaying: Bool { phase == .playing }
    var beatsPerSecond: Double { wordsPerMinute / 60 }

    // MARK: - Contenu

    /// Remplace le texte (après une modification) en gardant à peu près la position.
    func setDocument(_ doc: PrompterDocument) {
        let ratio = progress
        stopVoice()
        document = doc
        timeline = doc.timeline
        beat = ratio * timeline.total
        if phase == .finished { phase = .paused }
        refreshCoarse(force: true)
    }

    /// Le mode d'affichage fournit sa propre ligne de temps (même nombre de mots).
    func setTimeline(_ t: Timeline) {
        guard t != timeline else { return }
        let wp = wordPosition
        let targetWP = timeline.wordPosition(atBeat: voiceTarget)
        let ceilingWP = timeline.wordPosition(atBeat: voiceCeiling)
        timeline = t
        beat = t.beat(atWordPosition: wp)
        voiceTarget = t.beat(atWordPosition: targetWP)
        voiceCeiling = t.beat(atWordPosition: ceilingWP)
        refreshCoarse(force: true)
    }

    // MARK: - Commandes

    func toggle(countdown: Bool) {
        switch phase {
        case .playing: pause()
        case .countdown: cancelCountdown()
        case .idle, .finished:
            if phase == .finished || beat >= timeline.total - 0.001 { seek(toBeat: 0) }
            countdown ? startCountdown() : play()
        case .paused:
            play()
        }
    }

    func play() {
        guard timeline.total > 0 else { return }
        cancelCountdown()
        if beat >= timeline.total - 0.001 { beat = 0 }
        oneSentenceEnd = nil
        phase = .playing
        inertia = 0
        isScrubbing = false
        if voiceEnabled { startVoice(from: currentWord) } else { voiceGuided = false }
        driver.start()
    }

    func pause() {
        cancelCountdown()
        isScrubbing = false
        guard phase == .playing else { return }
        coast = voiceGuided ? 0 : beatsPerSecond * speedFactor
        speedFactor = 0
        phase = .paused
        oneSentenceEnd = nil
        stopVoice()
        driver.start()
    }

    func restart() {
        cancelCountdown()
        stopVoice()
        phase = .idle
        beat = 0
        coast = 0
        inertia = 0
        speedFactor = 0
        isScrubbing = false
        refreshCoarse(force: true)
    }

    /// Lit à voix haute la phrase en cours, puis s'arrête.
    func readSentenceAloud() {
        guard !document.isEmpty else { return }
        cancelCountdown()
        let s = document.sentenceIndex(ofWord: currentWord)
        let range = document.sentences[s].words
        // Si on est déjà au bout de la phrase, on lit la suivante.
        var target = range
        if wordPosition >= Double(range.upperBound) - 0.5, s + 1 < document.sentences.count {
            target = document.sentences[s + 1].words
        }
        seek(toBeat: timeline.start(ofWord: target.lowerBound))
        phase = .playing
        oneSentenceEnd = target.upperBound
        voiceGuided = true
        voiceTarget = beat
        voiceCeiling = beat
        speech.speak(document, from: target.lowerBound, to: target.upperBound,
                     wordsPerMinute: wordsPerMinute, voiceID: voiceID)
        driver.start()
    }

    func seek(toBeat b: Double) {
        beat = min(max(0, b), timeline.total)
        voiceTarget = beat
        voiceCeiling = beat
        if phase == .finished { phase = .paused }
        refreshCoarse(force: true)
    }

    func seek(toWord w: Int) { seek(toBeat: timeline.start(ofWord: w)) }

    /// Phrase précédente (-1) ou suivante (+1).
    func jumpSentence(_ delta: Int) {
        guard !document.isEmpty else { return }
        // Interrompre « Écouter la phrase » revient à une pause.
        if oneSentenceEnd != nil { pause() }
        let wasPlaying = phase == .playing
        let s = document.sentenceIndex(ofWord: currentWord)
        // « Suivante » depuis la dernière phrase : rien à faire.
        if delta > 0, s >= document.sentences.count - 1 { return }
        if wasPlaying { stopVoice() }
        let start = document.sentences[s].words.lowerBound
        var target = s + delta
        // « Précédent » au milieu d'une phrase revient à son début.
        if delta < 0, Double(currentWord) - Double(start) > 1.5 { target = s }
        target = min(max(0, target), document.sentences.count - 1)
        seek(toWord: document.sentences[target].words.lowerBound)
        if wasPlaying, voiceEnabled { startVoice(from: currentWord) }
        if !wasPlaying { glideIntoCurrentWord() }
    }

    /// Mot précédent (-1) ou suivant (+1) : lecture « à mon rythme ».
    func jumpWord(_ delta: Int) {
        guard !document.isEmpty else { return }
        if oneSentenceEnd != nil { pause() }
        let wasPlaying = phase == .playing
        if wasPlaying { stopVoice() }
        let target = min(max(0, currentWord + delta), document.words.count - 1)
        seek(toWord: target)
        if wasPlaying {
            if voiceEnabled { startVoice(from: currentWord) }
        } else {
            glideIntoCurrentWord()
        }
    }

    /// En pause, avance en douceur jusqu'au milieu du mot : le mot « arrive »
    /// (chute dans le mode dessin animé) au lieu d'apparaître d'un coup.
    private func glideIntoCurrentWord() {
        let w = currentWord
        let len = timeline.start(ofWord: w + 1) - timeline.start(ofWord: w)
        coast = 0
        inertia = len * 0.5 * 3.2
        driver.start()
    }

    // Glisser du doigt
    func beginScrub() {
        if oneSentenceEnd != nil { pause() }
        isScrubbing = true
        inertia = 0
        coast = 0
        if phase == .playing && voiceGuided { stopVoice() }
    }

    func scrub(by delta: Double) {
        beat = min(max(0, beat + delta), timeline.total)
        voiceTarget = beat
        voiceCeiling = beat
        if phase == .finished { phase = .paused }
        refreshCoarse(force: false)
    }

    func endScrub(velocity: Double) {
        isScrubbing = false
        if phase == .playing {
            if voiceEnabled { startVoice(from: currentWord) }
        } else {
            inertia = velocity
            driver.start()
        }
    }

    /// Geste annulé par le système (appel, Centre de contrôle) : on termine proprement.
    func cancelScrubIfNeeded() {
        if isScrubbing { endScrub(velocity: 0) }
    }

    func shutdown() {
        cancelCountdown()
        isScrubbing = false
        stopVoice()
        driver.stop()
        if phase == .playing { phase = .paused }
    }

    // MARK: - Compte à rebours

    private func startCountdown() {
        cancelCountdown()
        phase = .countdown(3)
        countdownTask = Task { [weak self] in
            for n in [3, 2, 1] {
                guard let self, !Task.isCancelled else { return }
                self.phase = .countdown(n)
                Haptics.tick()
                try? await Task.sleep(for: .milliseconds(850))
            }
            guard let self, !Task.isCancelled else { return }
            self.play()
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        if case .countdown = phase { phase = beat > 0 ? .paused : .idle }
    }

    // MARK: - Voix

    private func startVoice(from word: Int) {
        voiceGuided = true
        voiceTarget = beat
        voiceCeiling = beat
        speech.speak(document, from: word, wordsPerMinute: wordsPerMinute, voiceID: voiceID)
    }

    private func stopVoice() {
        speechStorage?.stop()
        voiceGuided = false
    }

    private func voiceReached(word: Int) {
        guard voiceGuided, !isScrubbing else { return }
        // Vise le milieu du mot prononcé.
        let start = timeline.start(ofWord: word)
        let end = timeline.start(ofWord: word + 1)
        voiceTarget = max(voiceTarget, start + (end - start) * 0.35)
        voiceCeiling = max(voiceCeiling, end)
    }

    private func voiceFinished() {
        guard voiceGuided else { return }
        if let end = oneSentenceEnd {
            voiceTarget = timeline.start(ofWord: end) - 0.001
            oneSentenceEnd = nil
            voiceGuided = false
            phase = .paused
            coast = 0
            // Glisse en douceur jusqu'à la fin de la phrase.
            inertia = max(0, (voiceTarget - beat) * 3)
            driver.start()
            return
        }
        voiceTarget = timeline.total
        voiceCeiling = timeline.total
    }

    // MARK: - Image par image

    private func tick(_ dt: Double) {
        guard dt > 0 else { return }
        switch phase {
        case .playing where voiceGuided:
            let k = 1 - exp(-dt * 6)
            let chase = beat + (voiceTarget - beat) * k
            // Avance douce entre deux mots signalés, sans dépasser le mot prononcé.
            let drift = min(beat + beatsPerSecond * dt, voiceCeiling)
            beat = min(max(beat, chase, drift), timeline.total)
            if voiceTarget >= timeline.total - 0.001, beat >= timeline.total - 0.05 { finish() }
        case .playing:
            speedFactor = min(1, speedFactor + dt / 0.45)
            let eased = speedFactor * speedFactor * (3 - 2 * speedFactor)
            if !isScrubbing { beat += beatsPerSecond * eased * dt }
            if beat >= timeline.total { beat = timeline.total; finish() }
        default:
            var moving = false
            if coast > 0.001 {
                beat += coast * dt
                coast *= exp(-dt * 9)
                moving = true
            }
            if abs(inertia) > 0.01, !isScrubbing {
                beat += inertia * dt
                inertia *= exp(-dt * 3.2)
                moving = true
            }
            beat = min(max(0, beat), timeline.total)
            if !moving && !isScrubbing { driver.stop() }
        }
        refreshCoarse(force: false)
    }

    private func finish() {
        stopVoice()
        phase = .finished
        speedFactor = 0
        refreshCoarse(force: true)
        onFinish?()
    }

    private func refreshCoarse(force: Bool) {
        let p = progress
        if force || abs(p - displayProgress) > 0.002 { displayProgress = p }
        let rem = Int(((timeline.total - beat) / max(0.1, beatsPerSecond)).rounded(.up))
        if force || rem != remainingSeconds { remainingSeconds = max(0, rem) }
        let w = currentWord
        if w != coarseWord { coarseWord = w }
    }
}
