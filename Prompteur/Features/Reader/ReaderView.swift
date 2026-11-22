import SwiftUI
import UIKit

/// Lecteur plein écran.
struct ReaderView: View {
    @Environment(ScriptStore.self) private var store
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppRouter.self) private var router
    @Environment(RewardStore.self) private var rewards
    @Environment(\.dismiss) private var dismiss

    let profile: ReaderProfile
    @State private var script: Script
    @State private var document: PrompterDocument
    @State private var engine: PrompterEngine
    @State private var tilt = MotionTilt()
    @State private var controlsVisible = true
    @State private var sheet: ReaderSheet?
    @State private var hideTask: Task<Void, Never>?
    @State private var resumeWord: Int?
    @State private var finished = false
    @State private var readingTime: TimeInterval = 0
    @State private var playStartedAt: Date?
    @State private var safeArea = EdgeInsets()
    /// Captures App Store (mode démo) : ni commandes ni barre de progression.
    @State private var demoClean = false
    // Récompenses (coin des enfants)
    @State private var track = SentenceTrack()
    @State private var gain: RewardStore.Gain?
    @State private var sessionStars = 0
    @State private var sessionBadges: [RewardStore.Badge] = []

    /// Phrase en cours et moment où l'enfant y est entré : une phrase ne
    /// rapporte une étoile que si on a pris le temps de la lire.
    struct SentenceTrack {
        var sentence = 0
        var enteredAt = Date()
        var rewardedUpTo = -1
    }

    enum ReaderSheet: String, Identifiable {
        case settings, styles, edit
        var id: String { rawValue }
    }

    init(script: Script, profile: ReaderProfile = .studio) {
        self.profile = profile
        _script = State(initialValue: script)
        let doc = PrompterDocument(text: script.content)
        _document = State(initialValue: doc)
        _engine = State(initialValue: PrompterEngine(document: doc))
    }

    private var settings: ReaderSettings { settingsStore[profile] }
    private var isKids: Bool { profile == .kids }
    private var accent: Color { Palette.cardColor(script.colorIndex) }
    /// Les scènes 3D suivent l'inclinaison de l'appareil (si le réglage le permet).
    private var wantsTilt: Bool { settings.style.family == .threeD && settings.motionParallax }

    var body: some View {
        ZStack {
            stage
                .scaleEffect(x: settings.mirror ? -1 : 1, y: 1)
                .ignoresSafeArea()
                .onTapGesture { handleStageTap() }
                .id(settings.style)

            if document.isEmpty { emptyState }

            controls
                .background(GeometryReader { g in
                    Color.clear
                        .onAppear { safeArea = g.safeAreaInsets }
                        .onChange(of: g.safeAreaInsets) { _, v in safeArea = v }
                })
                .opacity(controlsVisible ? 1 : 0)
                .allowsHitTesting(controlsVisible)
                .animation(.easeInOut(duration: 0.3), value: controlsVisible)

            if !controlsVisible && !demoClean { miniProgress }

            if case .countdown(let n) = engine.phase {
                CountdownView(value: n, retro: settings.style.family == .retro, accent: accent)
                    .allowsHitTesting(false)
            }

            if let gain, isKids, !finished {
                RewardBanner(gain: gain)
                    .padding(.top, safeArea.top + 56)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }

            if finished {
                Group {
                    if isKids {
                        KidsFinishView(stars: sessionStars, badges: sessionBadges, total: rewards.stars,
                                       onReplay: replay, onClose: close)
                    } else {
                        FinishView(words: document.wordCount, seconds: readingTime, accent: accent,
                                   onReplay: replay, onClose: close)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.05)))
            }

            keyboardShortcuts
        }
        .background(Color.black)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .onAppear(perform: setUp)
        .onDisappear(perform: tearDown)
        .onChange(of: settings.wordsPerMinute) { _, v in engine.wordsPerMinute = v }
        .onChange(of: settings.voiceOn) { _, v in
            engine.voiceEnabled = v
            if engine.isPlaying { engine.pause(); engine.play() }
        }
        .onChange(of: settings.voiceID) { _, v in engine.voiceID = v }
        .onChange(of: wantsTilt, initial: true) { _, on in on ? tilt.start() : tilt.stop() }
        .onChange(of: engine.phase) { old, new in phaseChanged(from: old, to: new) }
        .onChange(of: engine.coarseWord) { _, w in if isKids { sentenceProgress(word: w) } }
        .sheet(item: $sheet, onDismiss: reloadIfEdited) { s in
            switch s {
            case .settings: ReaderSettingsView()
            case .styles: StylePickerView()
            case .edit:
                NavigationStack { EditorView(scriptID: script.id, presentedFromReader: true) }
            }
        }
        // En dernier : le profil doit aussi atteindre les feuilles (réglages, styles).
        .environment(\.readerProfile, profile)
    }

    // MARK: - Scène

    @ViewBuilder
    private var stage: some View {
        let ctx = StageContext(engine: engine, document: document, settings: settings, tilt: tilt,
                               accent: accent, safeArea: safeArea)
        switch settings.style {
        case .sky: SkyStage(ctx: ctx)
        case .classic: ClassicStage(ctx: ctx)
        case .crtGreen: CRTStage(ctx: ctx, amber: false, title: script.displayTitle)
        case .crtAmber: CRTStage(ctx: ctx, amber: true, title: script.displayTitle)
        case .typewriter: TypewriterStage(ctx: ctx)
        case .drum: DrumStage(ctx: ctx)
        case .cards: CardsStage(ctx: ctx)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "text.badge.plus").font(.system(size: 44, weight: .semibold))
            Text("Ce texte est vide").font(Typo.headline(20))
            if !script.isSample {
                Button("Écrire le texte") { sheet = .edit }
                    .buttonStyle(PrimaryButtonStyle(color: accent))
            }
        }
        .foregroundStyle(.white)
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 28).fill(.ultraThinMaterial))
    }

    // MARK: - Commandes

    private var controls: some View {
        VStack(spacing: 12) {
            topBar
            if let w = resumeWord { resumeBanner(word: w) }
            Spacer()
            if isKids {
                KidsControlBar(engine: engine,
                               onSettings: { sheet = .settings },
                               onStyles: { sheet = .styles },
                               onInteract: poke)
            } else {
                if !engine.isPlaying, !document.isEmpty, engine.phase != .finished {
                    Button { engine.readSentenceAloud(); poke() } label: {
                        Label("Écouter la phrase", systemImage: "waveform")
                    }
                    .buttonStyle(PrimaryButtonStyle(color: .white.opacity(0.18), compact: true))
                    .transition(.opacity)
                }
                ReaderControlBar(engine: engine, accent: accent,
                                 onSettings: { sheet = .settings },
                                 onStyles: { sheet = .styles },
                                 onInteract: poke)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.25), value: engine.isPlaying)
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: close) { Image(systemName: "xmark") }
                .buttonStyle(GlassCircleButtonStyle(size: 44))
                .accessibilityLabel("Fermer le lecteur")

            HStack(spacing: 8) {
                Circle().fill(accent).frame(width: 8, height: 8)
                Text(script.displayTitle).lineLimit(1)
            }
            .font(Typo.headline(15))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Capsule().fill(.ultraThinMaterial))
            .environment(\.colorScheme, .dark)

            Spacer(minLength: 0)

            if isKids {
                StarCounter(stars: rewards.stars, compact: true)
            } else {
                Button {
                    if script.isSample { copySample() } else { engine.pause(); sheet = .edit }
                } label: {
                    Image(systemName: script.isSample ? "doc.on.doc" : "pencil")
                }
                .buttonStyle(GlassCircleButtonStyle(size: 44))
                .accessibilityLabel(script.isSample ? "Copier cet exemple pour le modifier" : "Modifier le texte")
            }
        }
    }

    private func resumeBanner(word: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "bookmark.fill").foregroundStyle(accent)
            Text("Reprise là où tu t'étais arrêté").font(Typo.body(14)).foregroundStyle(.white)
            Spacer(minLength: 4)
            Button("Depuis le début") {
                engine.restart()
                withAnimation { resumeWord = nil }
            }
            .font(Typo.headline(14))
            .foregroundStyle(accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Capsule().fill(.ultraThinMaterial))
        .environment(\.colorScheme, .dark)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var miniProgress: some View {
        VStack {
            Spacer()
            GeometryReader { g in
                Capsule().fill(accent.opacity(0.9))
                    .frame(width: max(4, g.size.width * engine.displayProgress), height: 3)
            }
            .frame(height: 3)
            .padding(.horizontal, 24)
            .padding(.bottom, 6)
        }
        .allowsHitTesting(false)
    }

    private var keyboardShortcuts: some View {
        // Clavier et télécommandes Bluetooth (qui envoient flèches, espace ou page suivante).
        ZStack {
            Button("Lecture / pause") { engine.toggle(countdown: settings.countdown); poke() }
                .keyboardShortcut(.space, modifiers: [])
            Button("Phrase précédente") { engine.jumpSentence(-1) }.keyboardShortcut(.upArrow, modifiers: [])
            Button("Phrase suivante") { engine.jumpSentence(1) }.keyboardShortcut(.downArrow, modifiers: [])
            Button("Page précédente") { engine.jumpSentence(-1) }.keyboardShortcut(.pageUp, modifiers: [])
            Button("Page suivante") { engine.jumpSentence(1) }.keyboardShortcut(.pageDown, modifiers: [])
            Button("Plus lent") { changeSpeed(up: false) }.keyboardShortcut(.leftArrow, modifiers: [])
            Button("Plus rapide") { changeSpeed(up: true) }.keyboardShortcut(.rightArrow, modifiers: [])
            Button("Mot suivant") { engine.jumpWord(1) }.keyboardShortcut(.return, modifiers: [])
            Button("Fermer") { close() }.keyboardShortcut(.escape, modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    // MARK: - Comportement

    private func setUp() {
        UIApplication.shared.isIdleTimerDisabled = true
        engine.wordsPerMinute = settings.wordsPerMinute
        engine.voiceEnabled = settings.voiceOn
        engine.voiceID = settings.voiceID
        engine.onFinish = { finishedReading() }
        track = SentenceTrack(sentence: document.isEmpty ? 0 : document.sentenceIndex(ofWord: engine.currentWord))
        #if DEBUG
        let demo = DemoConfig.current
        if demo.screen != nil {
            if let w = demo.word { engine.seek(toBeat: engine.timeline.beat(atWordPosition: w)); engine.pause() }
            if demo.clean { controlsVisible = false; demoClean = true }
            track = SentenceTrack(sentence: document.isEmpty ? 0 : document.sentenceIndex(ofWord: engine.currentWord))
            if demo.screen == "styles" { sheet = .styles }
            if demo.screen == "settings" { sheet = .settings }
            if demo.play { engine.play() }
            return
        }
        #endif
        if script.lastWord > 3, script.lastWord < document.wordCount - 3 {
            engine.seek(toWord: script.lastWord)
            engine.pause()
            resumeWord = script.lastWord
            Task {
                try? await Task.sleep(for: .seconds(5))
                withAnimation { resumeWord = nil }
            }
        }
    }

    private func tearDown() {
        UIApplication.shared.isIdleTimerDisabled = false
        savePosition()
        engine.shutdown()
        TypewriterSound.shared.stop()
        AudioSession.deactivate()
        tilt.stop()
        hideTask?.cancel()
    }

    private func close() {
        savePosition()
        if isKids, !finished, engine.progress > 0 { rewards.textProgress(script.id, fraction: engine.progress) }
        engine.shutdown()
        dismiss()
    }

    private func replay() {
        finished = false
        sessionStars = 0
        sessionBadges = []
        engine.restart()
        track = SentenceTrack()
        engine.toggle(countdown: settings.countdown)
    }

    private func finishedReading() {
        if isKids {
            // La dernière phrase compte aussi.
            sentenceProgress(word: document.wordCount, force: true)
            collect(rewards.textFinished(script.id, wordsPerMinute: settings.wordsPerMinute))
        }
        withAnimation(.spring(response: 0.5)) { finished = true }
        Haptics.success()
    }

    /// Une étoile par phrase lue en avançant, si l'enfant a eu le temps de la lire
    /// (pas en faisant défiler du doigt).
    private func sentenceProgress(word: Int, force: Bool = false) {
        guard !document.isEmpty else { return }
        let new = word >= document.wordCount ? document.sentences.count : document.sentenceIndex(ofWord: word)
        guard new != track.sentence else { return }
        let old = track.sentence
        let words = document.sentences.indices.contains(old) ? document.sentences[old].words.count : 1
        let enough = Date().timeIntervalSince(track.enteredAt) >= Double(words) * 0.35
        if new == old + 1, old > track.rewardedUpTo, enough, engine.isPlaying || force || engine.phase == .paused {
            track.rewardedUpTo = old
            collect(rewards.sentenceRead())
        }
        track.sentence = new
        track.enteredAt = Date()
    }

    private func collect(_ g: RewardStore.Gain) {
        guard g.stars > 0 || !g.badges.isEmpty || g.newLevel != nil else { return }
        sessionStars += g.stars
        sessionBadges += g.badges
        if !g.badges.isEmpty || g.newLevel != nil { Haptics.success() }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { gain = g }
        let shown = g
        Task {
            try? await Task.sleep(for: .seconds(g.badges.isEmpty && g.newLevel == nil ? 1.3 : 2.8))
            if gain == shown { withAnimation(.easeOut(duration: 0.3)) { gain = nil } }
        }
    }

    private func savePosition() {
        guard !script.isSample else { return }
        let w = engine.phase == .finished ? 0 : engine.currentWord
        store.savePosition(script.id, word: w)
    }

    private func handleStageTap() {
        guard !document.isEmpty, !finished else { return }
        if resumeWord != nil { withAnimation { resumeWord = nil } }
        engine.toggle(countdown: settings.countdown)
        Haptics.tap()
    }

    private func phaseChanged(from old: PrompterEngine.Phase, to new: PrompterEngine.Phase) {
        if new == .playing {
            playStartedAt = Date()
            if old == .finished || old == .idle { readingTime = 0 }
            withAnimation { resumeWord = nil }
            scheduleHide()
        } else {
            if let start = playStartedAt { readingTime += Date().timeIntervalSince(start) }
            playStartedAt = nil
            hideTask?.cancel()
            withAnimation { controlsVisible = true }
            if new == .paused { savePosition() }
        }
    }

    /// Toute interaction avec les commandes les garde visibles un moment.
    private func poke() {
        withAnimation { controlsVisible = true }
        if engine.isPlaying { scheduleHide() }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled, engine.isPlaying, sheet == nil else { return }
            withAnimation(.easeInOut(duration: 0.45)) { controlsVisible = false }
        }
    }

    private func changeSpeed(up: Bool) {
        settingsStore[profile].wordsPerMinute = ReaderSettings.stepped(settings.wordsPerMinute, up: up)
        poke()
    }

    private func reloadIfEdited() {
        guard !script.isSample else { return }
        guard let updated = store.script(script.id) else {
            // Le texte a été supprimé depuis l'éditeur : rien à lire.
            engine.shutdown()
            dismiss()
            return
        }
        if updated.content != script.content {
            script = updated
            let doc = PrompterDocument(text: updated.content)
            document = doc
            engine.setDocument(doc)
            finished = false
        } else {
            script = updated
        }
    }

    private func copySample() {
        engine.shutdown()
        let canCreate = store.canCreate
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            if canCreate {
                _ = router.newScript(in: store, title: script.displayTitle, content: script.content, profile: profile)
                router.show("Copie créée : tu peux la modifier")
            } else {
                router.sheet = .premium
            }
        }
    }
}

// MARK: - Barre de commandes

struct ReaderControlBar: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.readerProfile) private var profile
    let engine: PrompterEngine
    let accent: Color
    let onSettings: () -> Void
    let onStyles: () -> Void
    let onInteract: () -> Void

    var body: some View {
        let s = settingsStore[profile]
        VStack(spacing: 14) {
            ProgressScrubber(engine: engine, accent: accent, onInteract: onInteract)

            HStack(spacing: 10) {
                Button(action: onSettings) { Image(systemName: "textformat.size") }
                    .buttonStyle(GlassCircleButtonStyle(size: 42))
                    .accessibilityLabel("Réglages de lecture")

                HStack(spacing: 0) {
                    speedButton("minus", up: false)
                    VStack(spacing: 0) {
                        Text("\(Int(s.wordsPerMinute))").font(Typo.headline(17)).monospacedDigit()
                        Text("mots/min").font(Typo.caption(10)).opacity(0.7)
                    }
                    .frame(minWidth: 64)
                    .contentTransition(.numericText())
                    speedButton("plus", up: true)
                }
                .foregroundStyle(.white)
                .frame(height: 42)
                .background(Capsule().fill(.white.opacity(0.1)))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Vitesse \(Int(s.wordsPerMinute)) mots par minute")
                .accessibilityAdjustableAction { dir in
                    change(up: dir == .increment)
                }

                Button(action: onStyles) {
                    HStack(spacing: 6) {
                        Image(systemName: s.style.symbol)
                        Text(s.style.title).lineLimit(1)
                    }
                    .font(Typo.headline(14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(Capsule().fill(.white.opacity(0.1)))
                }
                .accessibilityLabel("Style d'affichage : \(s.style.title)")
            }

            HStack(spacing: 18) {
                Button { engine.restart(); onInteract() } label: { Image(systemName: "backward.end.fill") }
                    .buttonStyle(GlassCircleButtonStyle(size: 46))
                    .accessibilityLabel("Revenir au début")
                Button { engine.jumpSentence(-1); onInteract() } label: { Image(systemName: "gobackward") }
                    .buttonStyle(GlassCircleButtonStyle(size: 46))
                    .accessibilityLabel("Phrase précédente")

                PlayButton(engine: engine, accent: accent) {
                    engine.toggle(countdown: settingsStore[profile].countdown)
                    Haptics.thump()
                    onInteract()
                }

                Button { engine.jumpSentence(1); onInteract() } label: { Image(systemName: "goforward") }
                    .buttonStyle(GlassCircleButtonStyle(size: 46))
                    .accessibilityLabel("Phrase suivante")
                Button {
                    settingsStore[profile].voiceOn.toggle()
                    Haptics.tap()
                    onInteract()
                } label: {
                    Image(systemName: s.voiceOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                }
                .buttonStyle(GlassCircleButtonStyle(size: 46, active: s.voiceOn, activeColor: accent))
                .accessibilityLabel(s.voiceOn ? "Voix activée" : "Voix désactivée")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(.white.opacity(0.1)))
        )
        .environment(\.colorScheme, .dark)
        .frame(maxWidth: 560)
    }

    private func speedButton(_ symbol: String, up: Bool) -> some View {
        Button { change(up: up) } label: {
            Image(systemName: symbol).font(.system(size: 14, weight: .heavy)).frame(width: 40, height: 42)
        }
        .buttonRepeatBehavior(.enabled)
        .accessibilityHidden(true)
    }

    private func change(up: Bool) {
        withAnimation(.snappy) {
            settingsStore[profile].wordsPerMinute = ReaderSettings.stepped(settingsStore[profile].wordsPerMinute, up: up)
        }
        Haptics.tick()
        onInteract()
    }
}

struct PlayButton: View {
    let engine: PrompterEngine
    let accent: Color
    let action: () -> Void

    var body: some View {
        let playing = engine.isPlaying
        let counting: Bool = { if case .countdown = engine.phase { return true } else { return false } }()
        Button(action: action) {
            ZStack {
                Circle().fill(accent)
                    .shadow(color: accent.opacity(0.55), radius: playing ? 18 : 10)
                Image(systemName: counting ? "xmark" : (playing ? "pause.fill" : "play.fill"))
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(.white)
                    .offset(x: playing || counting ? 0 : 2)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 74, height: 74)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(playing ? "Pause" : (counting ? "Annuler le compte à rebours" : "Lecture"))
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Barre de progression qu'on peut toucher ou glisser.
struct ProgressScrubber: View {
    let engine: PrompterEngine
    let accent: Color
    let onInteract: () -> Void
    @GestureState private var dragging = false

    var body: some View {
        let total = engine.timeline.total / max(0.1, engine.beatsPerSecond)
        let elapsed = max(0, total - Double(engine.remainingSeconds))
        VStack(spacing: 6) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.16))
                    Capsule().fill(accent)
                        .frame(width: max(6, g.size.width * engine.displayProgress))
                    Circle().fill(.white)
                        .frame(width: dragging ? 18 : 12, height: dragging ? 18 : 12)
                        .offset(x: max(0, g.size.width * engine.displayProgress - (dragging ? 9 : 6)))
                        .shadow(radius: 3)
                }
                .frame(height: 6)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($dragging) { v, dragging, _ in
                            // La voix se tait pendant le déplacement et repart du nouvel endroit.
                            if !dragging { engine.beginScrub(); dragging = true }
                            let p = min(1, max(0, v.location.x / max(1, g.size.width)))
                            engine.seek(toBeat: p * engine.timeline.total)
                            onInteract()
                        }
                        .onEnded { _ in engine.endScrub(velocity: 0) }
                )
                .onChange(of: dragging) { _, on in
                    if !on { DispatchQueue.main.async { engine.cancelScrubIfNeeded() } }
                }
            }
            .frame(height: 22)
            .animation(.spring(response: 0.25), value: dragging)

            HStack {
                Text(Format.clock(engine.displayProgress >= 0.999 ? 0 : elapsed))
                Spacer()
                Text("−" + Format.clock(Double(engine.remainingSeconds)))
            }
            .font(Typo.mono(11))
            .foregroundStyle(.white.opacity(0.6))
        }
        .accessibilityElement()
        .accessibilityLabel("Progression")
        .accessibilityValue("\(Int(engine.displayProgress * 100)) %")
    }
}

// MARK: - Compte à rebours et fin

struct CountdownView: View {
    let value: Int
    let retro: Bool
    let accent: Color
    @State private var ring = 0.0

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            Circle()
                .stroke(.white.opacity(0.15), lineWidth: 10)
                .frame(width: 170, height: 170)
            Circle()
                .trim(from: 0, to: ring)
                .stroke(accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 170, height: 170)
            Text("\(value)")
                .font(retro ? .system(size: 96, weight: .black, design: .monospaced)
                            : .system(size: 104, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
                .id(value)
                .transition(.scale(scale: 1.6).combined(with: .opacity))
        }
        .onAppear { animateRing() }
        .onChange(of: value) { animateRing() }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: value)
    }

    private func animateRing() {
        ring = 0
        withAnimation(.linear(duration: 0.8)) { ring = 1 }
    }
}

struct FinishView: View {
    let words: Int
    let seconds: TimeInterval
    let accent: Color
    let onReplay: () -> Void
    let onClose: () -> Void
    @State private var burst = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            ForEach(0..<18, id: \.self) { i in
                let angle = Double(i) / 18 * 2 * .pi
                Image(systemName: i % 3 == 0 ? "star.fill" : "sparkle")
                    .font(.system(size: CGFloat(14 + (i % 4) * 6)))
                    .foregroundStyle(i % 2 == 0 ? accent : Palette.sun)
                    .offset(x: burst ? cos(angle) * 170 : 0, y: burst ? sin(angle) * 170 : 0)
                    .opacity(burst ? 0 : 1)
                    .scaleEffect(burst ? 1.2 : 0.2)
            }
            VStack(spacing: 14) {
                Text("Bravo !")
                    .font(.system(size: 54, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(summary)
                    .font(Typo.body(17))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                HStack(spacing: 12) {
                    Button(action: onReplay) { Label("Relire", systemImage: "arrow.counterclockwise") }
                        .buttonStyle(PrimaryButtonStyle(color: accent))
                    Button(action: onClose) { Text("Terminer") }
                        .buttonStyle(PrimaryButtonStyle(color: .white.opacity(0.16)))
                }
                .padding(.top, 8)
            }
            .padding(30)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.1)) { burst = true }
        }
    }

    private var summary: String {
        guard seconds > 1 else { return "Tu as lu tout le texte." }
        let wpm = Int(Double(words) / max(1, seconds) * 60)
        return "\(Format.words(words)) lus en \(Format.duration(seconds))\nsoit environ \(wpm) mots par minute."
    }
}
